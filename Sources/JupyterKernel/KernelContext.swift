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
    
    var writePipe: Int32 {
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
    precondition(pipe(&pipes) == 0, "Failed to create pipes.")
    pipe1 = pipes[0]
    pipe2 = pipes[1]
    precondition(
      fcntl(pipe1!, F_SETFL, O_NONBLOCK) == 0, "Failed to set 'O_NONBLOCK'.")
    // Child reads from this.
    // precondition(close(pipe1!) == 0, "Could not close pipe 1.")
    
    precondition(pipe(&pipes) == 0, "Failed to create pipes.")
    pipe3 = pipes[0]
    pipe4 = pipes[1]
    precondition(
      fcntl(pipe3!, F_SETFL, O_NONBLOCK) == 0, "Failed to set 'O_NONBLOCK'.")
    // Child writes into this.
    // precondition(close(pipe4!) == 0, "Could not close pipe 4.")
    
    // Write pipes to file.
    let filePointer = fopen("/opt/swift/pipes", "wb")!
    defer {
      fclose(filePointer)
    }
    
    let pid: Int32 = getpid()
    var buffer: [Int32] = [pipe1!, pipe2!, pipe3!, pipe4!, pid]
    fwrite(&buffer, 4, 5, filePointer)
    KernelContext.log("Pipe IDs: \(buffer)")
    
    func sendMessage(id: Int, pipe: Int32) {
      KernelContext.log("Starting to send \(id)")
      let path = "/opt/swift/socket\(id)"
      fclose(fopen(path, "wb")!)
      
      // Initialize `namesock`.
      var namesock = sockaddr_un()
      namesock.sun_family = sa_family_t(AF_UNIX)
      func withPointer1(_ ptr: UnsafeMutableRawPointer) {
        // +1 for null terminator
        strncpy(.init(OpaquePointer(ptr)), path, path.count + 1)
      }
      withPointer1(&namesock.sun_path)
      
      // Create and bind socket.
      let fd = socket(AF_UNIX, Int32(SOCK_DGRAM.rawValue), 0)
      precondition(fd != -1, "socket failed: \(errno)")
      func withPointer2(_ ptr: UnsafeRawPointer) {
        let stride = MemoryLayout<sockaddr_un>.stride
        precondition(
          bind(fd, .init(OpaquePointer(ptr)), socklen_t(stride)) != -1,
          "bind failed: \(errno)")
      }
      withPointer2(&namesock)

      // Call `write_fd`.
      precondition(
        write_fd(fd, nil, 0, pipe) > 0, "write_fd failed: \(errno)")
      precondition(close(fd) == 0, "Could not close fd \(fd)")
    }
    sendMessage(id: 1, pipe: pipe1!)
    sendMessage(id: 2, pipe: pipe2!)
    sendMessage(id: 3, pipe: pipe3!)
    sendMessage(id: 4, pipe: pipe4!)
  }
  
  static func fetchPipes() {
    // Read pipes from file.
    let filePointer = fopen("/opt/swift/pipes", "rb")!
    defer {
      fclose(filePointer)
    }
    var buffer = [Int32](repeating: 0, count: 4)
    fread(&buffer, 4, 5, filePointer)
    
    // Set pipes.
    let _src_pipe1 = buffer[0]
    let _src_pipe2 = buffer[1]
    let _src_pipe3 = buffer[2]
    let _src_pipe4 = buffer[3]
    let _src_pid = buffer[4]

    // From https://stackoverflow.com/a/42217485:
    func map_fd(_ source_pid: Int32, _ source_fd: Int32) -> Int32 {
      let fd_path = "/proc/\(source_pid)/fd/\(source_fd)"
      // var fd_path: [Int8] = Array(repeating: 0, count: 64)
      // snprintf(&fd_path, Int.bitWidth, "/proc/%d/fd/%d", source_pid, source_fd)
      var new_fd = open(fd_path, O_RDWR)
      if new_fd < 0 {
        new_fd = -100_000 - errno
      }
      return new_fd
    }
    // pipe1 = map_fd(_src_pid, _src_pipe1)
    // pipe2 = map_fd(_src_pid, _src_pipe2)
    // pipe3 = map_fd(_src_pid, _src_pipe3)
    // pipe4 = map_fd(_src_pid, _src_pipe4)
    
    // Will these functions not crash, now that FD is correct?
    //
    // Parent writes into this.
    // precondition(close(pipe2!) == 0, "Could not close pipe 2.")
    // Parent reads from this.
    // precondition(close(pipe3!) == 0, "Could not close pipe 3.")
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
    precondition(pipe == pipe4!)
    var header = Int64(data.count)
    precondition(
      Foundation.write(pipe, &header, 8) >= 0, 
      "Could not write to file3 \(pipe). \(errno)")
    precondition(
      Foundation.write(pipe, buffer, data.count) >= 0, 
      "Could not write to file4 \(pipe). \(errno)")
    
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
    precondition(pipe == pipe3!)
    while true {
      let bytesRead = Foundation.read(pipe, scratchBuffer, scratchBufferSize)
      KernelContext.log("BYTES READ: \(bytesRead)")
      if bytesRead <= 0 {
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

//===----------------------------------------------------------------------===//
// Translation of https://stackoverflow.com/a/2358843
//===----------------------------------------------------------------------===//

// Found the C macros at:
// https://opensource.apple.com/source/xnu/xnu-201/bsd/sys/socket.h.auto.html

func CMSG_DATA(
  _ cmsg: UnsafeMutablePointer<cmsghdr>
) -> UnsafeMutablePointer<UInt8> {
  let raw_ptr = OpaquePointer(cmsg.advanced(by: 1))
  return UnsafeMutablePointer(raw_ptr)
}

func CMSG_ALIGN(_ n: Int) -> Int {
  (n + 3) & ~3
}

func CMSG_FIRSTHDR(
  _ mhdr: UnsafeMutablePointer<msghdr>
) -> UnsafeMutablePointer<cmsghdr>? {
  let msg_control = mhdr.pointee.msg_control
  return msg_control?.assumingMemoryBound(to: cmsghdr.self)
}

func CMSG_SPACE(_ l: Int) -> Int {
  CMSG_ALIGN(MemoryLayout<cmsghdr>.stride + CMSG_ALIGN(l))
}

func CMSG_LEN(_ l: Int) -> Int {
  CMSG_ALIGN(MemoryLayout<cmsghdr>.stride + l)
}

// Code to pass the file descriptor.
// - fd: Either a file descriptor or unix socket; stores the message.
// - ptr: Maybe random data, just to validate that the message was correct.
func write_fd(
  _ fd: Int32,
  _ ptr: UnsafeMutableRawPointer?,
  _ nbytes: Int,
  _ sendfd: Int32
) -> Int {
  var msg = msghdr()
  var output: Int = 0
  withUnsafeTemporaryAllocation(of: iovec.self, capacity: 1) { iov in
    let control_size = CMSG_SPACE(4)
    withUnsafeTemporaryAllocation(
      of: Int8.self, capacity: control_size
    ) { control in
      msg.msg_control = UnsafeMutableRawPointer(control.baseAddress!)
      msg.msg_controllen = control_size
      
      let cmptr: UnsafeMutablePointer<cmsghdr> = CMSG_FIRSTHDR(&msg)!
      cmptr.pointee.cmsg_len = CMSG_LEN(4)
      cmptr.pointee.cmsg_level = SOL_SOCKET
      cmptr.pointee.cmsg_type = Int32(SCM_RIGHTS)
      
      let cmsg_data1 = CMSG_DATA(cmptr)
      let cmsg_data2 = OpaquePointer(cmsg_data1)
      let cmsg_data3 = UnsafeMutablePointer<Int32>(cmsg_data2)
      cmsg_data3.pointee = sendfd
      
      msg.msg_name = nil
      msg.msg_namelen = 0
      
      iov[0].iov_base = ptr
      iov[0].iov_len = nbytes
      msg.msg_iov = iov.baseAddress!
      msg.msg_iovlen = 1

      output = sendmsg(fd, &msg, 0)
    }
  }
  return output
}

// Code to receive the file descriptor.
// - fd: Either a file descriptor or unix socket; stores the message.
// - ptr: Maybe random data, just to validate that the message was correct.
func read_fd(
  _ fd: Int32,
  _ ptr: UnsafeMutableRawPointer?,
  _ nbytes: Int,
  _ recvfd: UnsafeMutablePointer<Int32>
) -> Int {
  var msg = msghdr()
  var output: Int = 0
  withUnsafeTemporaryAllocation(of: iovec.self, capacity: 1) { iov in
    let control_size = CMSG_SPACE(4)
    withUnsafeTemporaryAllocation(
      of: Int8.self, capacity: control_size
    ) { control in
      msg.msg_control = UnsafeMutableRawPointer(control.baseAddress!)
      msg.msg_controllen = control_size
      
      msg.msg_name = nil
      msg.msg_namelen = 0
      
      iov[0].iov_base = ptr
      iov[0].iov_len = nbytes
      msg.msg_iov = iov.baseAddress!
      msg.msg_iovlen = 1

      output = recvmsg(fd, &msg, 0)
      if let cmptr = CMSG_FIRSTHDR(&msg),
         cmptr.pointee.cmsg_len == CMSG_LEN(4) {
        if cmptr.pointee.cmsg_level != SOL_SOCKET {
          fatalError("control level != SOL_SOCKET")
        }
        if cmptr.pointee.cmsg_type != SCM_RIGHTS {
          fatalError("control type != SCM_RIGHTS")
        }

        let cmsg_data1 = CMSG_DATA(cmptr)
        let cmsg_data2 = OpaquePointer(cmsg_data1)
        let cmsg_data3 = UnsafeMutablePointer<Int32>(cmsg_data2)
        recvfd.pointee = cmsg_data3.pointee
      } else {
        recvfd.pointee = -1
      }
    }
  }
  return output
}