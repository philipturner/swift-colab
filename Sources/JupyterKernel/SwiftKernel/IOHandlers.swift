import Foundation
fileprivate let signal = Python.import("signal")
fileprivate let threading = Python.import("threading")

fileprivate var messages: [String] = []

fileprivate func updateProgressFile() {
  let data = "\(messages)".data(using: .utf8)!
  precondition(FileManager.default.createFile(atPath: "/content/progress.txt", contents: data))
}

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
//         try! signal.sigwait.throwing.dynamicallyCall(withArguments: [signal.SIGINT] as PythonObject)
        messages.append("hello world 4")
//         updateProgressFile()
        
        signal.sigwait([signal.SIGINT])
        messages.append("hello world 5")
        updateProgressFile()
        
        _ = KernelContext.async_interrupt_process()
        messages.append("hello world 6")
        updateProgressFile()
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
      `self`.daemon = true
      `self`.stop_event = threading.Event()
      `self`.had_stdout = false
      return Python.None
    },
    
    "run": PythonInstanceMethod { (`self`: PythonObject) in
       while true {
         if Bool(`self`.stop_event.wait(0.1))! == true {
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
  let bufferSize = 1000// 1 << 16
  let scratchBuffer = cachedScratchBuffer ?? .allocate(capacity: bufferSize)
  cachedScratchBuffer = scratchBuffer
  while true {
    let stdoutSize = KernelContext.get_stdout(scratchBuffer, Int32(bufferSize))
    guard stdoutSize > 0 else {
      break
    }
//     let stdoutSegment = Data(
//       bytesNoCopy: scratchBuffer, count: Int(stdoutSize), deallocator: .none)
    let stdoutSegment = Data(
      bytes: scratchBuffer, count: Int(stdoutSize))
    stdout += stdoutSegment
  }
  return String(data: stdout, encoding: .utf8)!
}

fileprivate func sendStdout(_ stdout: PythonObject /* String */) {
//   let kernel = KernelContext.kernel
//   if let range = stdout.range(of: "\033[2J") {
//     sendStdout(String(stdout[..<range.lowerBound]))
//     kernel.send_response(kernel.iopub_socket, "clear_output", [
//       "wait": false
//     ])
//     sendStdout(String(stdout[range.upperBound...]))
//   } else {
//     kernel.send_response(kernel.iopub_socket, "stream", [
//       "name": "stdout",
//       "text": stdout
//     ])
//   }
  
  let kernel = KernelContext.kernel
                            
    let clear_sequence: PythonObject = "\033[2J"
    let clear_sequence_index = stdout.find(clear_sequence)
    let clear_sequence_length = Python.len(clear_sequence)
    
    if clear_sequence_index != -1 {
        sendStdout(stdout[(..<clear_sequence_index).pythonObject])
        
        try! kernel.send_response.throwing.dynamicallyCall(withArguments:
            kernel.iopub_socket, "clear_output", ["wait": false])
            

        sendStdout(stdout[((clear_sequence_index + clear_sequence_length)...).pythonObject])
    } else {
         try! kernel.send_response.throwing.dynamicallyCall(withArguments:
            kernel.iopub_socket, "stream", ["name": "stdout", "text": stdout])
    }
}

fileprivate func getAndSendStdout(handler: PythonObject) {
  let stdout = getStdout()
  if stdout.count > 0 {
    handler.had_stdout = true
    sendStdout(PythonObject(stdout))
  }
}
