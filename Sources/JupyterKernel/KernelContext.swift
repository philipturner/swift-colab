import Foundation

struct KernelContext {
  static var kernel: PythonObject = Python.None
  static var cellID: Int = 0
  
  static var debuggerInitialized = false
  static var isInterrupted = false
  static var pollingStdout = false
  
  // For use in "ProcessInstalls.swift"
  static var installLocation = "/opt/swift/packages"
  
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
  enum CurrentProcess {
    case jupyterKernel
    case lldb
    
    var readPipe: Int32 {
      switch self {
        case .jupyterKernel: return pipe1!
        case .lldb: return pipe2!
      }
    }
    
    var writePipe: Int32 {
      switch self {
        case .jupyterKernel: return pipe2!
        case .lldb: return pipe1!
      }
    }
  }
  
  static var file1: UnsafeMutablePointer<FILE>?
  static var file2: UnsafeMutablePointer<FILE>?
  static var pipe1: Int32?
  static var pipe2: Int32?
  
  // TODO: Flush files and assign new file descriptors before each cell.
  // TODO: Replace KernelCommunicator with transferring data over this stream.
  static func resetPipes() {
    fclose(fopen("/opt/swift/pipe1", "wb")!)
    fclose(fopen("/opt/swift/pipe2", "wb")!)
  }
  
  // Both parent and child processes call the same function.
  static func fetchPipes(_ process: CurrentProcess) {
    let mode1 = (process == .jupyterKernel) ? "rb" : "ab"
    let mode2 = (process == .lldb) ? "rb" : "ab"
    file1 = fopen("/opt/swift/pipe1", mode1)
    file2 = fopen("/opt/swift/pipe2", mode2)
    pipe1 = fileno(file1)
    pipe2 = fileno(file2)
  }
  
  static func append(_ data: Data, _ process: CurrentProcess) {
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
    headerPtr.pointee = Int64(data.count)
    data.copyBytes(to: buffer + 8, count: data.count)
    
    let pipe = process.writePipe
    precondition(
      Foundation.write(pipe, buffer, 8 + data.count) >= 0, 
      "Could not write to pipe \(pipe): \(errno)")
  }
  
  static let scratchBufferSize = 1024
  
  // Still need to perform a postprocessing pass, which parses headers to
  // separate each message into its own `Data`.
  static func read_raw(_ process: CurrentProcess) -> Data {
    let scratchBuffer: UnsafeMutablePointer<UInt8> = 
      .allocate(capacity: scratchBufferSize)
    defer {
      scratchBuffer.deallocate()
    }
    var output = Data()
    
    let pipe = process.readPipe
    let read = Foundation.read
    while true {
      let bytesRead = read(pipe, scratchBuffer, scratchBufferSize)
      KernelContext.log("BYTES READ \(bytesRead) errno: \(errno)")
      if bytesRead <= 0 {
        break
      }
      output.append(UnsafePointer(scratchBuffer), count: bytesRead)
    }
    return output
  }
  
  static func read(_ process: CurrentProcess) -> [Data] {
    let raw_data = read_raw(process)
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
