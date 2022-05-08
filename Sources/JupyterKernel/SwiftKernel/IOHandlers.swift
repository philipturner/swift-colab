import Foundation
fileprivate let signal = Python.import("signal")
fileprivate let threading = Python.import("threading")
fileprivate let time = Python.import("time")

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
      `self`.had_stdout = false // TODO: remove this property if not necessary
      return Python.None
    },
    
    "run": PythonInstanceMethod { (`self`: PythonObject) in
      var localHadStdout = false
      while true {
        KernelContext.log("a")
        time.sleep(0.05)
        KernelContext.log("b")
        if !KernelContext.pollingStdout {
          break
        }
        getAndSendStdout(hadStdout: &localHadStdout)
        `self`.had_stdout = localHadStdout.pythonObject
        KernelContext.log("b.1")
      }
      KernelContext.log("b.2")
      getAndSendStdout(hadStdout: &localHadStdout)
      `self`.had_stdout = localHadStdout.pythonObject
      KernelContext.log("b.3")
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
