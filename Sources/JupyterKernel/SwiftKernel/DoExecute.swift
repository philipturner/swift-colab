import Foundation
fileprivate let json = Python.import("json")
fileprivate let jsonutil = Python.import("jupyter_client").jsonutil

func doExecute(code: String) throws -> PythonObject? {
  KernelContext.isInterrupted = false
  KernelContext.pollingStdout = true
  KernelContext.log("\n" + "code: \(code)")
  
  // Flush stderr
  _ = getStderr(readData: false)
  
  let handler = StdoutHandler()
  handler.start()
  
  // Execute the cell, handle unexpected exceptions, and make sure to always 
  // clean up the stdout handler.
  var result: ExecutionResult
  do {
    defer {
      KernelContext.pollingStdout = false
      handler.join()
    }
    result = try executeCell(code: code)
  } catch _ as InterruptException {
    return nil
  } catch let error as PackageInstallException {
    sendIOPubErrorMessage([error.localizedDescription])
    return makeExecuteReplyErrorMessage()
  } catch {
    let kernel = KernelContext.kernel
    sendIOPubErrorMessage([
      "Kernel is in a bad state. Try restarting the kernel.",
      "",
      "Exception in cell \(kernel.execution_count):",
      "\(error.localizedDescription)"
    ])
    throw error
  }
  
  // Send values/errors and status to the client.
  if result is SuccessWithValue {
    KernelContext.sendResponse("execute_result", [
      "execution_count": KernelContext.kernel.execution_count,
      "data": [
        "text/plain": result.description.pythonObject
      ],
      "metadata": [:]
    ])
    return nil
  } else if result is SuccessWithoutValue {
    return nil
  } else if result is ExecutionResultError {
    if KernelContext.process_is_alive() == 0 {
      sendIOPubErrorMessage(["Process killed"])
      
      // Exit the kernel because there is no way to recover from a killed 
      // process. The UI will tell the user that the kernel has died and the UI 
      // will automatically restart the kernel. We do the exit in a callback so 
      // that this execute request can cleanly finish before the kernel exits.
      let loop = Python.import("tornado").ioloop.IOLoop.current()
      loop.add_timeout(Python.import("time").time() + 0.1, loop.stop)
    } else if Bool(handler.had_stdout)! {
      // If it crashed while unwrapping `nil`, there is no stack trace. To solve
      // this problem, extract where it crashed from the error message. If no
      // stack frames are generated, at least show where the error originated.
      // TODO: Parse the error source from (module/file:line) to (module/file, 
      // Line line) with style in `fetchStderr`.
      var errorSource: String?
      
      var message = fetchStderr(errorSource: &errorSource)
      message += try prettyPrintStackTrace(errorSource: errorSource)
      sendIOPubErrorMessage(message)
    } else if result is SwiftError {
      // There is no stdout, so it must be a compile error. Simply return the 
      // error without trying to get a stack trace.
      let message = result.description.split( /* call formatting function */
        separator: "\n", omittingEmptySubsequences: false).map(String.init)
      sendIOPubErrorMessage(message)
    } else /* PreprocessorError or other */ {
      // This is a custom error, so any styling should have been applied before 
      // it was thrown.
    sendIOPubErrorMessage([result.description])
    }
    
    return makeExecuteReplyErrorMessage()
  } else {
    fatalError("This should never happen.")
  }
}

fileprivate func executeCell(code: String) throws -> ExecutionResult {
  try setParentMessage()
  let result = try preprocessAndExecute(code: code, isCell: true)
  if result is ExecutionResultSuccess {
    try afterSuccessfulExecution()
  }
  return result
}

fileprivate func setParentMessage() throws {
  let parentHeader = KernelContext.kernel._parent_header
  let jsonObj = json.dumps(json.dumps(jsonutil.squash_dates(parentHeader)))
  
  let result = execute(code: """
    JupyterKernel.communicator.updateParentMessage(
      to: KernelCommunicator.ParentMessage(json: \(String(jsonObj)!)))
    """)
  if result is ExecutionResultError {
    throw Exception("Error setting parent message: \(result)")
  }
}

// Erases bold/light formatting, forces lines to wrap in notebook, and adds a
// button to search Stack Overflow.
fileprivate func sendIOPubErrorMessage(_ message: [String]) {
  KernelContext.sendResponse("error", [
    "ename": "",
    "evalue": "",
    "traceback": PythonObject(message)
  ])
}

fileprivate func makeExecuteReplyErrorMessage() -> PythonObject {
  return [
    "status": "error",
    "execution_count": KernelContext.kernel.execution_count,
    "ename": "",
    "evalue": "",
    "traceback": PythonObject([])
  ]
}
