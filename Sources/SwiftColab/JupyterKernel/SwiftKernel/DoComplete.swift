import Foundation
import PythonKit

func doComplete(_ kwargs: PythonObject) throws -> PythonObject {
    let selfRef = kwargs["self"]
    
    if !Bool(selfRef.completion_enabled)! {
        let cursor_pos = kwargs["cursor_pos"]
        
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
