import Foundation
import PythonKit

fileprivate let json = Python.import("json")
fileprivate let lldb = Python.import("lldb")

func do_execute(_ kwargs: PythonObject) throws -> PythonObject {
    let selfRef = kwargs["self"]
    
    if !Bool(kwargs["silent"])! {
        let stream_content: PythonObject = ["name": "stdout", "text": kwargs["code"]]
        
        let throwingObject = selfRef.send_response.throwing
        try throwingObject.dynamicallyCall(withArguments: selfRef.iopub_socket, "stream", stream_content)
    }
    
    return [
        "status": "ok",
        // The base class increments the execution count
        "execution_count": selfRef.execution_count,
        "payload": [],
        "user_expressions": [:],
    ]
}

fileprivate struct Exception: LocalizedError {
    var errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

fileprivate func after_successful_execution(_ selfRef: PythonObject) throws {
    
}

fileprivate func read_jupyter_messages(_ selfRef: PythonObject, _ sbvalue: PythonObject) throws -> PythonObject {
    
}

fileprivate func read_display_message(_ selfRef: PythonObject, _ sbvalue: PythonObject) throws -> PythonObject {
    
}

fileprivate func read_byte_array(_ selfRef: PythonObject, _ sbvalue: PythonObject) throws -> PythonObject) {
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
}
