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

int read_byte_array(SBValue sbvalue, 
                    uint64_t *output_size, 
                    uint64_t *output_capacity, 
                    void **output);

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

// Output is in a serialized format:
// 1st level of recursion (the header that starts the output):
// - first 8 bytes (UInt64): header that says how many display messages
// 2nd level of recursion:
// - first 8 bytes (UInt64): header that says how many byte arrays
// 3rd level of recursion:
// - first 8 bytes (UInt64): header that says how long the byte array is
// - rest of line: data in the byte array, with allocated capacity rounded
//   up to a multiple of 8 bytes
//
// Caller must deallocate `serialized_output`.
int after_successful_execution(uint64_t **serialized_output) {
  const char *code = "JupyterKernel.communicator.triggerAfterSuccessfulExecution()";
  auto result = target.EvaluateExpression(code, expr_opts);
  auto errorType = result.GetError().GetType();
  
  if (errorType != eErrorTypeInvalid) {
    *serialized_output = NULL;
    return 1;
  }
  
  uint64_t output_size = 0;
  uint64_t output_capacity = 1024;
  void *output = malloc(output_capacity);
  
  uint32_t num_display_messages = result.GetNumChildren();
  ((uint64_t*)output)[0] = num_display_messages;
  output_size += 8;
  
  for (uint32_t i = 0; i < num_display_messages; ++i) {
    auto display_message = result.GetChildAtIndex(i);
    
    uint32_t num_byte_arrays = display_message.GetNumChildren();
    ((uint64_t*)((char*)output + output_size))[0] = num_byte_arrays;
    output_size += 8;
    
    for (uint32_t j = 0; j < num_byte_arrays; ++j) {
      auto byte_array = display_message.GetChildAtIndex(j);
      int error_code = read_byte_array(
        byte_array, &output_size, &output_capacity, &output);
      if (error_code != 0) {
        free(output);
        *serialized_output = NULL;
        return 1 + error_code;
      }
    }
  }
  
  *serialized_output = (uint64_t*)output;
  return 0;
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
    
    unsafe_log_message("frame start\n");
    unsafe_log_message(file_name);
    unsafe_log_message("\n");
    unsafe_log_message(function_name);
    unsafe_log_message("\n");
    if (directory_name) {
      unsafe_log_message(directory_name);
      unsafe_log_message("\n");
    }
    unsafe_log_message("frame end\n");
    
    // Let the Swift code format the line and column. Serialize them into an
    // 8-byte header.
    void *desc = malloc(
      /*line*/4 + /*column*/4 + 
      /*count*/4 + function_name_len + /*null terminator*/1 + 
      /*count*/4 + file_name_len + /*null terminator*/1 + 
      /*count*/4 + directory_name_len + /*null terminator*/1);
    
    // Write line and column
    uint32_t *header = (uint32_t*)desc;
    header[0] = line_entry.GetLine();
    header[1] = line_entry.GetColumn();
    int str_ptr = 4 + 4;
    
    // Write function name
    *((int*)header) = function_name_len + 1;
    str_ptr += 4;
    memcpy((char*)desc + str_ptr, function_name, function_name_len);
    function_name = (char*)desc + str_ptr; //
    str_ptr += function_name_len;
    ((char*)desc)[str_ptr] = 0; // Write null terminator
    str_ptr += 1;
    
    // Write file name
    *((int*)header) = file_name_len + 1;
    str_ptr += 4;
    memcpy((char*)desc + str_ptr, file_name, file_name_len);
    file_name = (char*)desc + str_ptr; //
    str_ptr += file_name_len;
    ((char*)desc)[str_ptr] = 0; // Write null terminator
    str_ptr += 1;
    
    // Write directory name
    *((int*)header) = directory_name_len + 1;
    str_ptr += 4;
    if (directory_name_len > 0) {
      memcpy((char*)desc + str_ptr, directory_name, directory_name_len);
      directory_name = (char*)desc + str_ptr; //
      str_ptr += directory_name_len;
    }
    ((char*)desc)[str_ptr] = 0; // Write null terminator
    str_ptr += 1;
    
    // Store description pointer
    out[filled_size] = desc;
    filled_size += 1;

    {
      unsafe_log_message("frame start2\n");
      unsafe_log_message(file_name);
      unsafe_log_message("\n");
      unsafe_log_message(function_name);
      unsafe_log_message("\n");
      if (directory_name) {
        unsafe_log_message(directory_name);
        unsafe_log_message("\n");
      }
      unsafe_log_message("frame end2\n");
    }
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

int read_byte_array(SBValue sbvalue, 
                    uint64_t *output_size, 
                    uint64_t *output_capacity, 
                    void **output) {
  auto get_address_error = SBError();
  auto address = sbvalue
    .GetChildMemberWithName("address")
    .GetData()
    .GetAddress(get_address_error, 0);
  if (get_address_error.Fail()) {
    return 1;
  }
  
  auto get_count_error = SBError();
  auto count_data = sbvalue
    .GetChildMemberWithName("count")
    .GetData();
  int64_t count = count_data.GetSignedInt64(get_count_error, 0);
  if (get_count_error.Fail()) {
    return 2;
  }
  
  int64_t needed_new_capacity = 
    8 // 3rd-level header 
    + (~7 & (count + 7)) // byte array's contents
    + 8; // potential next 2nd-level header
  int64_t needed_total_capacity = *output_size + needed_new_capacity;
  if (needed_total_capacity > *output_capacity) {
    uint64_t new_capacity = (*output_capacity) * 2;
    while (needed_total_capacity > new_capacity) {
      new_capacity *= 2;
    }
    
    void *new_output = malloc(new_capacity);
    memcpy(new_output, *output, *output_size);
    free(*output);
    *output = new_output;
    *output_capacity = new_capacity;
  }
  
  int64_t added_size = 
    8 // 3rd-level header 
    + (~7 & (count + 7)); // byte array's contents
  int64_t current_size = *output_size;
  int64_t *data_stream = (int64_t*)((char*)(*output) + current_size);
  
  // Zero out the last 8 bytes in the buffer; everything else will
  // be written to at some point.
  data_stream[added_size / 8 - 1] = 0;
  data_stream[0] = count;
  
  if (count > 0) {
    auto get_data_error = SBError();
    process.ReadMemory(address, data_stream + 1, count, get_data_error);
    if (get_data_error.Fail()) {
      return 3;
    }
  }
  
  // Update `output_size` to reflect the added data.
  *output_size = current_size + added_size;
  return 0;
}
