import Foundation
fileprivate let re = Python.import("re")
fileprivate let string = Python.import("string")

func processInstallDirective(
  line: String, lineIndex: Int, isValidDirective: inout Bool
) throws {
  func attempt(
    command: (String, Int) throws -> Void, _ regex: String
  ) rethrows {
    let regexMatch = re.match(regex, line)
    if regexMatch != Python.None {
      let restOfLine = String(regexMatch.group(1))!
      try command(restOfLine, lineIndex)
      isValidDirective = true
    }
  }
  
  try attempt(command: processInstall, ###"""
    ^\s*%install (.*)$
    """###)
  if isValidDirective { return }
  
  try attempt(command: processSwiftPMFlags, ###"""
    ^\s*%install-swiftpm-flags (.*)$
    """###)
  if isValidDirective { return }
  
  try attempt(command: processExtraIncludeCommand, ###"""
    ^\s*%install-extra-include-command (.*)$
    """###)
  if isValidDirective { return }
  
  try attempt(command: processInstallLocation, ###"""
    ^\s*%install-location (.*)$
    """###)
  if isValidDirective { return }
}

// %install-swiftpm-flags

// Nobody will type this literal into their Colab notebook.
fileprivate let id = "$SWIFT_COLAB_sHcpmxAcqC7eHlgD"
fileprivate let reversedID = String(id.reversed())

// Permit passing empty whitespace because this is valid:
// swift <arbitrary whitespace> build
fileprivate func processSwiftPMFlags(
  restOfLine: String, lineIndex: Int
) throws {
  var processedLine: String
  do {
    processedLine = String(try string.Template(restOfLine).substitute.throwing
      .dynamicallyCall(withArguments: [
        "clear": id
      ])
    )!
  } catch {
    throw PackageContext.handleTemplateError(error, lineIndex)
  }
  
  // Ensure that only everything after the last "$clear" flag passes into shlex.
  let reversedLine = String(processedLine.reversed())
  if let idRange = reversedLine.range(of: reversedID) {
    let endRange = reversedLine.startIndex..<idRange.lowerBound
    processedLine = String(reversedLine[endRange].reversed())
    PackageContext.swiftPMFlags = []
  }
  let flags = try PackageContext.shlexSplit(processedLine, lineIndex)
  PackageContext.swiftPMFlags += flags
}

// %install-extra-include-command

// Allow passing empty whitespace as the command because that's valid Bash.
fileprivate func processExtraIncludeCommand(
  restOfLine: String, lineIndex: Int
) throws {
  let result = subprocess.run(
    restOfLine,
    stdout: subprocess.PIPE,
    stderr: subprocess.PIPE,
    shell: true)
  if result.returncode != 0 {
    throw PreprocessorException(lineIndex: lineIndex, message: """
      %install-extra-include-command returned nonzero exit code: \(result.returncode)
      stdout: \(result.stdout.decode("utf8"))
      stderr: \(result.stderr.decode("utf8"))
      """)
  }

  // Regex eliminates only the middle space, so `restOfLine` could start with
  // spaces.
  let magicCommand = "%install-extra-include-command"
  let line = magicCommand + " " + restOfLine
  
  // Cache column locations to avoid computing multiple times. These are
  // 1-indexed, matching what LLDB would show.
  var startColumn: Int?
  var endColumn: Int?
  
  let preprocessed = result.stdout.decode("utf8")
  let includeDirs = try PackageContext.shlexSplit(preprocessed, lineIndex)
  for includeDir in includeDirs {
    // TODO: Make a validation test for text colorization, using abnormal 
    // whitespace configurations. The third command below should end with two
    // extra spaces.
    //
    // %install-extra-include-command echo -I/usr/include/glib-2.0
    // %install-extra-include-command pkg-config --cflags-only-I glib-2.0
    //   %install-extra-include-command  echo  "hello world c"
    if includeDir.prefix(2) != "-I" {
      
      if startColumn == nil {
        // Magic command might be prepended by spaces, so find index of "%".
        var index = line.firstIndex(of: "%")!
        index = line.index(index, offsetBy: magicCommand.count)
        
        // Something besides whitespace must exist, otherwise there would be no 
        // output.
        while line[index].isWhitespace {
          index = line.index(after: index)
        }
        startColumn = 1 + line.distance(from: line.startIndex, to: index)
        
        // Column after last column that isn't whitespace.
        index = line.lastIndex(where: { $0.isWhitespace == false })!
        endColumn = 1 + line.distance(from: line.startIndex, to: index) + 1
      }
      
      // `file` and `warning` contain the ": " that comes after them.
      let row = lineIndex + 1
      let file = "<Cell \(KernelContext.cellID)>:\(row):\(startColumn!): "
      let warning = "warning: "
      let message = "non-'-I' output from \(magicCommand): '\(includeDir)'"
      
      // Ensure correct characters are highlighted.
      let numSpaces = startColumn! - 1
      let numTildes = endColumn! - startColumn!
      let spaces = String(repeating: Character(" "), count: numSpaces)
      let marker = String(repeating: Character("~"), count: numTildes)
      PackageContext.sendStdout(
        formatString(file, ansiOptions: [1]) +
        formatString(warning, ansiOptions: [1, 35]) +
        formatString(message, ansiOptions: [1]) + "\n" +
        line + "\n" +
        spaces + formatString(marker, ansiOptions: [1, 32]))
      continue
    }
    PackageContext.swiftPMFlags.append(includeDir)
  }
}

// %install-location

fileprivate func processInstallLocation(
  restOfLine: String, lineIndex: Int
) throws {
  let parsed = try PackageContext.shlexSplit(restOfLine, lineIndex)
  if parsed.count != 1 {
    var sentence: String
    if parsed.count == 0 {
      sentence = "Please enter a path."
    } else {
      sentence = "Do not enter anything after the path."
    }
    throw PreprocessorException(lineIndex: lineIndex, message: """
      Usage: %install-location PATH
      \(sentence) For more guidance, visit:
      https://github.com/philipturner/swift-colab/blob/main/Documentation/MagicCommands.md#install-location
      """)
  }
  let path = try PackageContext.substituteCwd(parsed[0], lineIndex)
  PackageContext.installLocation = path
}
