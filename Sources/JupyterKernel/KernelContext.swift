import Foundation

struct KernelContext {
  static var kernel: PythonObject = Python.None
  
  static var debuggerInitialized = false
  
  enum InterruptStatus {
    case running
    case interrupted
  }
  
  static var interruptStatus: InterruptStatus = .running
  
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
  
  // For ensuring accesses to Python APIs are thread-safe.
  static var pythonQueue = DispatchQueue(
    label: "com.philipturner.swift-colab.KernelContext.pythonQueue")
  static var pythonSemaphore = DispatchSemaphore(value: 1)
  
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
