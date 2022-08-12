import Foundation
fileprivate let eventloops = Python.import("ipykernel.eventloops")
fileprivate let interactiveshell = Python.import("IPython.core.interactiveshell")
fileprivate let json = Python.import("json")
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
      // let `self` = args[0]
      let msg = args[1]
      // `self`.messages[dynamicMember: "append"](msg)
      print("started send_multipart")
      let input = encode_send_multipart(msg)
      KernelPipe.send(input, to: .jupyterKernel)
      
      while true {
        usleep(50_000)
        let messages = KernelPipe.recv(from: .jupyterKernel)
        precondition(messages.count <= 1, "Received more than one message.")
        if messages.count == 0 {
          continue
        }
        decode_send_multipart(messages[0])
        break
      }
      print("finished send_multipart")
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

//===----------------------------------------------------------------------===//
// Encoding and decoding messages between processes
//===----------------------------------------------------------------------===//

// Used in "PreprocessAndExecute.swift".
func execute_message(_ input: Data) -> Data {
  let input_str = String(data: input, encoding: .utf8)!
  let input_dict = json.loads(input_str.pythonObject)
  precondition(input_dict.count == 2, "Malformatted message.")
  
  switch String(input_dict[0]) {
  case "blocking_request":
    return execute_blocking_request(input_dict[1])
  case "send_multipart":
    KernelContext.stdoutHandler.flush()
    return execute_send_multipart(input_dict[1])
  default: // Includes `nil`.
    fatalError("Unrecognized message type '\(input_dict[0])'.")
  }
}

// blocking_request

fileprivate func encode_blocking_request(
  _ request_type: PythonObject,
  request: PythonObject,
  timeout_sec: PythonObject,
  parent: PythonObject
) -> Data {
  let input_dict = PythonObject([:])
  input_dict["request_type"] = request_type
  input_dict["request"] = request
  input_dict["timeout_sec"] = timeout_sec
  input_dict["parent"] = parent
  
  let input = PythonObject(["blocking_request", input_dict])
  let input_str = String(json.dumps(input))!
  return input_str.data(using: .utf8)!
}

fileprivate func execute_blocking_request(_ input: PythonObject) -> Data {
  let request_type = input["request_type"]
  let request = input["request"]
  let timeout_sec = input["timeout_sec"]
  let parent = input["parent"]
  
  let reply = blocking_request(
    request_type, request: request, timeout_sec: timeout_sec, parent: parent)
  let output = PythonObject(["blocking_request", reply])
  let output_str = String(json.dumps(output))!
  return output_str.data(using: .utf8)!
}

fileprivate func decode_blocking_request(_ input: Data) throws -> PythonObject {
  let input_str = String(data: input, encoding: .utf8)!
  let response = json.loads(input_str.pythonObject)
  precondition(response.count == 2, "Malformatted response.")
  precondition(
    response[0] == "blocking_request", 
    "Unexpected response type '\(response[0])'.")
  
  let reply = response[1]
  if reply.checking["error"] != nil {
    let _message = Python.import("google.colab")._message
    throw _message.MessageError(reply["error"])
  }
  return reply.checking["data"] ?? Python.None
}

// send_multipart

fileprivate func encode_send_multipart(_ msg: PythonObject) -> Data {
  var parts = [PythonObject](msg)!
  for i in 0..<parts.count {
    parts[i] = parts[i].decode("utf8")
  }
  let input = PythonObject(["send_multipart", PythonObject(parts)])
  let input_str = String(json.dumps(input))!
  return input_str.data(using: .utf8)!
}

// TODO: Scrap the StdoutHandler thread because we're already doing things
// asynchronously. Increase the rate of polling from 50_000 µs to 10_000 µs,
// which should minimize latency and make blocking actions more viable.
// TODO: Scrap the C++ code for serializing and deserializing images.
// TODO: Investigate whether this needs to be blocking/synchronous. If so, 
// consider doing some magic with Stdout to preserve order of execution while
// being asynchronous.
fileprivate func execute_send_multipart(_ input: PythonObject) -> Data {
  var parts = [PythonObject](input)!
  for i in 0..<parts.count {
    parts[i] = parts[i].encode("utf8")
  }
  let socket = KernelContext.kernel.iopub_socket
  socket.send_multipart(PythonObject(parts))

  let output = PythonObject(["send_request", Python.None])
  let output_str = String(json.dumps(output))!
  return output_str.data(using: .utf8)!
}

fileprivate func decode_send_multipart(_ input: Data) {
  let input_str = String(data: input, encoding: .utf8)!
  let response = json.load(input_str.pythonObject)
  precondition(response.count == 2, "Malformatted response.")
  precondition(
    response[0] == "send_request", 
    "Unexpected response type '\(response[0])'.")
}