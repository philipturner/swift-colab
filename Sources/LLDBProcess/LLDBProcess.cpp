#include <stdio.h>
#include <string.h>
#include <LLDB/LLDB.h>

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
    "/opt/swift/install_location/modules");
  
  // LLDB will not crash when scripting because this isn't macOS. However,
  // disabling scripting could decrease startup time if the debugger needs to
  // "load the Python scripting stuff".
  debugger.SetScriptLanguage(eScriptLanguageNone);
  
  const char *repl_swift = "/opt/swift/toolchain/usr/bin/repl_swift";
  target = debugger.CreateTarget(repl_swift);
  if (!target.IsValid())
    return 2;
  
  main_bp = target.BreakpointCreateByName(
    "repl_main", target.GetExecutable().GetFilename());
  if (!main_bp.IsValid())
    return 3;
  
  // Turn off "disable ASLR". This feature uses the "personality" syscall
  // in a way that is forbidden by the default Docker security policy.
  // Although Colab is not Docker, ASLR still prevents the Swift stdlib
  // from loading.
  auto launch_info = target.GetLaunchInfo();
  auto launch_flags = launch_info.GetLaunchFlags();
  launch_info.SetLaunchFlags(launch_flags & ~eLaunchFlagDisableASLR);
  target.SetLaunchInfo(launch_info);
  
  process = target.LaunchSimple(NULL, repl_env, cwd);
  if (!process.IsValid())
    return 4;
  
  expr_opts = SBExpressionOptions();
  auto swift_language = SBLanguageRuntime::GetLanguageTypeFromString("swift");
  expr_opts.SetLanguage(swift_language);
  expr_opts.SetREPLMode(true);
  expr_opts.SetUnwindOnError(false);
  expr_opts.SetGenerateDebugInfo(true);
  
  // Sets an infinite timeout so that users can run aribtrarily long
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
  
  if (errorType == eErrorTypeGeneric) {
    *description = NULL;
  } else {
    const char *unowned_desc;
    if (errorType == eErrorTypeInvalid) {
      unowned_desc = result.GetObjectDescription();
    } else {
      unowned_desc = error.GetCString();
    }
    
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

int process_is_alive(int *is_alive) {
  auto s = process.GetState();
  if (s == eStateAttaching ||
      s == eStateLaunching ||
      s == eStateStopped || 
      s == eStateRunning || 
      s == eStateStepping || 
      s == eStateCrashed || 
      s == eStateSuspended) {
    *is_alive = 1;
  } else {
    *is_alive = 0;
  }
  return 0;
}

// Output is in a serialized format:
// 1st level of recursion (the header that starts the output):
// - first 8 bytes (UInt64): header that says how many display messages
// 2nd level of recursion:
// - first 8 bytes (UInt64): header that says how many byte arrays
// 3rd level of recursion:
// - first 8 bytes (UInt64): header that says how long the byte array is
// - rest of line: data in the byte array, with allocated capacity rounded
// up to a multiple of 8 bytes
//
// Caller must deallocate `serialized_output`
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
int get_pretty_stack_trace(char ***frames, int *size) {
  uint32_t allocated_size = main_thread.GetNumFrames();
  char **out = (char**)malloc(allocated_size * sizeof(char*));
  int filled_size = 0;
  
  // Separates function name from source location in descriptions.
  const char *separator = " - ";
  int separator_len = strlen(separator);
  
  for (uint32_t i = 0; i < allocated_size; ++i) {
    auto frame = main_thread.GetFrameAtIndex(i);
    
    // Do not include frames without source location information. These
    // are frames in libraries and frames that belong to the LLDB
    // expression execution implementation.
    auto line_entry = frame.GetLineEntry();
    auto file_spec = line_entry.GetFileSpec();
    if (!file_spec.IsValid()) {
      continue;
    }
    
    // Do not include <compiler-generated> frames. These are
    // specializations of library functions.
    if (strcmp(file_spec.GetFilename(), "<compiler-generated>") == 0) {
      continue;
    }
    
    auto function_name = frame.GetDisplayFunctionName();
    auto function_name_len = strlen(function_name);
    
    SBStream stream;
    line_entry.GetDescription(stream);
    auto source_loc = stream.GetData();
    auto source_loc_len = strlen(source_loc);
    
    char *desc = (char*)malloc(
      function_name_len + separator_len + source_loc_len + 1);
    
    // Write function name
    memcpy(desc, function_name, function_name_len);
    
    // Write separator
    int str_ptr = function_name_len;
    memcpy(desc + str_ptr, separator, separator_len);
    
    // Write source location
    str_ptr += separator_len;
    memcpy(desc + str_ptr, source_loc, source_loc_len);
    
    // Write null terminator
    str_ptr += source_loc_len;
    desc[str_ptr] = 0;
    
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
