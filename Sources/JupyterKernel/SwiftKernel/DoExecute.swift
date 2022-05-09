import Foundation
fileprivate let json = Python.import("json")
fileprivate let jsonutil = Python.import("jupyter_client").jsonutil

func doExecute(code: String) throws -> PythonObject? {
  KernelContext.isInterrupted = false
  KernelContext.pollingStdout = true
  KernelContext.log("")
  KernelContext.log("code: \(code)")
  
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
    let traceback = [error.localizedDescription]
    sendIOPubErrorMessage(traceback)
    return makeExecuteReplyErrorMessage(traceback)
  } catch {
    let kernel = KernelContext.kernel
    sendIOPubErrorMessage([
      "Kernel is in a bad state. Try restarting the kernel.",
      "",
      "Exception in cell \(kernel.execution_count):",
      error.localizedDescription
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
    var traceback: [String] = []
    var isAlive: Int32 = 0
    _ = KernelContext.process_is_alive(&isAlive)
    
    if isAlive == 0 {
      traceback = ["Process killed"]
      sendIOPubErrorMessage(traceback)
      
      // Exit the kernel because there is no way to recover from a killed 
      // process. The UI will tell the user that the kernel has died and the UI 
      // will automatically restart the kernel. We do the exit in a callback so 
      // that this execute request can cleanly finish before the kernel exits.
      let loop = Python.import("tornado").ioloop.IOLoop.current()
      loop.add_timeout(Python.import("time").time() + 0.1, loop.stop)
    } else if Bool(handler.had_stdout)! {
      // Stderr contains the error message, so this block of code needs to add a 
      // stack trace.
      traceback = fetchStderr()
      traceback += try prettyPrintStackTrace()
      sendIOPubErrorMessage(traceback)      
    } else {
      // There is no stdout, so it must be a compile error. Simply return the 
      // error without trying to get a stack trace.
      traceback = [result.description]
      sendIOPubErrorMessage(traceback)
    }
    
    return makeExecuteReplyErrorMessage(traceback)
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

fileprivate func fetchStderr() -> [String] {
  guard let stderr = getStderr(readData: true) else {
    return ["Current stack trace:"]
  }
  var lines = stderr.split(separator: "\n", omittingEmptySubsequences: false)
    .map(String.init)
  guard let stackTraceIndex = lines.lastIndex(of: "Current stack trace:") else {
    return lines + ["Current stack trace:"]
  }
////////////////////////////////////////////////////////////////////////////////
  // Return early if there is no error message.
  guard stackTraceIndex > 0 else {
    return lines
  }
  lines.removeLast(lines.count - stackTraceIndex)
  lines.append("Current stack trace:")
  
  // Remove the "__lldb_expr_NUM/<Cell NUM>:NUM: " prefix to the error message.
  let firstLine = lines[0]
  guard firstLine.hasPrefix("__lldb_expr_") else { return lines }
  guard let slashIndex = firstLine.firstIndex(of: "/") else { return lines }
////////////////////////////////////////////////////////////////////////////////
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
  let messageStartIndex = firstLine.index(secondColonIndex, offsetBy: 2)
  guard firstLine.indices.contains(messageStartIndex) else { return lines }
  
  // Todo: preserve slashIndex..<(messageStartIndex - 1). If they
  // unwrap an optional, there is no stack trace. The header would at least
  // allow synthesizing one frame.
  
  // The error message may span multiple lines, so just modify the first line
  // in-place and return the array.
  lines[0] = String(firstLine[messageStartIndex...])
  return lines
//   if let stderr = getStderr(readData: true) {
//         let lines = stderr.split(
//           separator: "\n", omittingEmptySubsequences: true)
//         var addedErrorMessage = false
        
//         if let stackTraceIndex = lines.lastIndex(where: {
//           $0.hasPrefix("Current stack trace:")
//         }), stackTraceIndex == 1 {
//           let firstLine = lines[0]
//           if firstLine.hasPrefix("__lldb_expr"), 
//              let slashIndex = firstLine.firstIndex(of: "/") {
//             var numColons = 0
//             for index in firstLine[slashIndex...].indices {
//               if firstLine[index] == ":" {
//                 numColons += 1
//               }
//               if numColons == 2 {
//                 let messageIndex = firstLine.index(index, offsetBy: 2)
//                 let message = String(firstLine[messageIndex...])
//                 traceback = [message] + traceback
//                 addedErrorMessage = true
//                 break
//               }
//             }
//           }
//         }
//         if !addedErrorMessage {
//           traceback += ["", "Received error message:", stderr]
//         }
//       }
}

fileprivate func prettyPrintStackTrace() throws -> [String] {
  var output: [String] = []
  var frames: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>?
  var size: Int32 = 0
  let error = KernelContext.get_pretty_stack_trace(&frames, &size);
  guard let frames = frames else {
    throw Exception(
      "`get_pretty_stack_trace` failed with error code \(error).")
  }
  
  for i in 0..<Int(size) {
    let frame = frames[i]
    let description = String(cString: UnsafePointer(frame))
    var frameID = String(i + 1) + " "
    if frameID.count < 5 {
      frameID += String(repeating: " " as Character, count: 5 - frameID.count)
    }
    output.append(frameID + description)
    free(frame)
  }
  free(frames)
  return output
}

fileprivate func makeExecuteReplyErrorMessage(_ message: [String]) -> PythonObject {
  return [
    "status": "error",
    "execution_count": KernelContext.kernel.execution_count,
    "ename": "",
    "evalue": "",
    "traceback": message.pythonObject
  ]
}

fileprivate func sendIOPubErrorMessage(_ message: [String]) {
  KernelContext.sendResponse("error", [
    "ename": "",
    "evalue": "",
    "traceback": message.pythonObject
  ])
}

