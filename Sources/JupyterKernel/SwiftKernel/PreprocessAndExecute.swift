import Foundation
fileprivate let re = Python.import("re")
fileprivate let time = Python.import("time")

func preprocessAndExecute(
  code: String, isCell: Bool = false
) throws -> ExecutionResult {
  let preprocessed = try preprocess(code: code)
  var executionResult: ExecutionResult?
  KernelContext.lldbQueue.async {
    executionResult = execute(
      code: preprocessed, lineIndex: isCell ? 0 : nil, isCell: isCell)
  }
  
  while executionResult == nil {
    // Using Python's `time` module instead of Foundation.usleep releases the
    // GIL.
    time.sleep(0.05)
    
    if isCell {
      let messages = KernelPipe.recv(from: .lldb)
      precondition(messages.count <= 1, "Received more than one message.")
      if messages.count == 0 {
        continue
      }
      let response = execute_message(messages[0])
      KernelPipe.send(response, to: .lldb)
    }
  }
  return executionResult!
}

func execute(
  code: String, lineIndex: Int? = nil, isCell: Bool = false
) -> ExecutionResult {
  // Send a header to stdout, letting the StdoutHandler know that it compiled 
  // without errors and executed in LLDB.
  var prefixCode = isCell ? "print(\"HEADER\")\n" : ""
  if let lineIndex = lineIndex {
    prefixCode += getLocationDirective(lineIndex: lineIndex)
  } else {
    prefixCode += """
      #sourceLocation(file: "n/a", line: 1)
      """
  }
  
  let codeWithPrefix = prefixCode + "\n" + code
  var descriptionPtr: UnsafeMutablePointer<CChar>?
  let error = KernelContext.execute(codeWithPrefix, &descriptionPtr)
  
  var description: String?
  if let descriptionPtr = descriptionPtr {
    description = String(cString: descriptionPtr)
    free(descriptionPtr)
  }
  
  if error == 0 {
    return SuccessWithValue(description: description!)
  } else if error == 1 {
    return SuccessWithoutValue()
  } else if error == 2 {
    return SwiftError(description: description!)
  } else {
    fatalError("C++ `execute` function produced unexpected return code.")
  }
}

// Location directive for the current cell. This adds one to `lineIndex` before 
// creating the string. This does not include the newline that should come after 
// the directive.
fileprivate func getLocationDirective(lineIndex: Int) -> String {
  return """
    #sourceLocation(file: "<Cell \(KernelContext.cellID)>", line: \(lineIndex + 1))
    """
}

fileprivate func preprocess(code: String) throws -> String {
  let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
    .map(String.init)
  let preprocessedLines = try lines.indices.map { i -> String in
    let line = lines[i]
    guard line.contains("%") else {
      return line
    }
    return try preprocess(line: line, index: i)
  }
  return preprocessedLines.joined(separator: "\n")
}

fileprivate func preprocess(
  line: String, 
  index lineIndex: Int
) throws -> String {
  let installRegularExpression = ###"""
    ^\s*%install
    """###
  let installMatch = re.match(installRegularExpression, line)
  if installMatch != Python.None {
    var isValidDirective = false
    try processInstallDirective(
      line: line, lineIndex: lineIndex, isValidDirective: &isValidDirective)
    if isValidDirective {
      return ""
    } else {
      // This was not a valid %install-XXX command. Continue through regular 
      // processing and let the Swift parser throw an error.
    }
  }
  
  let systemRegularExpression = ###"""
    ^\s*%system (.*)$
    """###
  let systemMatch = re.match(systemRegularExpression, line)
  guard systemMatch == Python.None else {
    let restOfLine = String(systemMatch.group(1))!
    _ = try runTerminalProcess(args: [restOfLine])
    return ""
  }
  
  let includeRegularExpression = ###"""
    ^\s*%include (.*)$
    """###
  let includeMatch = re.match(includeRegularExpression, line)
  guard includeMatch == Python.None else {
    let restOfLine = String(includeMatch.group(1))!
    return try readInclude(restOfLine: restOfLine, lineIndex: lineIndex)
  }
  return line
}

fileprivate func readInclude(
  restOfLine: String,
  lineIndex: Int
) throws -> String {
  let parsed = try PackageContext.shlexSplit(restOfLine, lineIndex)
  if parsed.count != 1 {
    var sentence: String
    if parsed.count == 0 {
      sentence = "Please enter a path."
    } else {
      sentence = "Do not enter anything after the path."
      throw PreprocessorException(lineIndex: lineIndex, message: """
        Usage: %include PATH
        \(sentence) For more guidance, visit:
        https://github.com/philipturner/swift-colab/blob/main/Documentation/MagicCommands.md#include
        """)
    }
  }
  
  let name = parsed[0]
  let includePaths = ["/content", "/opt/swift/include"]
  var code: String? = nil
  var resolvedPath: String? = nil
  
  // Paths in "/content" should override paths in "/opt/swift/include". Stop
  // after finding the first file that matches.
  for includePath in includePaths {
    let path = includePath + "/" + name
    if let data = FileManager.default.contents(atPath: path) {
      code = String(data: data, encoding: .utf8)!
      resolvedPath = path
      break
    }
  }
  
  guard let code = code, 
        let resolvedPath = resolvedPath else {
    throw PreprocessorException(lineIndex: lineIndex, message:
      "File \"\(name)\" not found. Searched \(includePaths).")
  }
  return """
    #sourceLocation(file: "\(resolvedPath)", line: 1)
    \(code)
    \(getLocationDirective(lineIndex: lineIndex))
    
    """
}
