import Foundation
fileprivate let signal = Python.import("signal")
fileprivate let threading = Python.import("threading")
fileprivate let time = Python.import("time")

// SIGINT handling requires a single-threaded context that respects the GIL. 
// Thus, it uses Python threading instead of Swift GCD.
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
        KernelContext.interruptStatus = .interrupted
        _ = KernelContext.async_interrupt_process()
      }
      // Do not need to return anything because this is an infinite loop
    }
  ]
).pythonObject

class StdoutHandler {
  private var semaphore = DispatchSemaphore(value: 0)
  private var shouldStop = false
  
  // This is not thread-safe, but the way other code accesses it should not 
  // cause any data races. Access should be synchronized via `semaphore`.
  var hadStdout = false
  
  init() {
    DispatchQueue.global(qos: .userInteractive).async { [self] in
////////////////////////////////////////////////////////////////////////////////
      // Try to stick to checking at exact 0.1 second intervals. Without this
      // mechanism, it would slightly creep off by ~0.105 seconds, causing the
      // output to seem jumpy for any loop synchronized with a multiple of 0.1
      // second. This solution synchronizes the scan loop with 0.1 seconds, but
      // jumps ahead by something indivisible by 0.1 if the thread misses the
      // mark???
      var deadline = Date().advanced(by: 0.1)
      while true {
        Thread.sleep(until: deadline)
        if shouldStop {
          break
        }
        getAndSendStdout(hadStdout: &hadStdout)
        let previousDeadline = deadline
        
        deadline = deadline.advanced(by: 0.1)
        while deadline < Date() {
          deadline = deadline.advanced(by: 0.1)
        }
        
        KernelContext.log("\(deadline.timeIntervalSince(previousDeadline) * 1e6)")
      }
      getAndSendStdout(hadStdout: &hadStdout)
      semaphore.signal()
    }
  }
  
  // Must be called before deallocating this object.
  func stop() {
    shouldStop = true
    semaphore.wait()
  }
}

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

fileprivate func getAndSendStdout(hadStdout: inout Bool) {
  let stdout = getStdout()
  KernelContext.pythonSemaphore.wait()
  defer {
    KernelContext.pythonSemaphore.signal()
  }
  
  if stdout.count > 0 {
    hadStdout = true
    sendStdout(stdout)
  }
}
