import Foundation
fileprivate let codecs = Python.import("codecs")
fileprivate let io = Python.import("io")
fileprivate let locale = Python.import("locale")
fileprivate let os = Python.import("os")
fileprivate let pexpect = Python.import("pexpect")
fileprivate let pty = Python.import("pty")
fileprivate let select = Python.import("select")
fileprivate let signal = Python.import("signal")
fileprivate let subprocess = Python.import("subprocess")
fileprivate let sys = Python.import("sys")
fileprivate let termios = Python.import("termios")
fileprivate let threading = Python.import("threading")
fileprivate let time = Python.import("time")
fileprivate let zmq = Python.import("zmq")

// Not possible to use Swift GCD in place of Python single-threaded threading 
// here.
let SIGINTHandler = PythonClass(
  "SIGINTHandler",
  superclasses: [threading.Thread],
  members: [
    "__init__": PythonInstanceMethod { args in
      let `self` = args[0]
      threading.Thread.__init__(`self`)
      `self`.daemon = true
      return Python.None
    },
    
    "run": PythonInstanceMethod { _ in
      while true {
        signal.sigwait([signal.SIGINT])
        _ = KernelContext.async_interrupt_process()
        KernelContext.isInterrupted = true
      }
      // Do not need to return anything because this is an infinite loop.
    }
  ]
).pythonObject

// Not possible to use Swift GCD in place of Python single-threaded threading 
// here.
let StdoutHandler = PythonClass(
  "StdoutHandler",
  superclasses: [threading.Thread],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      threading.Thread.__init__(`self`)
      `self`.daemon = true
      `self`.had_stdout = false
      return Python.None
    },
    
    "run": PythonInstanceMethod { (`self`: PythonObject) in
      while true {
        time.sleep(0.05)
        if !KernelContext.pollingStdout {
          break
        }
        getAndSendStdout(handler: `self`)
      }
      getAndSendStdout(handler: `self`)
      return Python.None
    },
    
    // Lets another Python thread ensure that all Stdout is handled before doing
    // something. Because this doesn't actually use multithreading, it is 
    // thread-safe.
    "flush": PythonInstanceMethod { (`self`: PythonObject) in
      precondition(
        KernelContext.pollingStdout, 
        "Only call 'StdoutHandler.flush' while executing a Jupyter cell.")
      getAndSendStdout(handler: `self`)
      return Python.None
    }.pythonObject
  ]
).pythonObject

fileprivate var cachedScratchBuffer: UnsafeMutablePointer<CChar>?

fileprivate func getStdout() -> String {
  var stdout = Data()
  let bufferSize = 1 << 16
  let scratchBuffer = cachedScratchBuffer ?? .allocate(capacity: bufferSize)
  cachedScratchBuffer = scratchBuffer
  while true {
    let stdoutSize = KernelContext.get_stdout(scratchBuffer, Int32(bufferSize))
    guard stdoutSize > 0 else {
      break
    }
    let stdoutSegment = Data(
      bytesNoCopy: scratchBuffer, count: Int(stdoutSize), deallocator: .none)
    stdout += stdoutSegment
  }
  return String(data: stdout, encoding: .utf8)!
}

fileprivate func sendStdout(_ stdout: String) {
  if let range = stdout.range(of: "\033[2J") {
    sendStdout(String(stdout[..<range.lowerBound]))
    KernelContext.sendResponse("clear_output", [
      "wait": false
    ])
    sendStdout(String(stdout[range.upperBound...]))
  } else {
    KernelContext.sendResponse("stream", [
      "name": "stdout",
      "text": stdout
    ])
  }
}

func getAndSendStdout(handler: PythonObject) {
  var stdout = getStdout()
  if stdout.count > 0 {
    if Bool(handler.had_stdout)! == false {
      // Remove header that signalled that the code successfully compiled.
      let header = "HEADER\r\n"
      precondition(stdout.hasPrefix(header), """
        Stdout did not start with the expected header "\(header)".
        Stdout was: \(stdout)
        """)
      stdout.removeFirst(header.count)
      handler.had_stdout = true
    }
    sendStdout(stdout)
  }
}

