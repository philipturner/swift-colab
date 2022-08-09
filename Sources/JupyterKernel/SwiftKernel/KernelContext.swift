import Foundation

struct KernelContext {
  static var kernel: PythonObject = Python.None
  static var cellID: Int = 0
  
  static var debuggerInitialized = false
  static var isInterrupted = false
  static var pollingStdout = false
  static var lldbQueue = DispatchQueue(
    label: "com.philipturner.swift-colab.KernelContext.lldbQueue")
  
  private static var logInitialized = false
  private static let logQueue = DispatchQueue(
    label: "com.philipturner.swift-colab.KernelContext.logQueue")
  
  private static let get_log_initialized: @convention(c) () -> Int32 = 
    LLDBProcessLibrary.loadSymbol(name: "get_log_initialized")
  private static let set_log_initialized: @convention(c) (Int32) -> Void = 
    LLDBProcessLibrary.loadSymbol(name: "set_log_initialized")
  
  static func log(_ message: String) {
    logQueue.sync {
      let cppLogInitialized: Bool = get_log_initialized() != 0
      if cppLogInitialized != logInitialized {
        if logInitialized == false {
          logInitialized = true
        } else {
          precondition(cppLogInitialized == false)
          set_log_initialized(1);
        }
      }
      
      var mode: String
      if logInitialized {
        mode = "a"
      } else {
        mode = "w"
        logInitialized = true
      }
      
      let filePointer = fopen("/opt/swift/log", mode)!
      let writtenMessage = message + "\n"
      fwrite(writtenMessage, 1, writtenMessage.count, filePointer)
      fclose(filePointer)
    }
  }
  
  static func sendResponse(_ header: String, _ message: PythonConvertible) {
    kernel.send_response(kernel.iopub_socket, header, message)
  }
  
  // Dynamically loaded LLDB bringing functions
  
  static let init_repl_process: @convention(c) (
    OpaquePointer, UnsafePointer<CChar>) -> Int32 = 
    LLDBProcessLibrary.loadSymbol(name: "init_repl_process")
  
  static let execute: @convention(c) (
    UnsafePointer<CChar>, 
    UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "execute")
  
  static let process_is_alive: @convention(c) () -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "process_is_alive")
  
  static let after_successful_execution: @convention(c) (
    UnsafeMutablePointer<UnsafeMutablePointer<UInt64>?>) -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "after_successful_execution")
  
  static let get_stdout: @convention(c) (
    UnsafeMutablePointer<CChar>, Int32) -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "get_stdout")
  
  static let get_pretty_stack_trace: @convention(c) (
    UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutableRawPointer>?>,
    UnsafeMutablePointer<Int32>) -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "get_pretty_stack_trace")
  
  static let async_interrupt_process: @convention(c) () -> Int32 =
    LLDBProcessLibrary.loadSymbol(name: "async_interrupt_process")
}

fileprivate struct LLDBProcessLibrary {
  static var library: UnsafeMutableRawPointer = {
    _ = dlopen(
      "/opt/swift/toolchain/usr/lib/liblldb.so", RTLD_LAZY | RTLD_GLOBAL)!
    return dlopen("/opt/swift/lib/libLLDBProcess.so", RTLD_LAZY | RTLD_GLOBAL)!
  }()
  
  static func loadSymbol<T>(name: String) -> T {
    let address = dlsym(library, name)
    return unsafeBitCast(address, to: T.self)
  }
}

struct KernelPipe {
  enum ProcessType {
    case jupyterKernel
    case lldb

    var other: ProcessType {
      switch self {
        case .jupyterKernel: return .lldb
        case .lldb: return .jupyterKernel
      }
    }
    
    var recvPipe: Int32 {
      switch self {
        case .jupyterKernel: return pipe1!
        case .lldb: return pipe2!
      }
    }
    
    var sendPipe: Int32 {
      switch self {
        case .jupyterKernel: return pipe2!
        case .lldb: return pipe1!
      }
    }
  }
  
  // file1/pipe1: what JupyterKernel monitors for messages
  // file2/pipe2: what LLDB monitors for messages
  static var file1: UnsafeMutablePointer<FILE>?
  static var file2: UnsafeMutablePointer<FILE>?
  static var pipe1: Int32?
  static var pipe2: Int32?
  
  // If the runtime crashed while LLDB was `while` looping to receive a message,
  // the LLDB thread's Python code keeps running endlessly. This could cause
  // data races, where the zombie thread consumes messages it doesn't own.
  //
  // Solve this problem with a global, monotonically increasing counter. It
  // creates unique file names across Jupyter sessions, and provides a way to
  // invalidate a zombie thread. If the current counter doesn't match the last
  // one cached by `fetchPipes`, it crashes.
  static var globalCellID: UInt64?
  
