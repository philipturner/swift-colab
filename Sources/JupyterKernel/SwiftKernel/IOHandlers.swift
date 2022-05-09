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

fileprivate var errorStreamEnd: Int = 0

func getStderr() -> String {
//   let fm = FileManager.default
//   // TODO: open with with w+ in debugger, the go back to DoExecute and ensure you only read once.
//   let stderrData = fm.contents(atPath: "/opt/swift/err") ?? Data()
//   let stderr = String(data: stderrData, encoding: .utf8)!
//   // TODO: find a way to flush the file without LLDB's appending
//   // mechanism messing up

  
 
  
//     precondition(
//     fm.createFile(atPath: "/opt/swift/err", contents: Data()),
//     "Could not write to stderr file for the Swift interpreter")
  
//   let errorFilePointer = fopen("/opt/swift/err", "r+")!
//   rewind(errorFilePointer)
//   fclose(errorFilePointer)
  
  let errorFilePointer = fopen("/opt/swift/err", "r")!
  defer { fclose(errorFilePointer) }
  
  fseek(errorFilePointer, 0, SEEK_END)
  let newErrorStreamEnd = ftell(errorFilePointer)
  
  let messageSize = newErrorStreamEnd - errorStreamEnd
  defer { errorStreamEnd = newErrorStreamEnd }
  KernelContext.log("accessing file")
  KernelContext.log("previous cursor: \(previousCursor)")
  KernelContext.log("errorStreamEnd: \(errorStreamEnd)")
  KernelContext.log("newErrorStreamEnd: \(newErrorStreamEnd)")
  if messageSize == 0 {
    return ""
  }
  
  fseek(errorFilePointer, errorStreamEnd, SEEK_SET)
  let errorDataPointer = malloc(messageSize)!
  
  
  
//   return stderr
  return "Some Stderr\n"
}
