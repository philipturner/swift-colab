import Foundation

fileprivate struct CEnvironment {
  var envp: OpaquePointer
  
  init(environment: [String: String]) {
    var envArray: [String] = []
    for (key, value) in environment {
      envArray.append("\(key)=\(value)")
    }
    
    typealias EnvPointerType = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    let envPointer = EnvPointerType.allocate(capacity: envArray.count + 1)
    envPointer[envArray.count] = nil
    for i in 0..<envArray.count {
      let originalStr = envArray[i]
      let strPointer = UnsafeMutablePointer<CChar>.allocate(capacity: originalStr.count + 1)
      _ = originalStr.withCString {
        memcpy(strPointer, $0, originalStr.count + 1)
      }
      envPointer[i] = strPointer
    }
    envp = OpaquePointer(envPointer)
  }
}

fileprivate var sigintHandler: PythonObject!

func initSwift() throws {
  KernelContext.log("hello world 1")
  KernelPipe.createPipes()
  KernelContext.log("hello world 2")
  try initReplProcess()
  KernelContext.log("hello world 3")
  try initKernelCommunicator()
  KernelContext.log("hello world 4")
  try initConcurrency()
  KernelContext.log("hello world 5")
  
  sigintHandler = SIGINTHandler()
  sigintHandler.start()
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
  KernelContext.log("mark 1")
  var result = try preprocessAndExecute(code: """
    %include "KernelCommunicator.swift"
    """)
  KernelContext.log("mark 2")
  if result is ExecutionResultError {
    throw Exception("Error initializing KernelCommunicator: \(result)")
  }
  KernelContext.log("mark 3")
  
  let session = KernelContext.kernel.session
  let id = String(session.session)!
  let key = String(session.key.decode("utf8"))!
  let username = String(session.username)!
  KernelContext.log("mark 4")
  
  result = try preprocessAndExecute(code: """
    enum JupyterKernel {
      static var communicator = KernelCommunicator(
        jupyterSession: KernelCommunicator.JupyterSession(
          id: "\(id)", key: "\(key)", username: "\(username)"))
    }
    """)
  KernelContext.log("mark 5")
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
