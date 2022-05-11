import Foundation

func formatString(_ input: String, ansiOptions: [Int]) -> String {
  var formatSequence = "\u{1b}[0"
  for option in ansiOptions {
    formatSequence += ";\(option)"
  }
  formatSequence += "m"
  let clearSequence = "\u{1b}[0m"
  return formatSequence + input + clearSequence
}

func fetchStderr(errorSource: inout String?) -> [String] {
  guard let stderr = getStderr(readData: true) else {
    return []
  }
  var lines = stderr.split(separator: "\n", omittingEmptySubsequences: false)
    .map(String.init)
  guard let stackTraceIndex = lines.lastIndex(of: "Current stack trace:") else {
    return lines
  }
  
  // Return early if there is no error message.
  guard stackTraceIndex > 0 else { return lines }
  lines.removeLast(lines.count - stackTraceIndex)
  
  // Remove the "__lldb_expr_NUM/<Cell NUM>:NUM: " prefix to the error message.
  let firstLine = lines[0]
  guard let slashIndex = firstLine.firstIndex(of: "/"), 
        slashIndex > firstLine.startIndex else { 
    return lines 
  }
  var moduleName: String?
  if !firstLine.hasPrefix("__lldb_expr_") { 
    moduleName = String(firstLine[..<slashIndex])
  }
  
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
  if let moduleName = moduleName {
    errorSource = "\(moduleName)/\(errorSource!)"
  }
  
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

func prettyPrintStackTrace(errorSource: String?) throws -> [String] {
  var frames: UnsafeMutablePointer<UnsafeMutableRawPointer>?
  var size: Int32 = 0
  let error = KernelContext.get_pretty_stack_trace(&frames, &size);
  guard let frames = frames else {
    throw Exception(
      "`get_pretty_stack_trace` failed with error code \(error).")
  }
  defer { free(frames) }
  
  // Show where the error originated, regardless of whether there are stack 
  // frames.
  var output: [String] = []
  if let errorSource = errorSource {
    output.append("Location: \(errorSource)")
  }
  
  if size == 0 {
    output.append("Stack trace not available")
    return
  } else {
    output.append("Current stack trace:")
  }
  
  // Number of characters, including digits and spaces, before a function name.
  let padding = 5
  for i in 0..<Int(size) {
    let frameBytes = frames[i]
    defer { free(frameBytes) }
    
    let header = frameBytes.assumingMemoryBound(to: UInt32.self)
    let line = formatString("\(header[0])", ansiOptions: [32])
    let column = formatString("\(header[1])", ansiOptions: [32])
    
    var data = frameBytes.advanced(by: 8).assumingMemoryBound(to: CChar.self)
    var function = String(cString: UnsafePointer(data))
    function = formatString(function, ansiOptions: [34])
    
    var frame = formatString(fileName, ansiOptions: [34])
    
    
    frame += ", Line \(line), Column \(column)"
    
    data = data.advanced(by: fileName.count + 1)
    let directory = String(cString: UnsafePointer(data))
    if directory.count > 0 {
      // I'm torn on whether to say "Directory" or "Path" here. "Path" isn't
      // entirely accurate, because its last component (the file name) is left
      // out for brevity.
      frame += ", Path: \(formatString(directory, ansiOptions: [32]))"
    }
    
    var frameID = String(i + 1) + " "
    if frameID.count < padding {
      frameID += String(
        repeating: " " as Character, count: padding - frameID.count)
    }
    output.append(frameID + frame)
  }
  return output
}
