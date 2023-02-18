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
  

  KernelContext.log("A: \(Python.import("numpy").ndarray(1))")
  try initReplProcess()
  try initKernelCommunicator()
  try initConcurrency()
  try initSIGINTHandler()
}

fileprivate func initReplProcess() throws {
  KernelContext.log("B: \(Python.import("numpy").ndarray(1))")
  let environment = ProcessInfo.processInfo.environment
  let cEnvironment = CEnvironment(environment: environment)
  KernelContext.log("C: \(Python.import("numpy").ndarray(1))")

  let error = KernelContext.init_repl_process(
    cEnvironment.envp, FileManager.default.currentDirectoryPath)
  KernelContext.log("C.2:", Array<Int>(arrayLiteral: [Int.random(in: 0..<5)]).count)
  KernelContext.log("D: \(Python.import("numpy").ndarray(1))")
  if error != 0 {
    throw Exception("Got error code \(error) from 'init_repl_process'")
  }
  KernelContext.log("E: \(Python.import("numpy").ndarray(1))")
}

fileprivate func initKernelCommunicator() throws {
  var result = try preprocessAndExecute(code: """
    %include "KernelCommunicator.swift"
    """)
  if result is ExecutionResultError {
    throw Exception("Error initializing KernelCommunicator: \(result)")
  }
  
  let session = KernelContext.kernel.session
  let id = String(session.session)!
  let key = String(session.key.decode("utf8"))!
  let username = String(session.username)!
  
  result = try preprocessAndExecute(code: """
    enum JupyterKernel {
      static var communicator = KernelCommunicator(
        jupyterSession: KernelCommunicator.JupyterSession(
          id: "\(id)", key: "\(key)", username: "\(username)"))
    }
    """)
  if result is ExecutionResultError {
    throw Exception("Error declaring JupyterKernel: \(result)")
  }
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
