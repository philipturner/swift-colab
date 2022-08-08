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

func fetchStderr(errorSource: inout (file: String, line: Int)?) -> [String] {
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
  
  // Parse the "__lldb_expr_NUM/<Cell NUM>:NUM: " prefix to the error message.
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
  var firstColonIndex: String.Index?
  var secondColonIndex: String.Index?
  for index in firstLine[slashIndex...].indices {
    if firstLine[index] == ":" {
      numColons += 1
    }
    if numColons == 1 && firstColonIndex == nil {
      firstColonIndex = index
    } else if numColons == 2 {
      secondColonIndex = index
      break
    }
  }
  guard let firstColonIndex = firstColonIndex, 
        let secondColonIndex = secondColonIndex else { return lines }
  
  let fileNameStartIndex = firstLine.index(after: slashIndex)
  var errorFile = String(firstLine[fileNameStartIndex..<firstColonIndex])
  if let moduleName = moduleName {
    errorFile = "\(moduleName)/\(errorFile)"
  }
  
  // The substring ends at the character right before the second colon. This
  // means the source location does not include a column.
  let errorLineStartIndex = firstLine.index(after: firstColonIndex)
  let errorLineStr = String(firstLine[errorLineStartIndex..<secondColonIndex])
  guard let errorLine = Int(errorLineStr) else { return lines }
  errorSource = (errorFile, errorLine)
  
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

func prettyPrintStackTrace(
  errorSource: (file: String, line: Int)?
) throws -> [String] {
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
    output.append(
      getLocationLine(file: errorSource.file, line: errorSource.line))
  }
  if size == 0 {
    output.append(formatString("Stack trace not available", ansiOptions: [36]))
    return output
  } else {
    output.append(formatString("Current stack trace:", ansiOptions: [36]))
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
    func extractComponent() -> String {
      let output = String(cString: UnsafePointer(data))
      data += output.count + 1
      return output
    }
    
    let function = extractComponent()
    let file = extractComponent()
    let directory = extractComponent()
    var path: String
    
    if let folder = extractPackageFolder(fromPath: directory) {
      // File is in a package's build checkouts.
      path = folder + "/" + file
      KernelContext.log("+")
      KernelContext.log("FOLDER")
    } else if directory.count > 0 {
      // File location not recognized.
      path = directory + "/" + file
      KernelContext.log("+")
      KernelContext.log("DIRECTORY")
    } else {
      // File is a notebook cell.
      path = file
      KernelContext.log("+")
      KernelContext.log("NOTEBOOK")
    }
    // KernelContext.log("\(function) ~ \(file) ~ \(directory) ~ \(path) ~")
    // KernelContext.log("function ~ file ~ directory ~ path ~")
    KernelContext.log("\(function) ~")
    KernelContext.log("\(file) ~")
    KernelContext.log("\(directory) ~")
    KernelContext.log("\(path) ~")
    KernelContext.log("-")
    path = formatString(path, ansiOptions: [32])
    
    var frameID = String(i + 1) + " "
    if frameID.count < padding {
      frameID += String(
        repeating: " " as Character, count: padding - frameID.count)
    }
    frameID = formatString(frameID, ansiOptions: [36])
    
    let separator = formatString(" - ", ansiOptions: [36])
    let lineLabel = formatString(", line ", ansiOptions: [36])
    let columnLabel = formatString(", column ", ansiOptions: [36])
    output.append(
      frameID + function + separator + path + lineLabel + line + columnLabel + 
      column)
  }
  return output
}

// This could theoretically work on any path, regardless of whether it's a 
// directory or a full file path.
fileprivate func extractPackageFolder(fromPath path: String) -> String? {
  // Follow along with an example URL:
  // path = /opt/swift/packages/1/.build/checkouts/Lib/Folder
  
  // Should never start with the symbolic link "/opt/swift/install-location".
  // Rather, it should start with that link's destination.
  guard path.hasPrefix(KernelContext.installLocation) else {
    return nil
  }
  var url = path.dropFirst(KernelContext.installLocation.count)
  // url = /1/.build/checkouts/Lib/Folder
  guard url.hasPrefix("/") else { return nil }
  url = url.dropFirst(1)
  // url = 1/.build/checkouts/Lib/Folder
  
  // Drop package ID
  let id = url.prefix(while: { $0.isHexDigit && !$0.isLetter })
  guard Int(id) != nil else { return nil }
  url = url.dropFirst(id.count)
  // url = /.build/checkouts/Lib/Folder
  
  let buildCheckouts = "/.build/checkouts/"
  guard url.hasPrefix(buildCheckouts) else { return nil }
  url = url.dropFirst(buildCheckouts.count)
  // url = Lib/Folder
  
  // Preserve "Folder" to demonstrate where the file is located within the 
  // package.
  return String(url)
}

