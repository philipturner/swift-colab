import Foundation
fileprivate let builtins = Python.import("builtins")
fileprivate let getpass = Python.import("getpass")
fileprivate let json = Python.import("json")
fileprivate let jsonutil = Python.import("jupyter_client").jsonutil

func doExecute(code: String, allowStdin: Bool) throws -> PythonObject? {
  // Reset the pipes here, where `SIGINTHandler` can't simultaneously send an
  // interrupt. Otherwise, the LLDB process might halt while exchanging file
  // handles.
  try KernelContext.lldbQueue.sync {
    try configureCellPipes()
  }
  
  KernelContext.isInterrupted = false
  KernelContext.pollingStdout = true
  KernelContext.cellID = Int(KernelContext.kernel.execution_count)!
  forwardInput(allowStdin: allowStdin)
  
  // Flush stderr
  _ = getStderr(readData: false)
  
  let handler = StdoutHandler()
  handler.start()
  
  // Execute the cell, handle unexpected exceptions, and make sure to always 
  // clean up the stdout handler.
  var result: ExecutionResult
  do {
    defer {
      restoreInput()
      KernelContext.pollingStdout = false
      handler.join()
    }
    result = try executeCell(code: code)
  } catch _ as InterruptException {
    return nil
  } catch let error as PreprocessorError {
    let label = formatString("\(type(of: error).label): ", ansiOptions: [31])
    let cellID = KernelContext.cellID
    let message = [
      "\(label)\(error.localizedDescription)",
      getLocationLine(file: "<Cell \(cellID)>", line: error.lineIndex + 1)
    ]
    sendIOPubErrorMessage(message)
    return makeExecuteReplyErrorMessage(message)
  } catch {
    sendIOPubErrorMessage([
      "Kernel is in a bad state. Try restarting the kernel.",
      "",
      "Exception in cell \(KernelContext.cellID):",
      "\(error.localizedDescription)"
    ])
    throw error
  }
  
  // Send values/errors and status to the client.
  if result is SuccessWithValue {
    KernelContext.sendResponse("execute_result", [
      "execution_count": PythonObject(KernelContext.cellID),
      "data": [
        "text/plain": PythonObject(result.description)
      ],
      "metadata": [:]
    ])
    return nil
  } else if result is SuccessWithoutValue {
    return nil
  } else if result is SwiftError {
    var message: [String]
    if KernelContext.process_is_alive() == 0 {
      message = [formatString("Process killed", ansiOptions: [31])]
      sendIOPubErrorMessage(message)
      
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
      var errorSource: (file: String, line: Int)?
      message = fetchStderr(errorSource: &errorSource)
      
      if message.count == 0 && KernelContext.isInterrupted {
        // LLDB returned an error because it was interrupted. No need for a 
        // diagnostic explaining that.
        return nil
      }
      message += try prettyPrintStackTrace(errorSource: errorSource)
      sendIOPubErrorMessage(message)
    } else {
      // There is no stdout, so it must be a compile error. Simply return the 
      // error without trying to get a stack trace.
      message = formatCompilerError(result.description)
      
      // Forward this as "stream" instead of "error" to preserve bold 
      // formatting. This also means the lines will not wrap.
      KernelContext.sendResponse("stream", [
        "name": "stdout",
        "text": message.joined(separator: "\n")
      ])
      sendIOPubErrorMessage([])
    }
    return makeExecuteReplyErrorMessage(message)
  } else {
    fatalError("This should never happen.")
  }
}

fileprivate func configureCellPipes() throws {
  KernelPipe.closeHandles()
  // KernelPipe.fetchPipes(.jupyterKernel)
  do {
    // let result = execute(code: """
    //   KernelCommunicator.callSymbol("fetch_pipes")
    //   """)
    // if result is ExecutionResultError {
    //   throw Exception("Error fetching pipes: \(result)")
    // }
  }
}

// Forward raw_input and getpass to the current front via input_request.
fileprivate func forwardInput(allowStdin: Bool) {
  let kernel = KernelContext.kernel
  kernel._allow_stdin = PythonObject(allowStdin)
  
  kernel._sys_raw_input = builtins.input
  builtins.input = kernel.raw_input

  kernel._save_getpass = getpass.getpass
  getpass.getpass = kernel.getpass
}

// Restore raw_input, getpass
fileprivate func restoreInput() {
  let kernel = KernelContext.kernel
  builtins.input = kernel._sys_raw_input
  getpass.getpass = kernel._save_getpass
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

fileprivate func makeExecuteReplyErrorMessage(
  _ message: [String]
) -> PythonObject {
  return [
    "status": "error",
    "execution_count": PythonObject(KernelContext.cellID),
    "ename": "",
    "evalue": "",
    "traceback": PythonObject(message)
  ]
}
