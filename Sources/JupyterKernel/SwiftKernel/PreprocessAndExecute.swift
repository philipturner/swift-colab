import Foundation
fileprivate let re = Python.import("re")
fileprivate let time = Python.import("time")

func preprocessAndExecute(
  code: String, isCell: Bool = false
) throws -> ExecutionResult {
  let preprocessed = try preprocess(code: code)
  var executionResult: ExecutionResult?
  // Need to avoid accessing Python from the background thread.
  let executionCount = Int(KernelContext.kernel.execution_count)!

  DispatchQueue.global().async {
    executionResult = execute(
      code: preprocessed, lineIndex: isCell ? 0 : nil, isCell: isCell,
      executionCount: executionCount)
  }

  while executionResult == nil {
    // Using Python's `time` module instead of Foundation.usleep releases the
    // GIL.
    time.sleep(0.05)
  }
  return executionResult!
}

func execute(
  code: String, lineIndex: Int? = nil, isCell: Bool = false,
  executionCount: Int = Int(KernelContext.kernel.execution_count)!
) -> ExecutionResult {
  // Send a header to stdout, letting the StdoutHandler know that it compiled 
  // without errors and executed in LLDB.
  var prefixCode = isCell ? "print(\"HEADER\")\n" : ""
  
  if let lineIndex = lineIndex {
    prefixCode += getLocationDirective(
      lineIndex: lineIndex, executionCount: executionCount)
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
  } else {
    return SwiftError(description: description!)
  }
}

// Location directive for the current cell
//
// This adds one to `lineIndex` before creating the string.
// This does not include the newline that should come after the directive.
fileprivate func getLocationDirective(
  lineIndex: Int, 
  executionCount: Int = Int(KernelContext.kernel.execution_count)!
) -> String {
  return """
    #sourceLocation(file: "<Cell \(executionCount)>", line: \(lineIndex + 1))
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

fileprivate func preprocess(line: String, index lineIndex: Int) throws -> String {
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

fileprivate var previouslyReadPaths: Set<String> = []

fileprivate func readInclude(restOfLine: String, lineIndex: Int) throws -> String {
  let nameRegularExpression = ###"""
    ^\s*"([^"]+)"\s*$
    """###
  let nameMatch = re.match(nameRegularExpression, restOfLine)
  guard nameMatch != Python.None else {
    throw PreprocessorException(lineIndex: lineIndex, message:
      "%include must be followed by a name in quotes")
  }
  
  let name = String(nameMatch.group(1))!
  let includePaths = ["/opt/swift/include", "/content"]
  var code: String? = nil
  var chosenPath: String? = nil
  var rejectedAPath = false
  
  // Paths in "/content" should override paths in "/opt/swift/include".
  // Paths later in the list `includePaths` have higher priority.
  for includePath in includePaths {
    let path = includePath + "/" + name
    if previouslyReadPaths.contains(path) { 
        rejectedAPath = true
        continue 
    }
    if let data = FileManager.default.contents(atPath: path) {
      code = String(data: data, encoding: .utf8)!
      chosenPath = path
    }
  }
  
  guard let code = code, 
        let chosenPath = chosenPath else {
    if rejectedAPath {
      return ""
    }
    
    // Reversing `includePaths` to show the highest-priority one first.
    throw PreprocessorException(lineIndex: lineIndex, message:
      "Could not find \"\(name)\". Searched \(includePaths.reversed()).")
  }
  previouslyReadPaths.insert(chosenPath)
  return """
    #sourceLocation(file: "\(chosenPath)", line: 1)
    \(code)
    \(getLocationDirective(lineIndex: lineIndex))
    
    """
}
