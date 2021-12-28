import Foundation
import PythonKit

fileprivate let ioloop = Python.import("tornado").ioloop
fileprivate let json = Python.import("json")
fileprivate let lldb = Python.import("lldb")
fileprivate let squash_dates = Python.import("jupyter_client").jsonutil.squash_dates
fileprivate let SwiftModule = Python.import("Swift")

func do_execute(_ kwargs: PythonObject) throws -> PythonObject {
    let selfRef = kwargs["self"]
    var code = kwargs["code"]
    
    // Return early if the code is empty or whitespace, to avoid
    // initializing Swift and preventing package installs.
    if Python.len(code) == 0 || Bool(code.isspace())! {
        return [
            "status": "ok",
            "execution_count": selfRef.execution_count,
            "payload": [],
            "user_expressions": [:],
        ]
    }
    
    // Package installs must be done before initializing Swift (see doc
    // comment in `init_swift`).
    do {
        code = try process_installs(selfRef, code: code)
    } catch let e as PackageInstallException {
        let array = [String(describing: e)].pythonObject
        
        try send_iopub_error_message(selfRef, array)
        return make_execute_reply_error_message(selfRef, array)
    } catch let e {
        try send_exception_report(selfRef, "process_installs", e)
        throw e
    }
    
    if selfRef.checking.debugger == nil {
        try init_swift(selfRef)
    }
    
    // Start up a new thread to collect stdout.
    let stdout_handler = SwiftModule.StdoutHandler(selfRef)
    stdout_handler.start()
    
    var result: Any
    
    // Execute the cell, handle unexpected exceptions, and make sure to
    // always clean up the stdout handler.
    do {
        defer {
            stdout_handler.stop_event.set()
            stdout_handler.join()
        }
        
        result = try execute_cell(selfRef, code)
    } catch let e {
        try send_exception_report(selfRef, "execute_cell", e)
        throw e
    }
    
    // Send values/errors and status to the client.
    if let result = result as? SuccessWithValue {
        try selfRef.send_response.throwing
            .dynamicallyCall(withArguments: selfRef.iopub_socket, "execute_result", [
            "execution_count": selfRef.execution_count,
            "data": {
                "text/plain": String(describing: result.result)
            },
            "metadata": [:]
        ])
        
        return [
            "status": "ok",
            "execution_count": selfRef.execution_count,
            "payload": [],
            "user_expressions": [:]
        ]
    }
    
    fatalError()
}

fileprivate struct Exception: LocalizedError {
    var errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

fileprivate func after_successful_execution(_ selfRef: PythonObject) throws {
    let result = execute(selfRef, code:
                         "JupyterKernel.communicator.triggerAfterSuccessfulExecution()")
    guard let result = result as? SuccessWithValue else {
        selfRef.log.error(
            "Expected value from triggerAfterSuccessfulExecution(), " +
            "but got: \(result)")
        return
    }
    
    let messages = try read_jupyter_messages(selfRef, result.result)
    try send_jupyter_messages(selfRef, messages)
}

fileprivate func read_jupyter_messages(_ selfRef: PythonObject, _ sbvalue: PythonObject) throws -> PythonObject {
    ["display_messages": try sbvalue.map { 
        display_message_sbvalue in try read_display_message(selfRef, display_message_sbvalue)
    }].pythonObject
}

fileprivate func read_display_message(_ selfRef: PythonObject, _ sbvalue: PythonObject) throws -> PythonObject {
    try sbvalue.map { part in try read_byte_array(selfRef, part) }.pythonObject
}

fileprivate func read_byte_array(_ selfRef: PythonObject, _ sbvalue: PythonObject) throws -> PythonObject {
    let get_address_error = lldb.SBError()
    let address = sbvalue
        .GetChildMemberWithName("address")
        .GetData()
        .GetAddress(get_address_error, 0)
    if Bool(get_address_error.Fail())! {
        throw Exception("getting address: \(get_address_error)")
    }
    
    let get_count_error = lldb.SBError()
    let count_data = sbvalue
        .GetChildMemberWithName("count")
        .GetData()
    var count: PythonObject
    
    switch Int(selfRef._int_bitwidth)! {
    case 32: count = count_data.GetSignedInt32(get_count_error, 0)
    case 64: count = count_data.GetSignedInt64(get_count_error, 0)
    default:
        throw Exception("Unsupported integer bitwidth: \(selfRef._int_bitwidth)")
    }
    if Bool(get_count_error.Fail())! {
        throw Exception("getting count: \(get_count_error)")
    }
    
    // ReadMemory requires that count is positive, so early-return an empty
    // byte array when count is 0.
    if count == 0 {
        return Python.bytes()
    }
    
    let get_data_error = lldb.SBError()
    let data = selfRef.process.ReadMemory(address, count, get_data_error)
    if Bool(get_data_error.Fail())! {
        throw Exception("getting data: \(get_data_error)")
    }
    
    return data
}

fileprivate func send_jupyter_messages(_ selfRef: PythonObject, _ messages: PythonObject) throws {
    let function = selfRef.iopub_socket.send_multipart.throwing
    for display_message in messages["display_messages"] {
        try function.dynamicallyCall(withArguments: display_message)
    }
}

fileprivate func set_parent_message(_ selfRef: PythonObject) throws {
    let jsonDumps = json.dumps(json.dumps(squash_dates(selfRef._parent_header)))
    let result = execute(selfRef, code: PythonObject("""
                         JupyterKernel.communicator.updateParentMessage(
                             to: KernelCommunicator.ParentMessage(json: \(jsonDumps)))
                         """))
    if result is ExecutionResultError {
        throw Exception("Error setting parent message: \(result)")
    }
}

fileprivate func get_pretty_main_thread_stack_trace(_ selfRef: PythonObject) -> [PythonObject] {
    var stack_trace: [PythonObject] = []
    for frame in selfRef.main_thread {
        // Do not include frames without source location information. These
        // are frames in libraries and frames that belong to the LLDB
        // expression execution implementation.
        guard let file = Optional(frame.line_entry.file) else {
            continue
        }
        
        // Do not include <compiler-generated> frames. These are
        // specializations of library functions.
        guard file.fullpath != "<compiler-generated>" else {
            continue
        }
        
        stack_trace.append(Python.str(frame))
    }
    
    return stack_trace
}

fileprivate func make_execute_reply_error_message(_ selfRef: PythonObject, _ traceback: PythonObject) -> PythonObject {
    [
        "status": "error",
        "execution_count": selfRef.execution_count,
        "ename": "",
        "evalue": "",
        "traceback": traceback
    ]
}

fileprivate func send_iopub_error_message(_ selfRef: PythonObject, _ traceback: PythonObject) throws {
    try selfRef.send_response.throwing
        .dynamicallyCall(withArguments: selfRef.iopub_socket, "error", [
        "ename": "",
        "evalue": "",
        "traceback": traceback
    ])
}

fileprivate func send_exception_report(_ selfRef: PythonObject, _ while_doing: PythonObject, _ e: Any) throws {
     try send_iopub_error_message(selfRef, [
         "Kernel is in a bad state. Try restarting the kernel.",
         "",
         "Exception in `\(while_doing)`:".pythonObject,
         String(describing: e).pythonObject
     ])
}

fileprivate func execute_cell(_ selfRef: PythonObject, _ code: PythonObject) throws -> Any {
    try set_parent_message(selfRef)
    let result = try preprocess_and_execute(selfRef, code: code)
    if result is ExecutionResultSuccess {
        try after_successful_execution(selfRef)
    }
    
    return result
}
