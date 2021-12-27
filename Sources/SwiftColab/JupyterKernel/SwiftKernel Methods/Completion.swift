import Foundation
import PythonKit

func do_complete(_ kwargs: PythonObject) throws -> PythonObject {
    let selfRef = kwargs["self"]
    let cursor_pos = kwargs["cursor_pos"]
    
    if !Bool(selfRef.completion_enabled)! {
        return [
            "status": "ok",
            "matches": [],
            "cursor_start": cursor_pos,
            "cursor_end": cursor_pos,
        ]
    }
    
    struct CompletionNotImplementedError: LocalizedError {
        let errorDescription: String? = "`do_complete` has not been implemented for the Swift Kernel."
    }
    
    throw CompletionNotImplementedError()
}

func handle_disable_completion(_ selfRef: PythonObject) throws {
    selfRef.completion_enabled = false
    try send_response(selfRef, text: "Completion disabled!\n")
}

func handle_enable_completion(_ selfRef: PythonObject) throws {
    guard Bool(Python.hasattr(selfRef.target, "CompleteCode"))! else {
        try send_response(selfRef, text: "Completion NOT enabled because toolchain does not " +
                                         "have CompleteCode API.\n")
        return
    }
    
    selfRef.completion_enabled = true
    try send_response(selfRef, text: "Completion enabled!\n")
}

fileprivate func send_response(_ selfRef: PythonObject, text: String) throws {
    try selfRef.send_response.throwing
        .dynamicallyCall(withArguments: selfRef.iopub_socket, "stream", [
        "name": "stdout",
        "text": message
    ])
}
