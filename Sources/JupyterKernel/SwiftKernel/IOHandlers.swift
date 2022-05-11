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
      // I don't know why, but the character immediately following "HEADER" is 
      // not a newline.
      stdout.removeFirst(header.count + 1)
      handler.had_stdout = true
    }
    KernelContext.log("received stdout")
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

// This attempts to replicate the code located at:
// https://github.com/ipython/ipython/blob/master/IPython/utils/_process_posix.py,
//   def system(self, cmd):
func executeSystemCommand(
  args: [String], cwd: String? = nil
) throws -> Int {
  let process = pexpect.spawn("/bin/sh", args: ["-c"] + args, cwd: cwd)
  let flush = sys.stdout.flush
  let patterns = [pexpect.TIMEOUT, pexpect.EOF]
  var outSize: Int = 0
  
  while true {
    var waitTime: Double = 0.05
    if KernelContext.isInterrupted {
      waitTime = 0.2
      process.sendline(Python.chr(3))
      outSize = process.before.count
    }
    
    let resIdx = process.expect_list(patterns, waitTime)
    let str = String(process.before[outSize...].decode("utf8", "replace"))!
    if str.count > 0 {
      KernelContext.sendResponse("stream", [
        "name": "stdout",
        "text": str
      ])
    }
    flush()
    outSize = process.before.count
    
    if KernelContext.isInterrupted {
      process.terminate(force: true)
      throw InterruptException(
        "User interrupted execution during a `%system` command.")
    } else if Int(resIdx)! == 1 {
      break
    }
  }
  process.isalive()
  
  if let exitstatus = Int(process.exitstatus) {
    if exitstatus > 128 {
      return -(exitstatus - 128)
    } else {
      return exitstatus
    }
  } else if let signalstatus = Int(process.signalstatus) {
    return -signalstatus
  } else {
    return 0
  }
}
