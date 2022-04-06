import Foundation

fileprivate let PyMemoryView_FromMemory: @convention(c) (
  UnsafeMutablePointer<CChar>, Int64, Int32) -> PyObjectPointer = 
  PythonLibrary.loadSymbol(name: "PyMemoryView_FromMemory")

fileprivate let PyBUF_READ: Int32 = 0x100

func afterSuccessfulExecution() throws {
  var serializedOutput: UnsafeMutablePointer<UInt64>?
  let error = KernelContext.after_successful_execution(&serializedOutput)
  guard let serializedOutput = serializedOutput else {
    throw Exception(
      "C++ part of `afterSuccessfulExecution` failed with error code \(error).")
  }
   
  let output = try deserialize(executionOutput: serializedOutput)
  
  let kernel = KernelContext.kernel
  let send_multipart = kernel.iopub_socket.send_multipart.throwing
  for message in output {
    try send_multipart.dynamicallyCall(withArguments: message.pythonObject)
  }
  
  free(serializedOutput)
}

fileprivate func deserialize(
  executionOutput: UnsafeMutablePointer<UInt64>
) throws -> [[PythonObject]] {
  var stream = executionOutput
  let numJupyterMessages = Int(stream.pointee)
  stream += 1
  
  var jupyterMessages: [[PythonObject]] = []
  jupyterMessages.reserveCapacity(numJupyterMessages)
  for _ in 0..<numJupyterMessages {
    let numParts = Int(stream.pointee)
    stream += 1
    
    var message: [PythonObject] = []
    message.reserveCapacity(numParts)
    for _ in 0..<numParts {
      let numBytes = Int(stream.pointee)
      stream += 1
      
      let byteArray = PythonObject(consuming: PyMemoryView_FromMemory(
        UnsafeMutablePointer<CChar>(OpaquePointer(stream)),
        Int64(numBytes),
        PyBUF_READ
      ))
      
      message.append(byteArray)
      stream += (numBytes + 7) / 8
    }
    jupyterMessages.append(message)
  }
  
  return jupyterMessages
}
