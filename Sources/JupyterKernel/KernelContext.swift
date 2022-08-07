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
    case jupyterKernel // parent
    case lldb // child
    
    var readPipe: Int32 {
      // Fetches pipes from file if not already fetched, and current process
      // is LLDB. (do explicitly in caller, not here)
      switch self {
        case .jupyterKernel: return pipe3!
        case .lldb: return pipe1!
      }
    }
    
    var writePipe: Int {
      // Fetches pipes from file if not already fetched, and current process
      // is LLDB. (do explicitly in caller, not here)
      switch self {
        case .jupyterKernel: return pipe2!
        case .lldb: return pipe4!
      }
    }
  }
  
  // File descriptor IDs for each pipe.
  
  // parent -> child (read)
  static var pipe1: Int32? 
  // parent -> child (write)
  static var pipe2: Int32? 
  // child -> parent (read)
  static var pipe3: Int32? 
  // child -> parent (write)
  static var pipe4: Int32?
  
  static func createPipes() {
    // Generate pipes.
    var pipes = [Int32](repeating: 0, count: 2)
    pipe(&pipes)
    pipe1 = pipes[0]
    pipe2 = pipes[1]
    
    pipe(&pipes)
    pipe3 = pipes[0]
    pipe4 = pipes[1]
    
    // Write pipes to file.
    let filePointer = fopen("/opt/swift/pipes", "wb")
    defer {
      fclose(filePointer)
    }

    var buffer: [Int32] = [pipe1!, pipe2!, pipe3!, pipe4!]
    fwrite(&buffer, 4, 4, filePointer)
    KernelContext.log("Pipe IDs: \(buffer)")
  }
  
  static func fetchPipes() {
    // Read pipes from file.
    let filePointer = fopen("/opt/swift/pipes", "rb")
    defer {
      fclose(filePointer)
    }
    var buffer = [Int32](repeating: 0, count: 4)
    fread(&buffer, 4, 4, filePointer)
    
    // Set pipes.
    pipe1 = buffer[0]
    pipe2 = buffer[1]
    pipe3 = buffer[2]
    pipe4 = buffer[3]
    print("Pipe IDs: \(buffer)")
  }
  
  static func flushPipes() {
    // TODO: Implement and find a good call site.
  }
  
  // static func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
  //   let lockPointer = fopen("/opt/swift/pipes/lock", "rb")!
  //   let fd = fileno(lockPointer)
  //   flock(fd, LOCK_EX)
  //   let output = try body()
  //   flock(fd, LOCK_UN)
  //   fclose(lockPointer)
  //   return output
  // }
  
  static func append(_ data: Data, _ process: CurrentProcess) {
    guard data.count > 0 else {
      // Buffer pointer might initialize with null base address and zero count.
      return
    }
    let buffer: UnsafeMutablePointer<UInt8> = .allocate(capacity: data.count)
    defer {
      buffer.deallocate()
    }
    data.copyBytes(to: buffer, count: data.count)
    
    let pipe = process.writePipe
    var header = Int64(data.count)
    write(pipe, &header, 8)
    write(buffer, data.count)
    
    // withLock {
      // let filePointer = fopen("/opt/swift/pipes/\(process.writePipe)", "ab")!
      // defer { 
      //   fclose(filePointer) 
      // }
      
      // var header = Int64(data.count)
      // fwrite(&header, 8, 1, filePointer)
      // fwrite(buffer, 1, data.count, filePointer)
    // }
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
    while true {
      let bytesRead = read(pipe, scratchBuffer, scratchBufferSize)
      if bytesRead == 0 {
        break
      }
      output.append(UnsafePointer(scratchBuffer), count: bytesRead)
    }
    return output
    
    // return withLock {
    //   var filePointer = fopen("/opt/swift/pipes/\(process.readPipe)", "rb")!
    //   while true {
    //     let bytesRead = fread(scratchBuffer, 1, scratchBufferSize, filePointer)
    //     if bytesRead == 0 {
    //       break
    //     }
    //     output.append(UnsafePointer(scratchBuffer), count: bytesRead)
    //   }
    //   fclose(filePointer) 
      
    //   if output.count > 0 {
    //     // Erase the file's contents.
    //     filePointer = fopen("/opt/swift/pipes/\(process.readPipe)", "wb")!
    //     fclose(filePointer)
    //   }
    //   return output
    // }
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