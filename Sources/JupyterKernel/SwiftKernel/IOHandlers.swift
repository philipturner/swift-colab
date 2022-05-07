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

// A stored reference to the StdoutHandler type object, used as a workaround for 
// the fact that it must be initialized in Python code.
fileprivate var preservedStdoutHandlerRef: PythonObject!

@_cdecl("JupyterKernel_constructStdoutHandlerClass")
public func JupyterKernel_constructSwiftKernelClass(_ classObj: OpaquePointer) {

let StdoutHandler = {
  PyRun_SimpleString("""
  from ctypes import *; from ipykernel.kernelbase import Kernel
  class StdoutHandler(threading.Thread):
      def __init__(self, **kwargs):
          super().__init__(**kwargs)
   
  func = PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_constructStdoutHandlerClass
  func.argtypes = [c_void_p]; func(c_void_p(id(StdoutHandler)))
  """)
}()

let StdoutHandler = PythonClass(
  "StdoutHandler",
  superclasses: [threading.Thread],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      threading.Thread.__init__(`self`)
      `self`.daemon = true
      `self`.stop_event = threading.Event()
      `self`.stop_event.clear()
      `self`.had_stdout = false
      `self`.should_stop = false
      return Python.None
    },
    
    "run": PythonInstanceMethod { (`self`: PythonObject) in
      var hadStdout = false
      while true {
//         let stop_event = `self`.stop_event
//         stop_event.wait(timeout: 0.1)
        time.sleep(0.1)
        if Bool(`self`.should_stop)! == true {
//         if Bool(stop_event.is_set())! == true { 
          break
        }
        getAndSendStdout(hadStdout: &hadStdout)
      }
      getAndSendStdout(hadStdout: &hadStdout)
      `self`.had_stdout = hadStdout.pythonObject
      `self`.stop_event.set()
      return Python.None
    }
  ]
).pythonObject

// class StdoutHandler {
//   private var semaphore = DispatchSemaphore(value: 0)
//   private var shouldStop = false
  
//   // This is not thread-safe, but the way other code accesses it should not 
//   // cause any data races. Access should be synchronized via `semaphore`.
//   var hadStdout = false
  
//   init() {
//     DispatchQueue.global().async { [self] in
//       while true {
//         usleep(200_000)
//         if shouldStop {
//           break
//         }
//         getAndSendStdout(hadStdout: &hadStdout)
//       }
//       getAndSendStdout(hadStdout: &hadStdout)
//       semaphore.signal()
//     }
//   }
  
//   // Must be called before deallocating this object.
//   func stop() {
//     shouldStop = true
//     semaphore.wait()
//   }
// }

fileprivate var cachedScratchBuffer: UnsafeMutablePointer<CChar>?

fileprivate func getStdout() -> String {
  var stdout = Data()
  let bufferSize = 1000//1 << 16
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

internal func getAndSendStdout(hadStdout: inout Bool) {
  let stdout = getStdout()
  if stdout.count > 0 {
    hadStdout = true
    sendStdout(stdout)
  }
}
