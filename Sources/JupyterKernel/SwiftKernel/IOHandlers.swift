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
      `self`.had_stdout = false
      return Python.None
    },
    
    "run": PythonInstanceMethod { (`self`: PythonObject) in
      KernelContext.log("began stdout handler")
      while true {
        time.sleep(0.05)
        if !KernelContext.pollingStdout {
          break
        }
        getAndSendStdout(handler: `self`)
      }
      getAndSendStdout(handler: `self`)
      KernelContext.log("ended stdout handler")
      return Python.None
    }
  ]
).pythonObject

fileprivate var cachedStdoutBuffer: UnsafeMutablePointer<CChar>?
fileprivate var cachedStderrBuffer: UnsafeMutablePointer<CChar>?

fileprivate func getStdio(
  _ get_stdio: @convention(c) (UnsafeMutablePointer<CChar>, Int32) -> Int32,
  cachedBuffer: inout UnsafeMutablePointer<CChar>?
) -> String {
  var stdio = Data()
  let bufferSize = 1 << 16
  let scratchBuffer = cachedBuffer ?? .allocate(capacity: bufferSize)
  cachedBuffer = scratchBuffer
  while true {
    let stdioSize = get_stdio(scratchBuffer, Int32(bufferSize))
    guard stdioSize > 0 else {
      break
    }
    let stdioSegment = Data(
      bytesNoCopy: scratchBuffer, count: Int(stdioSize), deallocator: .none)
    stdio += stdioSegment
  }
  return String(data: stdio, encoding: .utf8)!
}

func getStderr() -> String {
  return getStdio(KernelContext.get_stderr, cachedBuffer: &cachedStderrBuffer)
}

fileprivate func getStdout() -> String {
  return getStdio(KernelContext.get_stdout, cachedBuffer: &cachedStdoutBuffer)
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

fileprivate func getAndSendStdout(handler: PythonObject) {
  var stdout = getStdout()
  if stdout.count > 0 {
    if Bool(handler.had_stdout)! == false {
      // Remove header that signalled that the code successfully compiled.
      let header = "HEADER"
      precondition(stdout.hasPrefix(header), """
        stdout did not start with the expected header "\(header)". stdout was:
        \(stdout)
        """)
      stdout.removeFirst(header.count + 1)
      handler.had_stdout = true
    }
    KernelContext.log("received stdout")
    sendStdout(stdout)
  }
}
