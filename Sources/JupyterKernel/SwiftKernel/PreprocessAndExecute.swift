import Foundation
fileprivate let re = Python.import("re")
fileprivate let subprocess = Python.import("subprocess")

func preprocessAndExecute(code: String, isCell: Bool = false) throws -> ExecutionResult {
  do {
    let preprocessed = try preprocess(code: code)
    return execute(code: preprocessed, lineIndex: isCell ? 0 : nil)
  } catch let e as PreprocessorException {
    return PreprocessorError(exception: e)
  }
}

func execute(code: String, lineIndex: Int? = nil) -> ExecutionResult {
  var locationDirective: String
  if let lineIndex = lineIndex {
    locationDirective = getLocationDirective(lineIndex: lineIndex)
  } else {
    locationDirective = """
    #sourceLocation(file: "n/a", line: 1)
    """
  }
  let codeWithLocationDirective = locationDirective + "\n" + code
  
  var descriptionPtr: UnsafeMutablePointer<CChar>?
  let error = KernelContext.execute(codeWithLocationDirective, &descriptionPtr)
  
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
fileprivate func getLocationDirective(lineIndex: Int) -> String {
  let executionCount = Int(KernelContext.kernel.execution_count)!
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
      // This was not a valid %install-XXX command. Continue through
      // regular processing and let the Swift parser throw an error.
    }
  }
  
  let systemRegularExpression = ###"""
  ^\s*%system (.*)$
  """###
  let systemMatch = re.match(systemRegularExpression, line)
  guard systemMatch == Python.None else {
    let restOfLine = String(systemMatch.group(1))!
    executeSystemCommand(restOfLine: restOfLine)
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

fileprivate func executeSystemCommand(restOfLine: String) {
  let process = subprocess.Popen(
    restOfLine,
    stdout: subprocess.PIPE,
    stderr: subprocess.STDOUT,
    shell: true)
  process.wait()
    
  let commandResult = process.stdout.read().decode("utf-8")
  let kernel = KernelContext.kernel
  kernel.send_response(kernel.iopub_socket, "stream", [
    "name": "stdout",
    "text": commandResult
  ])
}

fileprivate var previouslyReadPaths: Set<String> = []

fileprivate func readInclude(restOfLine: String, lineIndex: Int) throws -> String {
  let nameRegularExpression = ###"""
  ^\s*"([^"]+)"\s*$
  """###
  let nameMatch = re.match(nameRegularExpression, restOfLine)
  guard nameMatch != Python.None else {
    throw PreprocessorException(
            "Line \(lineIndex + 1): %include must be followed by a name in quotes")
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
    throw PreprocessorException(
        "Line \(lineIndex + 1): Could not find \"\(name)\". Searched \(includePaths.reversed()).")
  }
  previouslyReadPaths.insert(chosenPath)
  return """
  #sourceLocation(file: "\(chosenPath)", line: 1)
  \(code)
  \(getLocationDirective(lineIndex: lineIndex))
  
  """
}
