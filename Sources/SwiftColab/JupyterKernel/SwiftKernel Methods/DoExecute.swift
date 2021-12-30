import Foundation
import PythonKit

fileprivate let ioloop = Python.import("tornado").ioloop
fileprivate let json = Python.import("json")
fileprivate let lldb = Python.import("lldb")
fileprivate let squash_dates = Python.import("jupyter_client").jsonutil.squash_dates
fileprivate let SwiftModule = Python.import("Swift")
fileprivate let time = Python.import("time")

func do_execute(_ kwargs: PythonObject) throws -> PythonObject {
    let selfRef = kwargs["self"]
    var code = kwargs["code"]
    
    // Return early if the code is empty or whitespace, to avoid
    // initializing Swift and preventing package installs.
    if Int(Python.len(code))! == 0 || Bool(code.isspace())! {
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
        let array = [e.localizedDescription].pythonObject
        
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
    
    let emptyResponse: PythonObject = [
        "status": "ok",
        "execution_count": selfRef.execution_count,
        "payload": [],
        "user_expressions": [:]
    ]
    
    // Send values/errors and status to the client.
    if let result = result as? SuccessWithValue {
        var description = String(result.result[dynamicMember: "description"])!
        if description == "None" { description = "" }
        
        try selfRef.send_response.throwing
            .dynamicallyCall(withArguments: selfRef.iopub_socket, "execute_result", [
            "execution_count": selfRef.execution_count,
            "data": [
                "text/plain": PythonObject(description)
            ],
            "metadata": [:]
        ])
        
        return emptyResponse
    } else if result is SuccessWithoutValue {
        return emptyResponse
    } else if let result = result as? ExecutionResultError {
        if !Bool(selfRef.process.is_alive)! {
            selfRef.send_iopub_error_message(selfRef, ["Process killed"])
            
            // Exit the kernel because there is no way to recover from a
            // killed process. The UI will tell the user that the kernel has
            // died and the UI will automatically restart the kernel.
            // We do the exit in a callback so that this execute request can
            // cleanly finish before the kernel exits.
            let loop = ioloop.IOLoop.current()
            loop.add_timeout(time.time() + 0.1, loop.stop)
            
            return make_execute_reply_error_message(selfRef, ["Process killed"])
        }
        
        if Bool(stdout_handler.had_stdout)! {
            // When there is stdout, it is a runtime error. Stdout, which we
            // have already sent to the client, contains the error message
            // (plus some other ugly traceback that we should eventually
            // figure out how to suppress), so this block of code only needs
            // to add a traceback.
            let stackTrace = get_pretty_main_thread_stack_trace(selfRef)
            let traceback = PythonObject(["Current stack trace:"] + stackTrace.map { "\t\($0)" })
            
            try send_iopub_error_message(selfRef, traceback)
            return make_execute_reply_error_message(selfRef, traceback)
        }
        
        // There is no stdout, so it must be a compile error. Simply return
        // the error without trying to get a stack trace.
        let array = [result.description].pythonObject
        try send_iopub_error_message(selfRef, array)
        return make_execute_reply_error_message(selfRef, array)
    } else {
        fatalError("`execute()` produced an unexpected return type.")
    }
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
    var output: [PythonObject] = []
    
    for display_message_sbvalue in sbvalue {
        output.append(try read_display_message(selfRef, display_message_sbvalue))
    }
    
    return ["display_messages": output.pythonObject]
}

fileprivate func read_display_message(_ selfRef: PythonObject, _ sbvalue: PythonObject) throws -> PythonObject {
    var output: [PythonObject] = []
    
    for part in sbvalue {
        output.append(try read_byte_array(selfRef, part))
    }
    
    return output.pythonObject
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
    if Int(count)! == 0 {
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
    func encode(_ input: PythonObject) throws -> PythonObject {
        try json.dumps.throwing.dynamicallyCall(withArguments: input)
    }
    
    let jsonDumps = try encode(try encode(squash_dates(selfRef._parent_header)))
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
        let file = frame.line_entry.file
        guard file != Python.None else {
            continue
        }
        
        // Do not include <compiler-generated> frames. These are
        // specializations of library functions.
        guard String(file.fullpath)! != "<compiler-generated>" else {
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
