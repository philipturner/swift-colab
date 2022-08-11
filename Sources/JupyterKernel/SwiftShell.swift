import Foundation
fileprivate let eventloops = Python.import("ipykernel.eventloops")
fileprivate let interactiveshell = Python.import("IPython.core.interactiveshell")
fileprivate let session = Python.import("jupyter_client.session")
fileprivate let traitlets = Python.import("traitlets")
fileprivate let zmqshell = Python.import("ipykernel.zmqshell")

fileprivate let InteractiveShellABC = interactiveshell.InteractiveShellABC
fileprivate let Session = session.Session
fileprivate let Instance = traitlets.Instance
fileprivate let ZMQInteractiveShell = zmqshell.ZMQInteractiveShell

// PythonKit sometimes hangs indefinitely when you import NumPy. In turn, this
// causes matplotlib and other Python libraries depending on NumPy to hang. The
// culprit is some Python code that executes automatically when you import the
// module. I cannot reproduce the hang/freeze while running Colab in Python
// mode. Although, I have observed it while running Python code via
// `PyRun_SimpleString` from within PythonKit (while Colab is in Swift mode).
//
// In `numpy.core._add_newdocs_scalars`, it tries generating documentation for
// some scalar types at runtime. While generating the documentation, it calls
// `platform.system()` and `platform.machine()` from the built-in `platform`
// library. It sometimes freezes while calling those functions. However, it
// doesn't freeze if you call one of those functions long before loading NumPy.
//
// The workaround requires calling `system()` or `machine()` from the same
// process that imports NumPy. The Jupyter kernel loads and executes this symbol
// from within `KernelCommunicator.swift`, which runs inside the Swift
// interpreter.
@_cdecl("prevent_numpy_import_hang")
public func prevent_numpy_import_hang() {
  let platform = Python.import("platform")
  _ = platform.system()
}

@_cdecl("fetch_pipes")
public func fetch_pipes() {
  KernelPipe.fetchPipes(currentProcess: .lldb)
}

@_cdecl("redirect_stdin")
public func redirect_stdin() {
  let _message = Python.import("google.colab")._message
  _message.blocking_request = PythonFunction { args, kwargs in
    func fetchArgument(_ key: String) -> PythonObject {
      if let index = kwargs.firstIndex(where: { $0.key == key }) {
        return kwargs[index].value
      } else {
        return Python.None
      }
    }
    let input = encode_blocking_request(
      args[0], 
      request: fetchArgument("request"), 
      timeout_sec: fetchArgument("timeout_sec"), 
      parent: fetchArgument("parent"))
    KernelPipe.send(input, to: .jupyterKernel)
    
    while true {
      usleep(50_000)
      let messages = KernelPipe.recv(from: .jupyterKernel)
      precondition(messages.count <= 1, "Received more than one message.")
      if messages.count == 0 {
        continue
      }
      return try decode_blocking_request(messages[0])
    }
  }.pythonObject
}

@_cdecl("test_pythonkit_fix")
public func test_pythonkit_fix() {
  let display = Python.import("IPython.display")
  let pd = Python.import("pandas")
  let array: [PythonObject] = [
    ["col 1": 3, "col 2": 5, "col 3": 4, "col3 ": 5],
    ["col 1": 8, "col 2": 2, "col 3": 4]
  ]
  print(array)
  display.display(pd.DataFrame.from_records(array))
}

// Caller side: use `ctypes` to convert return value, which is the address of a
// Python object, into an actual Python object. This Swift file stores a
// reference to the return value's object so that it doesn't deallocate.
@_cdecl("create_shell")
public func create_shell(
  _ username_ptr: UnsafePointer<CChar>,
  _ sessionID_ptr: UnsafePointer<CChar>, 
  _ key_ptr: UnsafePointer<CChar>
) -> Int64 {
  // If the user includes "EnableIPythonDisplay.swift" twice, don't regenerate
  // the socket and shell.
  if socketAndShell == nil {
    InteractiveShellABC.register(SwiftShell)
    
    let username = String(cString: username_ptr)
    let sessionID = String(cString: sessionID_ptr)
    let key = String(cString: key_ptr).pythonObject.encode("utf8")
    
    let socket = CapturingSocket()
    let session = Session(username: username, session: sessionID, key: key)
    let shell = SwiftShell.instance()
    shell.display_pub.session = session
    shell.display_pub.pub_socket = socket
    
    socketAndShell = [socket, shell]
  }
  return Int64(Python.id(socketAndShell))!
}

fileprivate var socketAndShell: PythonObject!

// Simulates a ZMQ socket, saving messages instead of sending them. We use this 
// to capture display messages.
fileprivate let CapturingSocket = PythonClass(
  "CapturingSocket",
  superclasses: [],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      `self`.messages = []
      return Python.None
    },
    
    "send_multipart": PythonInstanceMethod { args, kwargs in
      let `self` = args[0]
      let msg = args[1]
      `self`.messages[dynamicMember: "append"](msg)
      print("called send_multipart")
      return Python.None
    }
  ]
).pythonObject

// An IPython shell, modified to work within Swift.
fileprivate let SwiftShell = PythonClass(
  "SwiftShell",
  superclasses: [ZMQInteractiveShell],
  members: [
    "kernel": Instance(
      "ipykernel.inprocess.ipkernel.InProcessKernel", allow_none: true),
    
    // Enable GUI integration for the kernel.
    "enable_gui": PythonInstanceMethod { args in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      `self`.active_eventloop = gui
      return Python.None
    },
    
    // Enable matplotlib integration for the kernel.
    "enable_matplotlib": PythonInstanceMethod { args in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = args[0].kernel.gui
      }
      return try ZMQInteractiveShell.enable_matplotlib.throwing
        .dynamicallyCall(withArguments: [`self`, gui])
    },
    
    // Enable pylab support at runtime.
    "enable_pylab": PythonInstanceMethod { args in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      return try ZMQInteractiveShell.enable_pylab.throwing
        .dynamicallyCall(withArguments: `self`, gui)
    }
  ]
).pythonObject
