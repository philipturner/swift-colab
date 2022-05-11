import Foundation
import PythonKit

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
  
  if size == 0 {
    // If there are no frames, try to show where the error originated.
    if let errorSource = errorSource {
      return ["Location: \(errorSource)"]
    } else {
      return ["Stack trace not available"]
    }
  }
  
  // Number of characters, including digits and spaces, before a function name.
  let padding = 5
  
  var output: [String] = ["Current stack trace:"]
  for i in 0..<Int(size) {
    let frameBytes = frames[i]
    defer { free(frameBytes) }
    
    var data = frameBytes.advanced(by: 8).assumingMemoryBound(to: CChar.self)
    let fileName = String(cString: UnsafePointer(data))
    var frame = formatString(fileName, ansiOptions: [34])
    
    let header = frameBytes.assumingMemoryBound(to: UInt32.self)
    let line = formatString("\(header[0])", ansiOptions: [32])
    let column = formatString("\(header[1])", ansiOptions: [32])
    frame += ", Line \(line), Column \(column)"
    
    data = data.advanced(by: fileName.count + 1)
    let directory = String(cString: UnsafePointer(data))
    if directory.count > 0 {
      frame += ", Directory: \(formatString(directory, ansiOptions: [32]))"
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
