import Foundation
fileprivate let signal = Python.import("signal")
fileprivate let threading = Python.import("threading")

internal var globalMessages: [String] = []
internal var vulnerableProcess: PythonObject = Python.None
internal var killedVulnerableProcess: Bool = false

internal func updateProgressFile() {
  var string = ""
  for message in globalMessages {
    string += message + "\n"
  }
  
  let data = string.data(using: .utf8)!
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
        globalMessages.append("hello world 0")
        updateProgressFile()
        
        signal.sigwait([signal.SIGINT])
        globalMessages.append("hello world 1")
        updateProgressFile()
        
        _ = KernelContext.async_interrupt_process()
        globalMessages.append("hello world 2.1")
        updateProgressFile()
        
        if vulnerableProcess != Python.None {
          vulnerableProcess.send_signal(signal.SIGKILL)
//           vulnerableProcess.terminate()
          killedVulnerableProcess = true
          globalMessages.append("hello world 2.2")
        } else {
          globalMessages.append("hello world 2.3")
        }
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
       globalMessages.append("hello world 4")
       updateProgressFile()
       while true {
         globalMessages.append("hello world 5")
         updateProgressFile()
//          usleep(1_000_000)
//          if doExecute_lock {
         if Bool(`self`.stop_event.wait())! { //== true {
           globalMessages.append("hello world 6")
           updateProgressFile()
           break
         } else {
           globalMessages.append("hello world 6.2")
           updateProgressFile()
         }
         getAndSendStdout(handler: `self`)
       }
       globalMessages.append("hello world 7")
       updateProgressFile()           
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
    globalMessages.append("hello world 5.1")
    updateProgressFile()  
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
  
//   let kernel = KernelContext.kernel
                            
//     let clear_sequence: PythonObject = "\033[2J"
//     let clear_sequence_index = stdout.find(clear_sequence)
//     let clear_sequence_length = Python.len(clear_sequence)
    
//     if clear_sequence_index != -1 {
//         sendStdout(stdout[(..<clear_sequence_index).pythonObject])
        
//         try! kernel.send_response.throwing.dynamicallyCall(withArguments:
//             kernel.iopub_socket, "clear_output", ["wait": false])
            

//         sendStdout(stdout[((clear_sequence_index + clear_sequence_length)...).pythonObject])
//     } else {
//          try! kernel.send_response.throwing.dynamicallyCall(withArguments:
//             kernel.iopub_socket, "stream", ["name": "stdout", "text": stdout])
//     }
}

fileprivate func getAndSendStdout(handler: PythonObject) {
  let stdout = getStdout()
  globalMessages.append("hello world 5.2")
  updateProgressFile()  
  if stdout.count > 0 {
    handler.had_stdout = true
    sendStdout(stdout)
  }
}

internal func altGetAndSendStdout(hadStdout: inout Bool) {
  let stdout = getStdout()
  globalMessages.append("hello world 5.2")
  updateProgressFile()  
  if stdout.count > 0 {
    hadStdout = true
    sendStdout(stdout)
  }
}
