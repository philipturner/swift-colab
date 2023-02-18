import Foundation

@_cdecl("JupyterKernel_createSwiftKernel")
public func JupyterKernel_createSwiftKernel() {
  KernelContext.log("Started creating Swift kernel233")
  let fm = FileManager.default
  func read(path: String) -> String {
    let data = fm.contents(atPath: path)!
    return String(data: data, encoding: .utf8)!.lowercased()
  }
  
  let currentRuntime = read(path: "/opt/swift/runtime")
  let currentMode = read(path: "/opt/swift/mode")
  
  // Whether to automatically alternate between runtimes.
  let isRelease = currentMode.contains("release")
  let runtime1 = isRelease ? "python3" : "swift"
  let runtime2 = isRelease ? "swift" : "python3"
  
  let nextRuntime = currentRuntime.contains("python") ? runtime1 : runtime2
  fm.createFile(
    atPath: "/opt/swift/runtime", contents: nextRuntime.data(using: .utf8)!)
  
  // In dev mode, switch back into Python mode on the next runtime restart. This 
  // makes debugging a lot easier and decreases the chance my main account will 
  // be kicked off of Colab for excessive restarts/downloads.
  if currentRuntime.contains("python") {
    activatePythonKernel()
  } else {
    activateSwiftKernel()
  }
  KernelContext.log("Ended creating Swift kerne233")
}

// A stored reference to the SwiftKernel type object, used as a workaround for 
// the fact that it must be initialized in Python code.
fileprivate var preservedSwiftKernelRef: PythonObject!

@_cdecl("JupyterKernel_constructSwiftKernelClass")
public func JupyterKernel_constructSwiftKernelClass(_ classObj: OpaquePointer) {
  KernelContext.log("Started creating Swift kernel class233")
  let SwiftKernel = PythonObject(OwnedPyObjectPointer(classObj))
  preservedSwiftKernelRef = SwiftKernel
  
  SwiftKernel.implementation = "swift"
  SwiftKernel.implementation_version = "0.1"
  SwiftKernel.banner = ""
  
  SwiftKernel.language_info = [
    "name": "swift",
    "mimetype": "text/x-swift",
    "file_extension": ".swift",
    "version": ""
  ]
  
  SwiftKernel.do_execute = PythonInstanceMethod { args in
    if !KernelContext.debuggerInitialized {
      KernelContext.kernel = args[0]
      try initSwift()
      KernelContext.debuggerInitialized = true
      KernelContext.log("finished initSwift")
    }
    
    let code = String(args[1])!
    let allowStdin = Bool(args[5])!
    let response = try doExecute(code: code, allowStdin: allowStdin)
    return response ?? [
      "status": "ok",
      "execution_count": PythonObject(KernelContext.cellID),
      "payload": [],
      "user_expressions": [:],
    ]
  }.pythonObject
  KernelContext.log("Ended creating Swift kernel class233")
}

fileprivate func activateSwiftKernel() {
  print("=== Activating Swift kernel ===")
  
  // Jupyter sends us SIGINT when the user requests execution interruption.
  // Here, we block all threads from receiving the SIGINT, so that we can
  // handle it in a specific handler thread.
  let signal = Python.import("signal")
  signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
  
  // Must create this from a Python script declaration. Using the built-in
  // `type(_:_:_:)` method makes it `traitlets.traitlets.SwiftKernel`
  // instead of `__main__.SwiftKernel`.
  PyRun_SimpleString("""
    from ctypes import *; from ipykernel.kernelbase import Kernel
    class SwiftKernel(Kernel):
        def __init__(self, **kwargs):
            super().__init__(**kwargs)

    func = PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_constructSwiftKernelClass
    func.argtypes = [c_void_p]; func(c_void_p(id(SwiftKernel)))
    """)
  
  KernelContext.log("A")
  KernelContext.log("\(Python.import("__main__"))")
  KernelContext.log("B")
  KernelContext.log("\(Python.import("__main__").SwiftKernel)")
  KernelContext.log("C")
  KernelContext.log("\(Python.import("__main__").SwiftKernel.__class__)")
  KernelContext.log("D")
  
  KernelContext.log("Debug checkpoint 015")
  let IPKernelApp = Python.import("ipykernel.kernelapp").IPKernelApp
  KernelContext.log("Debug checkpoint 115")
  PyRun_SimpleString("""
    from ipykernel.kernelapp import IPKernelApp
    try: 
        print("at least started4")
        IPKernelApp.launch_instance(argv=\(CommandLine.arguments) + ['--IPKernelApp.kernel_class=__main__.SwiftKernel'])
    except AssertionError as err:
        print("AssertionError recognized2:", err)
    except BaseException as err:
        print("BaseException recognized2:", err)
    except Exception as err:
        print("Exception recognized2:", err)
    """)
  KernelContext.log("Debug checkpoint 447")

  // We pass the kernel name as a command-line arg, since Jupyter gives those
  // highest priority (in particular overriding any system-wide config).
  do {
    // TODO: To prevent this from failing ever again, always print errors
    // encountered here to '/opt/swift/log'.
  try IPKernelApp.launch_instance.throwing.dynamicallyCall(withKeywordArguments:
    [(key: "argv", value: CommandLine.arguments + 
        ["--IPKernelApp.kernel_class=__main__.SwiftKernel"]
    )])
  } catch let error as PythonError {
    KernelContext.log("Python error occurred: start")
    KernelContext.log(error.description)
    KernelContext.log("Python error occurred: end")
  } catch let error {
    KernelContext.log("Unknown error occurred: start")
    KernelContext.log("\(error.localizedDescription)")
    KernelContext.log("Unknown error occurred: end")
  }
  KernelContext.log("Debug checkpoint 2123")
}

// The original Python kernel. There is no way to get it run besides
// passing a string into the Python interpreter. No component of this
// string can be extracted into Swift.
fileprivate func activatePythonKernel() {
  print("=== Activating Python kernel ===")
  
  // Remove the CWD from sys.path while we load stuff.
  // This is added back by InteractiveShellApp.init_path()
  PyRun_SimpleString("""
    import sys; from ipykernel import kernelapp as app
    if sys.path[0] == "":
        del sys.path[0]

    app.launch_new_instance()          
    """)
}
