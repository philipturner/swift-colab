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

// Caller side: use `ctypes` to convert return value, which is the address of a
// Python object, into an actual Python object. This Swift file stores a
// reference to the return value's object so that it doesn't deallocate.
@_cdecl("create_shell")
public func create_shell(
  _ username_ptr: UnsafePointer<CChar>,
  _ sessionID_ptr: UnsafePointer<CChar>, 
  _ key_ptr: UnsafePointer<CChar>
) -> Int64 {
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
    
    // -------------------------------------------------------------------------
    // InteractiveShell interface
    // -------------------------------------------------------------------------
    
    // Enable GUI integration for the kernel.
    "enable_gui": PythonInstanceMethod { (args: [PythonObject]) in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      `self`.active_eventloop = gui
      return Python.None
    },
    
    // Enable matplotlib integration for the kernel.
    "enable_matplotlib": PythonInstanceMethod { (args: [PythonObject]) in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      try ZMQInteractiveShell.enable_matplotlib.throwing
        .dynamicallyCall(withArguments: [`self`, gui])
      return Python.None
    },
    
    // Enable pylab support at runtime.
    "enable_pylab": PythonInstanceMethod { (args: [PythonObject]) in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      try ZMQInteractiveShell.enable_pylab.throwing
        .dynamicallyCall(withArguments: [`self`, gui])
      return Python.None
    }
  ]
).pythonObject
