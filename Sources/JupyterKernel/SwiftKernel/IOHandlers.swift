import Foundation
fileprivate let signal = Python.import("signal")
fileprivate let threading = Python.import("threading")
fileprivate let time = Python.import("time")

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
//         KernelContext.lldbQueue.sync {
          _ = KernelContext._1_async_interrupt_process()
//         }
        KernelContext.isInterrupted = true
        
      }
      // Do not need to return anything because this is an infinite loop
    }
  ]
).pythonObject

// var stop_event: PythonObject = Python.None

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
      var localHadStdout = false
      while true {
        KernelContext.sendResponse("stream", [
      "name": "stdout",
      "text": ""
    ])
        KernelContext.log("a")
//         KernelContext.log("a.2")
        time.sleep(0.1)
//         KernelContext.log("b")
//         KernelContext.log("b.2")
        if !KernelContext.pollingStdout {
          break
        }
//         if stop_event.wait(0.1) != Python.None {
//           KernelContext.log("b.2")
//           break
//         }
        KernelContext.log("b")
        getAndSendStdout(hadStdout: &localHadStdout)
        `self`.had_stdout = localHadStdout.pythonObject
      }
      KernelContext.log("b.3")
      getAndSendStdout(hadStdout: &localHadStdout)
      `self`.had_stdout = localHadStdout.pythonObject
      KernelContext.log("b.4")
      return Python.None
    }
  ]
).pythonObject

fileprivate var cachedScratchBuffer: UnsafeMutablePointer<CChar>?

fileprivate func getStdout() -> String {
  var stdout = Data()
  let bufferSize = 1024//1 << 16
  let scratchBuffer = cachedScratchBuffer ?? .allocate(capacity: bufferSize)
  cachedScratchBuffer = scratchBuffer
  while true {
    let stdoutSize = KernelContext._1_get_stdout(scratchBuffer, Int32(bufferSize))
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

fileprivate func getAndSendStdout(hadStdout: inout Bool) {
  let stdout = getStdout()
  if stdout.count > 0 {
    hadStdout = true
    sendStdout(stdout)
  }
}