fileprivate var errorStreamEnd: Int = 0

func getStderr(readData: Bool) -> String? {
  let errorFilePointer = fopen("/opt/swift/err", "rb")!
  defer { fclose(errorFilePointer) }
  
  fseek(errorFilePointer, 0, SEEK_END)
  let newErrorStreamEnd = ftell(errorFilePointer)
  let messageSize = newErrorStreamEnd - errorStreamEnd
  defer { errorStreamEnd = newErrorStreamEnd }
  if messageSize == 0 || !readData {
    return nil
  }
  
  let errorDataPointer = malloc(messageSize)!
  fseek(errorFilePointer, errorStreamEnd, SEEK_SET)
  let readBytes = fread(errorDataPointer, 1, messageSize, errorFilePointer)
  precondition(readBytes == messageSize,
    "Did not read the expected number of bytes from stderr")
  
  return String(
    bytesNoCopy: errorDataPointer, length: messageSize, encoding: .utf8, 
    freeWhenDone: true)!
}

// Replicates functionality found at:
// https://github.com/googlecolab/colabtools/blob/main/google/colab/_system_commands.py
func runTerminalProcess(args: [String], cwd: String? = nil) throws -> Int {
  var cwd_pythonObject = Python.None
  if let cwd = cwd {
    cwd_pythonObject = PythonObject(cwd)
  }
  
  let joinedArgs = PythonObject(args.joined(separator: " "))
  let state = try _run_command(joinedArgs, cwd_pythonObject)
  return Int(state.returncode)!
}

//===----------------------------------------------------------------------===//
// ColabTools _message.py translation
//===----------------------------------------------------------------------===//

fileprivate let _NOT_READY = Python.object()

// Reads the next message from stdin_socket.
fileprivate func _read_next_input_message() -> PythonObject {
  let kernel = KernelContext.kernel
  let stdin_socket = kernel.stdin_socket
  var reply = Python.None
  
  do {
    let tuple = try kernel.session.recv.throwing.dynamicallyCall(
      withArguments: stdin_socket, zmq.NOBLOCK)
    (_, reply) = tuple.tuple2
  } catch {
    // We treat invalid messages as empty replies.
  }
  if reply == Python.None {
    return _NOT_READY
  }
  
  // We want to return '' even if reply is malformed.
  let content = reply.checking["content"] ?? PythonObject([:])
  return content.checking["value"] ?? ""
}

// Reads a stdin message.
fileprivate func _read_stdin_message() -> PythonObject {
  while true {
    let value = _read_next_input_message()
    if value == _NOT_READY {
      return Python.None
    }
    
    // Skip any colab responses.
    if Bool(Python.isinstance(value, Python.dict))!,
       value["type"] == "colab_reply" {
      continue
    }

    return value
  }
}

// Reads a reply to the message from the stdin channel.
fileprivate func read_reply_from_input(
  _ message_id: PythonObject,
  _ timeout_sec: PythonObject
) -> PythonObject {
  var deadline = Python.None
  if timeout_sec != Python.None {
    deadline = time.time() + timeout_sec
  }
  while Bool(deadline == Python.None)! || 
        Bool(time.time() < deadline)! {
    let reply = _read_next_input_message()
    if Bool(reply == _NOT_READY)! ||
       !Bool(Python.isinstance(reply, Python.dict))! {
      time.sleep(0.025)
      continue
    }
    if Bool(reply["type"] == "colab_reply")! &&
       Bool(reply["colab_msg_id"] == message_id)! {
      return reply
    }
  }
  return Python.None
}

// Global counter for message id.
fileprivate var _msg_id: PythonObject = 0

