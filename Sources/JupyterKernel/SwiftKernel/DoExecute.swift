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
    sendIOPubErrorMessage(error.localizedDescription)
    return makeExecuteReplyErrorMessage()
  } catch {
    let kernel = KernelContext.kernel
    sendStreamMessage("""
      Kernel is in a bad state. Try restarting the kernel.
      
      Exception in cell \(kernel.execution_count):
      \(error.localizedDescription)
      """)
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
      sendStreamMessage("Process killed")
      
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
      var errorSource: String?
      
      let errorMessage = fetchStderr(errorSource: &errorSource)
      let traceback = try prettyPrintStackTrace(errorSource: errorSource)
      sendIOPubErrorMessage(errorMessage)
      sendStreamMessage(String(traceback.joined(separator: "\n")))
    } else {
      // There is no stdout, so it must be a compile error. Simply return the 
      // error without trying to get a stack trace.
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

fileprivate func fetchStderr(errorSource: inout String?) -> [String] {
  guard let stderr = getStderr(readData: true) else {
    return []
  }
  var lines = stderr.split(separator: "\n", omittingEmptySubsequences: false)
    .map(String.init)
  guard let stackTraceIndex = lines.lastIndex(of: "Current stack trace:") else {
    return lines
  }
  
  // Return early if there is no error message.
  guard stackTraceIndex > 0 else {
    return lines
  }
  lines.removeLast(lines.count - stackTraceIndex)
  
  // Remove the "__lldb_expr_NUM/<Cell NUM>:NUM: " prefix to the error message.
  let firstLine = lines[0]
  guard firstLine.hasPrefix("__lldb_expr_") else { return lines }
  guard let slashIndex = firstLine.firstIndex(of: "/") else { return lines }
  
  var numColons = 0
  var secondColonIndex: String.Index?
  for index in firstLine[slashIndex...].indices {
    if firstLine[index] == ":" {
      numColons += 1
    }
    if numColons == 2 {
      secondColonIndex = index
      break
    }
  }
  guard let secondColonIndex = secondColonIndex else { return lines }
  
  // The substring ends at the character right before the second colon. This
  // means the source location does not include a column.
  let angleBracketIndex = firstLine.index(after: slashIndex) // index of "<"
  errorSource = String(firstLine[angleBracketIndex..<secondColonIndex])
  
  // The line could theoretically end right after the second colon.
  let messageStartIndex = firstLine.index(secondColonIndex, offsetBy: 2)
  guard firstLine.indices.contains(messageStartIndex) else { return lines }
  
  // The error message may span multiple lines, so just modify the first line
  // in-place and return the array.
  lines[0] = colorizeErrorMessage(String(firstLine[messageStartIndex...]))
  return lines
}

fileprivate func colorizeErrorMessage(_ message: String) -> String {
  var colonIndex: String.Index?
  for index in message.indices {
    if message[index] == ":" {
      colonIndex = index
      break
    }
  }
  guard let colonIndex = colonIndex else {
    return message
  }
  
  let labelPortion = formatString(
    String(message[...colonIndex]), ansiOptions: [31])
  let contentsStartIndex = message.index(after: colonIndex)
  return labelPortion + String(message[contentsStartIndex...])
}

fileprivate func formatString(_ input: String, ansiOptions: [Int]) -> String {
  var formatSequence = "\u{1b}[0"
  for option in ansiOptions {
    formatSequence += ";\(option)"
  }
  formatSequence += "m"
  let clearSequence = "\u{1b}[0m"
  return formatSequence + input + clearSequence
}

fileprivate func prettyPrintStackTrace(errorSource: String?) throws -> [String] {
  var frames: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>?
  var size: Int32 = 0
  let error = KernelContext.get_pretty_stack_trace(&frames, &size);
  guard let frames = frames else {
    throw Exception(
      "`get_pretty_stack_trace` failed with error code \(error).")
  }
  defer { free(frames) }
  
  if size == 0 {
    // If there are no frames, try to show where the error originated.
    if let errorSource = errorSource {
      return ["Location: \(errorSource)"]
    } else {
      return ["Stack trace not available"]
    }
  }
  
////////////////////////////////////////////////////////////////////////////////
  // Number of characters, including digits and spaces, before a function name.
  let padding = 5
  
  var output: [String] = ["Current stack trace:"]
  for i in 0..<Int(size) {
    let frame = frames[i]
    defer { free(frame) }
    
    let description = String(cString: UnsafePointer(frame))
    var frameID = String(i + 1) + " "
    if frameID.count < padding {
      frameID += String(
        repeating: " " as Character, count: padding - frameID.count)
    }
    output.append(frameID + description)
  }
  return output
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

// Erases bold/light formatting and forces lines to wrap in notebook.
fileprivate func sendIOPubErrorMessage(_ message: [String]) {
  KernelContext.sendResponse("stream", [
    "ename": "",
    "evalue": "",
    "traceback": message.pythonObject
  ])
}

// Preserves all formatting and does not wrap lines.
fileprivate func sendStreamMessage(_ message: String) {
  KernelContext.sendResponse("stream", [
    "name": "stdout",
    "text": (message + "\n").pythonObject
  ])
}
