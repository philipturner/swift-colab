import Foundation
import PythonKit
import SwiftPythonBridge

func doComplete(_ kwargs: PythonObject) throws -> PythonObject {
    let selfRef = kwargs["self"]
    
    struct CompletionNotImplementedError: LocalizedError {
        let errorDescription: String? = "`do_complete` has not been implemented for the Swift Kernel. After receiving this error message the first time, place it after the `if` statement."
    }
    
    throw CompletionNotImplementedError() // intentionally crashing before, not after the if statement to ensure it works
    
    if !Bool(selfRef.completion_enabled)! {
        let cursor_pos = kwargs["cursor_pos"]
        
        return [
            "status": "ok",
            "matches": [],
            "cursor_start": cursor_pos,
            "cursor_end": cursor_pos,
        ]
    }
}
