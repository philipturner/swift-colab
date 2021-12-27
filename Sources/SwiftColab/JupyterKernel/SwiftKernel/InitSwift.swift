import Foundation
import PythonKit
fileprivate let lldb = Python.import("lldb")
fileprivate let os = Python.import("os")

/// Initializes Swift so that it's ready to start executing user code.
///
/// This must happen after package installation, because the ClangImporter
/// does not see modulemap files that appear after it has started.
func initSwift(_ selfRef: PythonObject) throws {
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
    guard let debugger = Optional(lldb.SBDebugger.Create()) else {
        throw Exception("could not start debugger")
    }
    
    selfRef.debugger = debugger
    debugger.SetAsync(false)
    
    if Python.hasattr(selfRef, "swift_module_search_path") {
        debugger.HandleCommand("setings append target.swift-module-search-paths \(selfRef.swift_module_search_path)")
    }
    
    // LLDB crashes while trying to load some Python stuff on Mac. Maybe
    // something is misconfigured? This works around the problem by telling
    // LLDB not to load the Python scripting stuff, which we don't use
    // anyways.
    debugger.SetScriptLanguage(lldb.eScriptLanguageNone)
    
    let repl_swift = os.environ["REPL_SWIFT_PATH"]
    guard let target = Optional(debugger.CreateTargetWithFileAndArch(repl_swift, "")) else {
        throw Exception("Could not create target \(repl_swift)")
    }
    
    self.target = target
    
    guard let main_bp = Optional(target.BreakpointCreateByName(
        "repl_main", target.GetExecutable().GetFileName())) else {
        throw Exception("Could not set breakpoint")
    }
    
    self.main_bp = main_bp
    
    let script_dir = os.path.dirname(os.path.realpath(sys.argv[0]))
    var repl_env: [PythonObject] = ["PYTHONPATH=\(script_dir)"]
    
    for key in os.environ {
        guard key != "PYTHONPATH", 
              key != "REPL_SWIFT_PATH" else {
            continue
        }
        
        repl_env.append("\(key)=\(os.environ[key])")
    }
    
    // Turn off "disable ASLR" because it uses the "personality" syscall in
    // a way that is forbidden by the default Docker security policy.
    
}
