import Foundation

fileprivate struct CEnvironment {
  var envp: OpaquePointer
  
  init(environment: [String: String]) {
    var envArray: [String] = []
    for (key, value) in environment {
      envArray.append("\(key)=\(value)")
    }
    
    typealias EnvPointer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    let envPointer = EnvPointer.allocate(capacity: envArray.count + 1)
    envPointer[envArray.count] = nil
    for i in 0..<envArray.count {
      let originalStr = envArray[i]
      let strPointer = UnsafeMutablePointer<CChar>
        .allocate(capacity: originalStr.count + 1)
      _ = originalStr.withCString {
        memcpy(strPointer, $0, originalStr.count + 1)
      }
      envPointer[i] = strPointer
    }
    envp = OpaquePointer(envPointer)
  }
}

func initSwift() throws {
  KernelPipe.resetPipes()
  KernelPipe.fetchPipes(currentProcess: .jupyterKernel)
  _ = KernelContext.mutex
  
  try initReplProcess()
  try initKernelCommunicator()
  try initConcurrency()
  try initSIGINTHandler()
}

fileprivate func initReplProcess() throws {
  let environment = ProcessInfo.processInfo.environment
  let cEnvironment = CEnvironment(environment: environment)

  let error = KernelContext.init_repl_process(
    cEnvironment.envp, FileManager.default.currentDirectoryPath)
  if error != 0 {
    throw Exception("Got error code \(error) from 'init_repl_process'")
  }
}

fileprivate func initKernelCommunicator() throws {
  KernelContext.log("0")
  var result = try preprocessAndExecute(code: """
    %include "KernelCommunicator.swift"
    """)
  KernelContext.log("1")
  if result is ExecutionResultError {
    throw Exception("Error initializing KernelCommunicator: \(result)")
  }
  KernelContext.log("2")
  
  let session = KernelContext.kernel.session
  KernelContext.log("3")
  let id = String(session.session)!
  let key = String(session.key.decode("utf8"))!
  let username = String(session.username)!
  KernelContext.log("4")
  
  result = try preprocessAndExecute(code: """
    enum JupyterKernel {
      static var communicator = KernelCommunicator(
        jupyterSession: KernelCommunicator.JupyterSession(
          id: "\(id)", key: "\(key)", username: "\(username)"))
    }
    """)
  KernelContext.log("5")
  if result is ExecutionResultError {
    throw Exception("Error declaring JupyterKernel: \(result)")
  }
  KernelContext.log("6")
}

fileprivate func initConcurrency() throws {
  // If this is a pre-concurrency Swift version, the import is a no-op.
  let result = execute(code: """
    import _Concurrency
    """)
  if result is ExecutionResultError {
    throw Exception("Error importing _Concurrency: \(result)")
  }
}

fileprivate func initSIGINTHandler() throws {
  DispatchQueue.global().async {
    while true {
      var signal_set = sigset_t()
      sigemptyset(&signal_set)
      sigaddset(&signal_set, SIGINT) 
      
      var sig: Int32 = 0
      sigwait(&signal_set, &sig)
      
      _ = KernelContext.mutex.acquire()
      _ = KernelContext.async_interrupt_process()
      _ = KernelContext.mutex.release()
      KernelContext.isInterrupted = true
    }
  }
}
