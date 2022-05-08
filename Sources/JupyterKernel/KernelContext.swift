import Foundation

struct KernelContext {
  static var kernel: PythonObject = Python.None
  
  static var debuggerInitialized = false
  static var isInterrupted = false
  static var pollingStdout = false
  
  private static var logInitialized = false
  private static let logQueue = DispatchQueue(
    label: "com.philipturner.swift-colab.KernelContext.logQueue")
  
  static func log(_ message: String) {
    logQueue.sync {
      let fm = FileManager.default
      var logData: Data!
      if logInitialized {
        logData = fm.contents(atPath: "/opt/swift/log") ?? Data()
      } else {
        logData = Data()
        logInitialized = true
      }

      let messageData = (message + "\n").data(using: .utf8)!
      guard fm.createFile(
            atPath: "/opt/swift/log", contents: logData! + messageData) else {
        fatalError("Could not write to Swift-Colab log file.")
      }
    }
  }
  
  static func sendResponse(_ header: String, _ message: PythonConvertible) {
    kernel.send_response(kernel.iopub_socket, header, message)
  }
  
  // Allows sending responses from other threads, preventing multithreaded
  // access to Python that violates the GIL and (maybe) makes the UI
  // unresponsive.
  private static var cachedResponses: [(String, PythonConvertible)] = []
  static var responseQueue = DispatchQueue(
    label: "com.philipturner.swift-colab.KernelContext.responseQueue")
  
  // Must call this on `responseQueue`; `message` must not contain any Python 
  // objects.
  static func sendAsyncResponse(
    _ header: String, _ message: PythonConvertible
  ) {
    cachedResponses.append((header, message))
  }
  
  static func flushResponses() {
    let responses = responseQueue.sync { () -> [(String, PythonConvertible)] in
      let output = cachedResponses
      cachedResponses = []
      return output
    }
    
    let send_response = kernel.send_response
    let iopub_socket = kernel.iopub_socket
    for response in responses {
      send_response(iopub_socket, response.0, response.1)
//       KernelContext.log("a flushed response")
    }
  }
  
  // Dynamically loaded LLDB bringing functions
  
  static let init_repl_process: @convention(c) (
    OpaquePointer, UnsafePointer<CChar>) -> Int32 = 
    LLDBProcessLibrary.loadSymbol(name: "init_repl_process")
  
  static let execute: @convention(c) (
    UnsafePointer<CChar>, 
    UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "execute")
  
  static let process_is_alive: @convention(c) (
    UnsafeMutablePointer<Int32>) -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "process_is_alive")
  
  static let after_successful_execution: @convention(c) (
    UnsafeMutablePointer<UnsafeMutablePointer<UInt64>?>) -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "after_successful_execution")
  
  static let get_stdout: @convention(c) (
    UnsafeMutablePointer<CChar>, Int32) -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "get_stdout")
  
  static let get_pretty_stack_trace: @convention(c) (
    UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>>?>,
    UnsafeMutablePointer<Int32>) -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "get_pretty_stack_trace")
  
  static let async_interrupt_process: @convention(c) () -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "async_interrupt_process")
}

fileprivate struct LLDBProcessLibrary {
  static var library: UnsafeMutableRawPointer = {
    _ = dlopen("/opt/swift/toolchain/usr/lib/liblldb.so", RTLD_LAZY | RTLD_GLOBAL)!
    return dlopen("/opt/swift/lib/libLLDBProcess.so", RTLD_LAZY | RTLD_GLOBAL)!
  }()
  
  static func loadSymbol<T>(name: String) -> T {
    let address = dlsym(library, name)
    return unsafeBitCast(address, to: T.self)
  }
}