// Sends the given message to the frontend without waiting for a reply.
fileprivate func send_request(
  _ request_type: PythonObject,
  _ request_body: PythonObject,
  parent: PythonObject = Python.None,
  expect_reply: PythonObject = true
) -> PythonObject {
  var request_id = Python.None
  let metadata = [
    "colab_request_type": request_type
  ].pythonObject
  if Bool(expect_reply)! {
    _msg_id += 1
    request_id = _msg_id
    metadata["colab_msg_id"] = request_id
  }
  let content = [
    "request": request_body
  ].pythonObject
  
  // If there's no parent message, add in the session header to route to the
  // appropriate frontend.
  var parent_copy = parent
  if parent_copy == Python.None {
    // TODO: Is this the same as `kernel.shell.parent_header`?
    let parent_header = KernelContext.kernel._parent_header
    if parent_header != Python.None {
      parent_copy = [
        "header": [
          // Only specifying the session if it is not a cell-related message.
          "session": parent_header["header"]["session"]
        ].pythonObject
      ].pythonObject
    }
  }
  
  let kernel = KernelContext.kernel
  let msg = kernel.session.msg(
    "colab_request", content: content, metadata: metadata, parent: parent)
  kernel.session.send(kernel.iopub_socket, msg)
  return request_id
}

// Calls the front end with a request, and blocks until a reply is received.
func blocking_request(
  _ request_type: PythonObject,
  request: PythonObject,
  timeout_sec: PythonObject,
  parent: PythonObject
) -> PythonObject {
  let request_id = send_request(
    request_type, request, parent: parent, expect_reply: true)
  return read_reply_from_input(request_id, timeout_sec)
}

//===----------------------------------------------------------------------===//
// ColabTools _system_commands.py translation
//===----------------------------------------------------------------------===//

// Context manager that displays a stdin UI widget and hides it upon exit.
struct _display_stdin_widget {
  static func __enter__(delay_millis: PythonObject = 0) -> (Bool) -> Void {
    let kernel = KernelContext.kernel
    _ = send_request(
      "cell_display_stdin", ["delayMillis": delay_millis],
      parent: kernel._parent_header, expect_reply: false)
    
    let echo_updater: (Bool) -> Void = { new_echo_status in
      // Note: Updating the echo status uses colab_request / colab_reply on the
      // stdin socket. Input provided by the user also sends messages on this
      // socket. If user input is provided while the blocking_request call is 
      // still waiting for a colab_reply, the input will be dropped per
      // https://github.com/googlecolab/colabtools/blob/56e4dbec7c4fa09fad51b60feb5c786c69d688c6/google/colab/_message.py#L100.
      _ = send_request(
        "cell_update_stdin", ["echo": new_echo_status].pythonObject, 
        parent: kernel._parent_header, expect_reply: false)
    }
    return echo_updater
  }
  
  static func __exit__() {
    let kernel = KernelContext.kernel
    _ = send_request(
      "cell_remove_stdin", PythonObject([:]), parent: kernel._parent_header, 
      expect_reply: false)
  }
}

// Result of an invocation of the shell magic.
struct ShellResult {
  var args: PythonObject
  var returncode: PythonObject

  init(_ args: PythonObject, _ returncode: PythonObject) {
    self.args = args
    self.returncode = returncode
  }
}

