import Foundation
fileprivate let signal = Python.import("signal")
fileprivate let threading = Python.import("threading")

let SIGINTHandler = PythonClass(
  "SIGINTHandler",
  superclasses: [threading.Thread],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      threading.Thread.__init__(`self`)
      `self`.daemon = true
      return Python.None
    },
    
    "run": PythonInstanceMethod { (`self`: PythonObject) in
      while true {
        signal.sigwait([signal.SIGINT])
        _ = KernelContext.send_async_interrupt()
      }
      // Do not need to return anything because this is an infinite loop
    }
  ]
).pythonObject

let StdoutHandler = PythonClass(
  "StdoutHandler",
  superclasses: [threading.Thread],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      threading.Thread.__init__(`self`)
      `self`.stop_event = threading.Event()
      `self`.had_stdout = false
      return Python.None
    },
    
    "run": PythonInstanceMethod { (`self`: PythonObject) in
       while true {
         if Bool(`self`.stop_event.wait(0.1)) == true {
           break
         }
         getAndSendStdout(handler: `self`)
       }
       getAndSendStdout(handler: `self`)
       return Python.None
    }
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
  let kernel = KernelContext.kernel
  if let range = stdout.range(of: "\033[2J") {
    sendStdout(String(stdout[..<range.lowerBound]))
    kernel.send_response(kernel.iopub_socket, "clear_output", [
      "wait": false
    ])
    sendStdout(String(stdout[range.upperBound...]))
  } else {
    kernel.send_response(kernel.iopub_socket, "stream", [
      "name": "stdout",
      "text": stdout
    ])
  }
}

fileprivate func getAndSendStdout(handler: PythonObject) {
  let stdout = getStdout()
  if stdout.count > 0 {
    handler.had_stdout = true
    sendStdout(stdout)
  }
}
