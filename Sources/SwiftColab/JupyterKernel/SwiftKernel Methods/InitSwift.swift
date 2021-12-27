import Foundation
import PythonKit
fileprivate let lldb = Python.import("lldb")
fileprivate let os = Python.import("os")
fileprivate let sys = Python.import("sys")

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

fileprivate func init_repl_process(_ selfRef: PythonObject) throws {
    guard let debugger = Optional(lldb.SBDebugger.Create()) else {
        throw Exception("could not start debugger")
    }
    
    selfRef.debugger = debugger
    debugger.SetAsync(false)
    
    if Bool(Python.hasattr(selfRef, "swift_module_search_path"))! {
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
    
    selfRef.target = target
    
    guard let main_bp = Optional(target.BreakpointCreateByName(
        "repl_main", target.GetExecutable().GetFileName())) else {
        throw Exception("Could not set breakpoint")
    }
    
    selfRef.main_bp = main_bp
    
    let script_dir = os.path.dirname(os.path.realpath(sys.argv[0]))
    var repl_env: [String] = ["PYTHONPATH=\(script_dir)"]
    
    for key in os.environ {
        guard key != "PYTHONPATH", 
              key != "REPL_SWIFT_PATH" else {
            continue
        }
        
        repl_env.append("\(key)=\(os.environ[key])")
    }
    
    // Turn off "disable ASLR" because it uses the "personality" syscall in
    // a way that is forbidden by the default Docker security policy.
    let launch_info = target.GetLaunchInfo()
    let launch_flags = launch_info.GetLaunchFlags()
    launch_info.SetLaunchFlags(launch_flags & ~lldb.eLaunchFlagDisableASLR)
    target.SetLaunchInfo(launch_info)
    
    guard let process = Optional(target.LaunchSimple(Python.None,
                                                     PythonObject(repl_env),
                                                     os.getcwd())) else {
        throw Exception("Could not launch process")
    }
    
    selfRef.process = process
    
    let expr_opts = lldb.SBExpressionOptions()
    let swift_language = lldb.SBLanguageRuntime.GetLanguageTypeFromString("swift")
    selfRef.expr_opts = expr_opts
    selfRef.swift_language = swift_language
    
    expr_opts.SetLanguage(swift_language)
    expr_opts.SetREPLMode(true)
    expr_opts.SetUnwindOnError(false)
    expr_opts.SetGenerateDebugInfo(true)
    
    // Sets an infinite timeout so that users can run aribtrarily long computations.
    expr_opts.SetTimeoutInMicroSeconds(0)
    
    selfRef.main_thread = process.GetThreadAtIndex(0)
}

fileprivate func init_kernel_communicator(_ selfRef: PythonObject) throws {
    if let result = preprocess_and_execute(selfRef, code:
        "%include KernelCommunicator.swift".pythonObject) as? ExecutionResultError {
        throw Exception("Error initializing KernelCommunicator: \(String(reflecting: result))")
    }
    
}

fileprivate func init_int_bitwidth(_ selfRef: PythonObject) throws {
    
}

fileprivate func init_sigint_handler(_ selfRef: PythonObject) throws {
    
}
