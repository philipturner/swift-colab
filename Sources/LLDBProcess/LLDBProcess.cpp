#include <stdio.h>
#include <string.h>
#include <LLDB/LLDB.h>

// MARK: - Logging Functions

bool log_initialized = false;

extern "C" {
  int get_log_initialized() {
    return int(log_initialized);
  }
  
  void set_log_initialized(int new_value) {
    log_initialized = bool(new_value);
  }
}

// Not thread-safe with respect to the Swift-side `KernelContext.log(_:)`.
// Must manually add the "\n" terminator to the message.
void unsafe_log_message(const char *message_with_newline) {
  const char *mode = NULL;
  if (log_initialized) {
    mode = "a";
  } else {
    mode = "w";
    log_initialized = true;
  }
  
  auto file_pointer = fopen("/opt/swift/log", mode);
  auto count = strlen(message_with_newline);
  fwrite(message_with_newline, 1, count, file_pointer);
  fclose(file_pointer);
}

// MARK: - LLDB Functions

using namespace lldb;
SBDebugger debugger;
SBTarget target;
SBBreakpoint main_bp;
SBProcess process;
SBExpressionOptions expr_opts;
SBThread main_thread;

extern "C" {

int init_repl_process(const char **repl_env,
                      const char *cwd) {
  SBDebugger::Initialize();
  debugger = SBDebugger::Create();
  if (!debugger.IsValid())
    return 1;
  
  debugger.SetAsync(false);
  debugger.HandleCommand(
    "settings append target.swift-module-search-paths "
    "/opt/swift/install-location/modules");
  
  const char *repl_swift = "/opt/swift/toolchain/usr/bin/repl_swift";
  target = debugger.CreateTarget(repl_swift);
  if (!target.IsValid())
    return 2;
  
  main_bp = target.BreakpointCreateByName(
    "repl_main", target.GetExecutable().GetFilename());
  if (!main_bp.IsValid())
    return 3;
  
  // Turn off "disable ASLR". This feature prevents the Swift Standard Library
  // from loading.
  auto launch_flags = target.GetLaunchInfo().GetLaunchFlags();
  launch_flags &= ~eLaunchFlagDisableASLR;
  
  // Redirect stderr to something that Swift-Colab can manually process. This
  // suppresses the ugly backtraces that appear in stdout.
  const char *errorFilePath = "/opt/swift/err";
  FILE *errorFilePointer = fopen(errorFilePath, "w");
  fclose(errorFilePointer);
  
  SBListener listener;
  SBError error;
  process = target.Launch(
    listener, /*argv=*/NULL, repl_env, /*stdin_path=*/NULL, 
    /*stdout_path=*/NULL, errorFilePath, cwd, launch_flags, 
    /*stop_at_entry=*/false, error);
  if (!process.IsValid())
    return 4;
  
  expr_opts = SBExpressionOptions();
  auto swift_language = SBLanguageRuntime::GetLanguageTypeFromString("swift");
  expr_opts.SetLanguage(swift_language);
  expr_opts.SetREPLMode(true);
  expr_opts.SetUnwindOnError(false);
  expr_opts.SetGenerateDebugInfo(true);
  
  // Sets an infinite timeout so that users can run arbitrarily long
  // computations.
  expr_opts.SetTimeoutInMicroSeconds(0);
  
  main_thread = process.GetThreadAtIndex(0);
  return 0;
}

// Caller must deallocate `description`.
int execute(const char *code, char **description) {
  auto result = target.EvaluateExpression(code, expr_opts);
  auto error = result.GetError();
  auto errorType = error.GetType();
  
  const char *unowned_desc;
  if (errorType == eErrorTypeInvalid) {
    unowned_desc = result.GetObjectDescription();
    // `unowned_desc` may be null here.
  } else if (errorType == eErrorTypeGeneric) {
    unowned_desc = NULL;
  } else {
    unowned_desc = error.GetCString();
    // `unowned_desc` should never be null here.
  }
  
  if (errorType == eErrorTypeInvalid && unowned_desc == NULL) {
    // The last line of code created a `Task`. This has a null description, so
    // act as if it's a `SuccessWithoutValue`.
    errorType = eErrorTypeGeneric;
  }
  
  if (errorType == eErrorTypeGeneric) {
    *description = NULL;
  } else {
    int desc_size = strlen(unowned_desc);
    bool replace_last = false;
    if (errorType != eErrorTypeInvalid && desc_size > 0) {
      char last_char = unowned_desc[desc_size - 1];
      if (last_char == '\n' || last_char == '\r') {
        desc_size -= 1;
        replace_last = true;
      }
    }
    
    char *owned_desc = (char*)malloc(desc_size + 1);
    memcpy(owned_desc, unowned_desc, desc_size + 1);
    if (replace_last) {
      owned_desc[desc_size] = 0;
    }
    *description = owned_desc;
  }
  
  if (errorType == eErrorTypeInvalid) {
    return 0;
  } else if (errorType == eErrorTypeGeneric) {
    return 1;
  } else {
    return 2;
  }
}

int process_is_alive() {
  auto s = process.GetState();
  if (s == eStateAttaching ||
      s == eStateLaunching ||
      s == eStateStopped || 
      s == eStateRunning || 
      s == eStateStepping || 
      s == eStateCrashed || 
      s == eStateSuspended) {
    return 1;
  } else {
    return 0;
  }
}

int get_stdout(char *dst, int *buffer_size) {
  return int(process.GetSTDOUT(dst, size_t(buffer_size)));
}

// Caller must deallocate `frames` and every string within `frames`.
int get_pretty_stack_trace(void ***frames, int *size) {
  uint32_t allocated_size = main_thread.GetNumFrames();
  void **out = (void**)malloc(allocated_size * sizeof(char*));
  int filled_size = 0;
  
  for (uint32_t i = 0; i < allocated_size; ++i) {
    auto frame = main_thread.GetFrameAtIndex(i);
    
    // Do not include frames without source location information. These are 
    // frames in libraries and frames that belong to the LLDB expression 
    // execution implementation.
    auto line_entry = frame.GetLineEntry();
    auto file_spec = line_entry.GetFileSpec();
    if (!file_spec.IsValid()) {
      continue;
    }
    
    // Do not include <compiler-generated> frames. These are specializations of
    // library functions.
    if (strcmp(file_spec.GetFilename(), "<compiler-generated>") == 0) {
      continue;
    }
    
    auto function_name = frame.GetDisplayFunctionName();
    auto function_name_len = strlen(function_name);
    auto file_name = file_spec.GetFilename();
    auto file_name_len = strlen(file_name);
    
    const char *directory_name = NULL;
    size_t directory_name_len = 0;
    if (file_spec.Exists()) {
      directory_name = file_spec.GetDirectory();
      directory_name_len = strlen(directory_name); 
    }
    
    // Let the Swift code format the line and column. Serialize them into an
    // 8-byte header.
    void *desc = malloc(
      /*line*/4 + /*column*/4 + 
      /*count*/4 + (~3 & (function_name_len + 3)) + 
      /*count*/4 + (~3 & (file_name_len + 3)) + 
      /*count*/4 + (~3 & (directory_name_len + 3)));
    
    // Write line and column.
    uint32_t *header = (uint32_t*)desc;
    header[0] = line_entry.GetLine();
    header[1] = line_entry.GetColumn();
    int str_ptr = 4 + 4;
    
    // Write function name.
    ((int*)((char*)header + str_ptr))[0] = function_name_len;
    str_ptr += 4;
    memcpy((char*)desc + str_ptr, function_name, function_name_len);
    str_ptr += ~3 & (function_name_len + 3); // Align to 4 bytes.
    
    // Write file name.
    ((int*)((char*)header + str_ptr))[0] = file_name_len;
    str_ptr += 4;
    memcpy((char*)desc + str_ptr, file_name, file_name_len);
    str_ptr += ~3 & (file_name_len + 3); // Align to 4 bytes.
    
    // Write directory name.
    ((int*)((char*)header + str_ptr))[0] = directory_name_len;
    str_ptr += 4;
    if (directory_name_len > 0) {
      memcpy((char*)desc + str_ptr, directory_name, directory_name_len);
    }
    str_ptr += ~3 & (directory_name_len + 3); // Align to 4 bytes.
    
    // Store description pointer.
    out[filled_size] = desc;
    filled_size += 1;
  }
  *frames = out;
  *size = filled_size;
  return 0;
}

int async_interrupt_process() {
  process.SendAsyncInterrupt();
  return 0;
}

} // extern "C"
