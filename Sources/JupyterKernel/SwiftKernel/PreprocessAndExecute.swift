import Foundation
fileprivate let re = Python.import("re")
fileprivate let time = Python.import("time")

func preprocessAndExecute(
  code: String, isCell: Bool = false
) throws -> ExecutionResult {
  let preprocessed = try preprocess(code: code)
  var executionResult: ExecutionResult?
  
  DispatchQueue.global().async {
    let _executionResult = execute(
      code: preprocessed, lineIndex: isCell ? 0 : nil, isCell: isCell)
    _ = KernelContext.mutex.acquire()
    executionResult = _executionResult
    _ = KernelContext.mutex.release()
  }
  
  while true {
    // Using Python's `time` module instead of Foundation.usleep releases the
    // GIL. If we don't periodically release the GIL, output looks choppy.
    time.sleep(0.05)
    
    _ = KernelContext.mutex.acquire()
    let shouldBreak = executionResult != nil
    _ = KernelContext.mutex.release()
    
    // TODO: Pipe all messages directly through Stdout, see whether this
    // improves waiting performance.
    if isCell {
      getAndSendStdout()
    }
    if shouldBreak {
      return executionResult!
    }
  }
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
  KernelContext.log("--0")
  let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
    .map(String.init)
  KernelContext.log("1")
  let preprocessedLines = try lines.indices.map { i -> String in
    KernelContext.log("Testing line \(i): 0")
    let line = lines[i]
    KernelContext.log("Testing line \(i): 1")
    guard line.contains("%") else {
      KernelContext.log("Testing line \(i): 2")
      return line
    }
    KernelContext.log("Testing line \(i): 3")
    return try preprocess(line: line, index: i)
  }
  KernelContext.log("2")
  return preprocessedLines.joined(separator: "\n")
}

fileprivate func preprocess(
  line: String, 
  index lineIndex: Int
) throws -> String {
  KernelContext.log("---0ni")
  print(try? Python.attemptImport("numpy") as Any)
  let installRegularExpression = ###"""
    ^\s*%install
    """###
  KernelContext.log("---0vi")
  let installMatch = re.match(installRegularExpression, line)
  KernelContext.log("---0q")
  if installMatch != Python.None {
    KernelContext.log("1")
    var isValidDirective = false
    try processInstallDirective(
      line: line, lineIndex: lineIndex, isValidDirective: &isValidDirective)
    KernelContext.log("2")
    if isValidDirective {
      KernelContext.log("2.1")
      return ""
    } else {
      KernelContext.log("2.2")
      // This was not a valid %install-XXX command. Continue through regular 
      // processing and let the Swift parser throw an error.
    }
  }
  KernelContext.log("3")
  
  let systemRegularExpression = ###"""
    ^\s*%system (.*)$
    """###
  let systemMatch = re.match(systemRegularExpression, line)
  guard systemMatch == Python.None else {
    KernelContext.log("4")
    let restOfLine = String(systemMatch.group(1))!
    KernelContext.log("5")
    _ = try runTerminalProcess(args: [restOfLine])
    KernelContext.log("5.1")
    return ""
  }

  KernelContext.log("6")
  
  let includeRegularExpression = ###"""
    ^\s*%include (.*)$
    """###
  let includeMatch = re.match(includeRegularExpression, line)
  guard includeMatch == Python.None else {
    KernelContext.log("7")
    let restOfLine = String(includeMatch.group(1))!
    KernelContext.log("8")
    return try readInclude(restOfLine: restOfLine, lineIndex: lineIndex)
  }
  KernelContext.log("9")
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
