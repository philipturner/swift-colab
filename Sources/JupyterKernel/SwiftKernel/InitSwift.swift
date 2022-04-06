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
  try initReplProcess()
  try initKernelCommunicator()
  try initBitWidth()
  
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

// This is no longer needed for any functional purpose, but it serves
// as a quick validation test that Swift-Colab actually works.
fileprivate func initBitWidth() throws {
  let result = execute(code: "Int.bitWidth")
  guard let result = result as? SuccessWithValue else {
    if result is SuccessWithoutValue {
      throw Exception("Got SuccessWithoutValue from Int.bitWidth")
    } else {
      throw Exception("Expected value from Int.bitWidth, but got: \(String(reflecting: result))")
    }
  }
  precondition(result.description.contains("64"), 
    "Int.bitWidth returned \(result.description) when '64' was expected.")
}
