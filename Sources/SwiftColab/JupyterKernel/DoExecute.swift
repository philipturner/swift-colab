import Foundation
import PythonKit
import SwiftPythonBridge

internal func doExecute(_ kwargs: PythonObject) throws -> PythonObject {
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