// Polls the process and captures / forwards input and output.
func _poll_process(
  _ parent_pty: PythonObject,
  _ epoll: PythonObject,
  _ p: PythonObject,
  _ cmd: PythonObject,
  _ decoder: PythonObject,
  _ state: inout _MonitorProcessState
) -> ShellResult? {
  let terminated: Bool = p.poll() != Python.None
  if terminated {
     termios.tcdrain(parent_pty)
     epoll.modify(
      parent_pty, select.EPOLLIN | select.EPOLLHUP | select.EPOLLERR)
  }
  
  var output_available = false
  
  let events: [PythonObject] = Array(epoll.poll())
  var input_events: [PythonObject] = []
  for tuple in events {
    let (_, event) = tuple.tuple2
    if Int(event & select.EPOLLIN)! != 0 {
      output_available = true
      let raw_contents = os.read(parent_pty, 1 << 20)
      let decoded_contents = decoder.decode(raw_contents)
      
      sys.stdout.write(decoded_contents)
      sendStdout(String(decoded_contents)!)
    }
    
    if Int(event & select.EPOLLOUT)! != 0 {
      input_events.append(event)
    }
    
    if Int(event & select.EPOLLHUP)! != 0 ||
       Int(event & select.EPOLLERR)! != 0 {
      state.is_pty_still_connected = false
    }
  }
  
  for _ in input_events {
    let input_line = _read_stdin_message()
    if input_line != Python.None {
      let input_bytes = Python.bytes(input_line.encode("UTF-8"))
      os.write(parent_pty, input_bytes)
    }
  }
  
  if terminated, !state.is_pty_still_connected, !output_available {
    sys.stdout.flush()
    return ShellResult(cmd, p.returncode)
  }
  
  if !output_available {
    time.sleep(0.1)
  }
  return nil
}

struct _MonitorProcessState {
  var process_output: PythonObject = io.StringIO()
  var is_pty_still_connected: Bool = true
}

// Monitors the given subprocess until it terminates.
fileprivate func _monitor_process(
  _ parent_pty: PythonObject,
  _ epoll: PythonObject,
  _ p: PythonObject,
  _ cmd: PythonObject,
  _ update_stdin_widget: (Bool) -> Void
) throws -> ShellResult {
  var state = _MonitorProcessState()
  let decoder = codecs.getincrementaldecoder("UTF-8")(errors: "replace") 
  var echo_status: Bool?
  while true {
    let result = _poll_process(parent_pty, epoll, p, cmd, decoder, &state)
    if let result = result {
      return result
    }
    
    let term_settings = termios.tcgetattr(parent_pty)
    let new_echo_status = Bool(term_settings[3] & termios.ECHO)!
    if echo_status != new_echo_status {
      update_stdin_widget(new_echo_status)
      echo_status = new_echo_status
    }
    
    if KernelContext.isInterrupted {
      p.send_signal(signal.SIGINT)
      time.sleep(0.5)
      if p.poll() != Python.None {
        p.send_signal(signal.SIGKILL)
      }
      throw InterruptException(
        "User interrupted execution during a `%system` command.")
    }
  }
}

fileprivate func _configure_term_settings(_ pty_fd: PythonObject) {
  let term_settings = termios.tcgetattr(pty_fd)
  term_settings[1] &= ~termios.ONLCR
  term_settings[3] &= ~termios.ECHOCTL
  termios.tcsetattr(pty_fd, termios.TCSANOW, term_settings)
}

fileprivate func _run_command(
  _ cmd: PythonObject, 
  _ cwd: PythonObject = Python.None
) throws -> ShellResult {
  let locale_encoding = locale.getpreferredencoding()
  if locale_encoding != "UTF-8" {
    throw Exception("A UTF-8 locale is required. Got \(locale_encoding)")
  }

  let (parent_pty, child_pty) = pty.openpty().tuple2
  _configure_term_settings(child_pty)
  
  let epoll = select.epoll()
  epoll.register(
    parent_pty, 
    select.EPOLLIN | select.EPOLLOUT | select.EPOLLHUP | select.EPOLLERR)
  
  defer {
    epoll.close()
    os.close(parent_pty)
  }
  do {
    let update_stdin_widget = _display_stdin_widget.__enter__()
    defer { _display_stdin_widget.__exit__() }

    let p = subprocess.Popen(
      cmd,
      shell: true,
      cwd: cwd,
      executable: "/bin/bash",
      stdout: child_pty,
      stdin: child_pty,
      stderr: child_pty,
      close_fds: false)
    os.close(child_pty)
    
    return try _monitor_process(parent_pty, epoll, p, cmd, update_stdin_widget)
  }
}
