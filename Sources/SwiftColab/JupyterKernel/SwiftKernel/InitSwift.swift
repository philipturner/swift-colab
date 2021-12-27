import Foundation
import PythonKit
let lldb = Python.import("lldb")

/// Initializes Swift so that it's ready to start executing user code.
///
/// This must happen after package installation, because the ClangImporter
/// does not see modulemap files that appear after it has started.
func init_swift(_ selfRef: PythonObject) throws {
    try init_repl_process(selfRef)
    try init_kernel_communicator(selfRef)
    try init_int_bitwidth(selfRef)
    try init_sigint_handler(selfRef)
    
    // We do completion by default when the toolchain has the SBTarget.CompleteCode API.
    // The user can disable/enable using "%disableCompletion" and "%enableCompletion".
    selfRef.completion_enabled = Python.hasattr(selfRef.target, "CompleteCode")
}

fileprivate struct Exception: LocalizedError {
    var errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

func init_repl_process(_ selfRef: PythonObject) throws {
    selfRef.debugger = lldb.SBDebugger.Create()
    if selfRef.debugger == Python.None {
        throw Exception("could not start debugger")
    }
    selfRef.debugger.SetAsync(false)
}
