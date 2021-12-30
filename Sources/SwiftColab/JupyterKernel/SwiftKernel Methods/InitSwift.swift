import Foundation
import PythonKit

fileprivate let json = Python.import("json")
fileprivate let lldb = Python.import("lldb")
fileprivate let os = Python.import("os")
fileprivate let SwiftModule = Python.import("Swift")
fileprivate let sys = Python.import("sys")

/// Initializes Swift so that it's ready to start executing user code.
///
/// This must happen after package installation, because the ClangImporter
/// does not see modulemap files that appear after it has started.
func init_swift(_ selfRef: PythonObject) throws {
    try init_repl_process(selfRef)
    try init_kernel_communicator(selfRef)
    try init_int_bitwidth(selfRef)
    init_sigint_handler(selfRef)
    
    // We do completion by default when the toolchain has the SBTarget.CompleteCode API.
    // The user can disable/enable using "%disableCompletion" and "%enableCompletion".
    selfRef.completion_enabled = selfRef.target.checking.CompleteCode ?? Python.None
}

fileprivate struct Exception: LocalizedError {
    var errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

fileprivate func init_repl_process(_ selfRef: PythonObject) throws {
    let debugger = lldb.SBDebugger.Create()
    guard debugger != Python.None else {
        throw Exception("could not start debugger")
    }
    
    selfRef.debugger = debugger
    debugger.SetAsync(false)
    
    if let search_path = selfRef.checking.swift_module_search_path {
        debugger.HandleCommand("settings append target.swift-module-search-paths \(search_path)")
    }
    
    // LLDB crashes while trying to load some Python stuff on Mac. Maybe
    // something is misconfigured? This works around the problem by telling
    // LLDB not to load the Python scripting stuff, which we don't use
    // anyways.
    debugger.SetScriptLanguage(lldb.eScriptLanguageNone)
    
    let repl_swift = "/opt/swift/toolchain/usr/bin/repl_swift"
    let target = debugger.CreateTargetWithFileAndArch(repl_swift, "")
    guard target != Python.None else {
        throw Exception("Could not create target \(repl_swift)")
    }
    
    selfRef.target = target
    
    let main_bp = target.BreakpointCreateByName("repl_main", target.GetExecutable().GetFilename())
    guard main_bp != Python.None else {
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
    
    let process = target.LaunchSimple(Python.None, PythonObject(repl_env), os.getcwd())
    guard process != Python.None else {
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
    if let result = try preprocess_and_execute(selfRef, code:
        "%include \"KernelCommunicator.swift\"".pythonObject) as? ExecutionResultError {
        throw Exception("Error initializing KernelCommunicator: \(String(reflecting: result))")
    }
    
    func encode(_ input: PythonObject) throws -> PythonObject {
        try json.dumps.throwing.dynamicallyCall(withArguments: input)
    }
    
    let session = selfRef.session
    let id = try encode(session.session)
    let key = try encode(session.key.decode("utf8"))
    let username = try encode(session.username)
    
    let decl_code = PythonObject("""
    enum JupyterKernel {
        static var communicator = KernelCommunicator(
            jupyterSession: KernelCommunicator.JupyterSession(
                id: \(id), key: \(key), username: \(username)))
    }
    """)
    
    if let result = try preprocess_and_execute(selfRef, code: decl_code) as? ExecutionResultError {
        throw Exception("Error declaring JupyterKernel: \(String(reflecting: result))")
    }
}

fileprivate func init_int_bitwidth(_ selfRef: PythonObject) throws {
    let result = execute(selfRef, code: "Int.bitWidth")
    guard let result = result as? SuccessWithValue else {
        throw Exception("Expected value from Int.bitWidth, but got: \(String(reflecting: result))")
    }
    
    selfRef._int_bitwidth = Python.int(result.result.GetData().GetSignedInt32(lldb.SBError(), 0))
}

fileprivate func init_sigint_handler(_ selfRef: PythonObject) {
    selfRef.sigint_handler = SwiftModule.SIGINTHandler(selfRef)
    selfRef.sigint_handler.start()
}
