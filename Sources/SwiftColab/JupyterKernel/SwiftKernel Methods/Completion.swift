import Foundation
import PythonKit

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

func do_complete(_ kwargs: PythonObject) -> PythonObject {
    let selfRef = kwargs["self"]
    let cursor_pos = kwargs["cursor_pos"]
    
    func getReturnValue(matches: [PythonObject], cursor_start: PythonObject) -> PythonObject {
        [
            "status": "ok",
            "matches": PythonObject(matches),
            "cursor_start": cursor_start,
            "cursor_end": cursor_pos,
        ]
    }
    
    if !Bool(selfRef.completion_enabled)! {
        return getReturnValue(matches: [], cursor_start: cursor_pos)
    }
    
    let code = kwargs["code"]
    let code_to_cursor = code[(..<cursor_pos).pythonObject]
    let sbresponse = selfRef.target.CompleteCode(
        selfRef.swift_language, Python.None, code_to_cursor)
    
    let `prefix` = sbresponse.GetPrefix()
    var insertable_matches: [PythonObject] = []
    
    for i in Python.range(sbresponse.GetNumMatches()) {
        let sbmatch = sbresponse.GetMatchAtIndex(i)
        let insertable_match = `prefix` + sbmatch.GetInsertable()
        if insertable_match.startswith("_") {
            continue
        }
        
        insertable_matches.append(insertable_match)
    }
    
    return getReturnValue(matches: insertable_matches, 
                          cursor_start: cursor_pos - Python.len(`prefix`))
}