func getLocationLine(file: String, line: Int) -> String {
  let locationLabel = formatString("Location: ", ansiOptions: [36])
  let formattedFile = formatString(file, ansiOptions: [32])
  let lineLabel = formatString(", line ", ansiOptions: [36])
  let formattedLine = formatString("\(line)", ansiOptions: [32])
  return locationLabel + formattedFile + lineLabel + formattedLine
}

func formatCompilerError(_ input: String) -> [String] {
  let label = formatString("Compile error: ", ansiOptions: [31])
  var lines = input.split(
    separator: "\n", omittingEmptySubsequences: false).map(String.init)
  guard lines.count > 0 else {
    return [label + "no error message available"]
  }
  
  // In Swift 5.6, the following line was prepended to parse errors.
  // "expression failed to parse:"
  if lines[0].hasPrefix("error: ") {
    lines = [label] + lines
  } else {
    // The error starts with a message such as "expression failed to parse:".
    lines[0] = label + lines[0]
  }
  
  enum LineType {
    case errorMessage
    case sourceCode
    case pointer
    case suggestion
  }
  var lineType: LineType = .errorMessage
  
  for i in lines[1...].indices {
    let line = lines[i]
    switch lineType {
    case .errorMessage:
      if line != "" {
        lines[i] = formatCompileErrorLine(line)
        lineType = .sourceCode
      }
    case .sourceCode:
      lineType = .pointer
    case .pointer:
      if line.contains("^") {
        lines[i] = formatString(line, ansiOptions: [1, 32])
        lineType = .suggestion
      }
    case .suggestion:
      if line == "" {
        lineType = .errorMessage
      }
    }
  }
  return lines
}

fileprivate func formatCompileErrorLine(_ input: String) -> String {
  enum MessageType {
    case error
    case warning
    case note
  }
  var messageType: MessageType
  
  var message: String
  let errorLabel = "error: "
  let warningLabel = "warning: "
  if input.hasPrefix(errorLabel) {
    message = String(input.dropFirst(errorLabel.count))
    messageType = .error
  } else if input.hasPrefix(warningLabel) {
    message = String(input.dropFirst(warningLabel.count))
    messageType = .warning
  } else {
    message = input
    messageType = .note
  }
  
  var firstColonIndex: String.Index?
  var secondColonIndex: String.Index?
  var thirdColonIndex: String.Index?
  for i in message.indices {
    let char = message[i]
    guard char == ":" else {
      continue
    }
    if firstColonIndex == nil {
      firstColonIndex = i
    } else if secondColonIndex == nil {
      secondColonIndex = i
    } else if thirdColonIndex == nil {
      thirdColonIndex = i
      break
    }
  }
  
  func formatMessage() -> String {
    return formatString(message, ansiOptions: [36])
  }
  guard let firstColonIndex = firstColonIndex,
        let secondColonIndex = secondColonIndex,
        let thirdColonIndex = thirdColonIndex else {
    return formatMessage()
  }
  
  let lineStartIndex = message.index(after: firstColonIndex)
  let columnStartIndex = message.index(after: secondColonIndex)
  var messageStartIndex = message.index(after: thirdColonIndex)
  messageStartIndex = message.index(after: messageStartIndex)
  
  let lineRange = lineStartIndex..<secondColonIndex
  let columnRange = columnStartIndex..<thirdColonIndex
  guard let line = Int(message[lineRange]),
        let column = Int(message[columnRange]),
        message.indices.contains(messageStartIndex) else {
    return formatMessage()
  }
  
  // Attempt to shorten file name.
  var file = String(message[..<firstColonIndex])
  if let folderWithFile = extractPackageFolder(fromPath: file) {
    file = folderWithFile
  }
  file = "\(file):\(line):\(column): "
  
  let shortenedMessage = String(message[messageStartIndex...])
  var label: String
  var ansiColor: Int
  switch messageType {
  case .error:
    if shortenedMessage.hasPrefix(errorLabel) {
      message = String(shortenedMessage.dropFirst(errorLabel.count))
      label = errorLabel
      ansiColor = 31
    } else {
      return formatMessage()
    }
  case .warning:
    if shortenedMessage.hasPrefix(warningLabel) {
      message = String(shortenedMessage.dropFirst(warningLabel.count))
      label = warningLabel
      ansiColor = 35
    } else {
      return formatMessage()
    }
  case .note:
    let noteLabel = "note: "
    if shortenedMessage.hasPrefix(noteLabel) {
      message = String(shortenedMessage.dropFirst(noteLabel.count))
      label = noteLabel
      ansiColor = 30
    } else {
      return formatMessage()
    }
  }
  
  file = formatString(file, ansiOptions: [1])
  label = formatString(label, ansiOptions: [1, ansiColor])
  message = formatString(message, ansiOptions: [1])
  return file + label + message
}