  // Close existing file handles.
  private static func closeHandles() {
    if let file1 = file1 {
      precondition(fclose(file1) == 0, "Could not close pipe 1: \(errno)")
      Self.file1 = nil
      pipe1 = nil
    }
    if let file2 = file2 {
      precondition(fclose(file2) == 0, "Could not close pipe 2: \(errno)")
      Self.file2 = nil
      pipe2 = nil
    }
  }
  
  static func incrementThenLoadCounter() -> UInt64 {
    let fm = FileManager.default
    var nextCounter: UInt64
    if let previous = fm.contents(atPath: "/opt/swift/pipes/counter") {
      let string = String(data: previous, encoding: .utf8)!
      nextCounter = UInt64(string)! + 1
    } else {
      nextCounter = 0
    }
    
    let contents = "\(nextCounter)".data(using: .utf8)!
    fm.createFile(atPath: "/opt/swift/pipes/counter", contents: contents)
    return nextCounter
  }
  
  static func loadCounter() -> UInt64 {
    let fm = FileManager.default
    let data = fm.contents(atPath: "/opt/swift/pipes/counter")!
    let string = String(data: data, encoding: .utf8)!
    return UInt64(string)!
  }

  static func validateCounter() {
    let currentCounter = loadCounter()
    guard globalCellID! == currentCounter else {
      fatalError("Zombie thread.")
    }
  }
  
  // TODO: Replace `afterSuccessfulExecution` with transferring data over this 
  // stream.
  static func resetPipes() {
    closeHandles()
    let counter = incrementThenLoadCounter()
    if counter > 0 {
      remove("/opt/swift/pipes/1-\(counter - 1)")
      remove("/opt/swift/pipes/2-\(counter - 1)")
    }
    fclose(fopen("/opt/swift/pipes/1-\(counter)", "wb")!)
    fclose(fopen("/opt/swift/pipes/2-\(counter)", "wb")!)
  }
  
  // Both parent and child processes call the same function.
  static func fetchPipes(currentProcess: ProcessType) {
    closeHandles()
    globalCellID = loadCounter()
    
    let mode1 = (currentProcess == .jupyterKernel) ? "rb" : "ab"
    let mode2 = (currentProcess == .lldb) ? "rb" : "ab"
    file1 = fopen("/opt/swift/pipes/1-\(globalCellID!)", mode1)
    file2 = fopen("/opt/swift/pipes/2-\(globalCellID!)", mode2)
    pipe1 = fileno(file1)
    pipe2 = fileno(file2)
  }
  
  static func send(_ data: Data, to targetProcess: ProcessType) {
    validateCounter()
    guard data.count > 0 else {
      // Buffer pointer might initialize with null base address and zero count.
      return
    }
    let buffer: UnsafeMutablePointer<UInt8> = 
      .allocate(capacity: 8 + data.count)
    defer {
      buffer.deallocate()
    }
    let headerPtr = UnsafeMutablePointer<UInt64>(OpaquePointer(buffer))
    headerPtr.pointee = UInt64(data.count)
    data.copyBytes(to: buffer + 8, count: data.count)
    
    let pipe = targetProcess.other.sendPipe
    precondition(
      Foundation.write(pipe, buffer, 8 + data.count) >= 0, 
      "Could not write to pipe \(pipe): \(errno)")
  }
  
  static let scratchBufferSize = 1024
  
  // Still need to perform a postprocessing pass, which parses headers to
  // separate each message into its own `Data`.
  static func recv_raw(from targetProcess: ProcessType) -> Data {
    validateCounter()
    let scratchBuffer: UnsafeMutablePointer<UInt8> = 
      .allocate(capacity: scratchBufferSize)
    defer {
      scratchBuffer.deallocate()
    }
    var output = Data()
    
    let pipe = targetProcess.other.recvPipe
    while true {
      let bytesRead = read(pipe, scratchBuffer, scratchBufferSize)
      if bytesRead <= 0 {
        break
      }
      output.append(UnsafePointer(scratchBuffer), count: bytesRead)
    }
    return output
  }
  
  static func recv(from targetProcess: ProcessType) -> [Data] {
    let raw_data = recv_raw(from: targetProcess)
    guard raw_data.count > 0 else {
      return []
    }
    var output: [Data] = []
    
    // Align to `Int64`, which is 8 bytes.
    let buffer: UnsafeMutableRawPointer = 
      .allocate(byteCount: raw_data.count, alignment: 8)
    defer {
      buffer.deallocate()
    }
    raw_data.copyBytes(
      to: buffer.assumingMemoryBound(to: UInt8.self), count: raw_data.count)

    var stream = buffer
    var streamProgress = 0
    let streamEnd = raw_data.count
    while streamProgress < streamEnd {
      let header = stream.assumingMemoryBound(to: Int64.self).pointee
      stream += 8
      streamProgress += 8
      let newData = Data(bytes: UnsafeRawPointer(stream), count: Int(header))
      output.append(newData)
      stream += Int(header)
      streamProgress += Int(header)
    }
    if streamProgress > streamEnd {
      fatalError("Malformed pipe contents.")
    }
    return output
  }
}
