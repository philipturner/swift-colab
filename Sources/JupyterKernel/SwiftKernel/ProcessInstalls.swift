import Foundation
fileprivate let json = Python.import("json")
fileprivate let os = Python.import("os")
fileprivate let re = Python.import("re")
fileprivate let sqlite3 = Python.import("sqlite3")
fileprivate let string = Python.import("string")
fileprivate let subprocess = Python.import("subprocess")

func processInstallDirective(
  line: String, lineIndex: Int, isValidDirective: inout Bool
) throws {
  func attempt(
    command: (String, String, Int) throws -> Void, _ regex: String
  ) rethrows {
    let regexMatch = re.match(regex, line)
    if regexMatch != Python.None {
      let restOfLine = String(regexMatch.group(1))!
      try command(line, restOfLine, lineIndex)
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

fileprivate func sendStdout(_ message: String, insertNewLine: Bool = true) {
  KernelContext.sendResponse("stream", [
    "name": "stdout",
    "text": "\(message)\(insertNewLine ? "\n" : "")"
  ])
}

// %install-swiftpm-flags

fileprivate var swiftPMFlags: [String] = []

// Allow passing empty whitespace as the flags because it's valid to run:
// swift         build
fileprivate func processSwiftPMFlags(
  line: String, restOfLine: String, lineIndex: Int
) throws {
  // Nobody is going to type this literal into their Colab notebook.
  let id = "$SWIFT_COLAB_sHcpmxAcqC7eHlgD"
  var processedLine: String
  do {
    processedLine = String(try string.Template(restOfLine).substitute.throwing
      .dynamicallyCall(withArguments: [
        "clear": id
      ])
    )!
  } catch {
    throw handleTemplateError(error, lineIndex: lineIndex)
  }
  
  // Ensure that only everything after the last "$clear" flag passes into shlex.
  let reversedID = String(id.reversed())
  let reversedLine = String(processedLine.reversed())
  if let idRange = reversedLine.range(of: reversedID) {
    let endRange = reversedLine.startIndex..<idRange.lowerBound
    processedLine = String(reversedLine[endRange].reversed())
    swiftPMFlags = []
  }
  
  swiftPMFlags += try shlexSplit(lineIndex: lineIndex, line: processedLine)
}

fileprivate func handleTemplateError(
  _ anyError: Error, lineIndex: Int
) -> Error {
  guard let pythonError = anyError as? PythonError else {
    return anyError
  }
  switch pythonError {
  case .exception(let error, _):
    return PreprocessorException(lineIndex: lineIndex, message:
      "Invalid template argument \(error)")
  default:
    return pythonError
  }
}

// %install-extra-include-command

// Allow passing empty whitespace as the command because that's valid Bash.
fileprivate func processExtraIncludeCommand(
  line: String, restOfLine: String, lineIndex: Int
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
  
  // Cache column locations to avoid computing multiple times. These are
  // 1-indexed, matching what LLDB would show.
  var startColumn: Int?
  var endColumn: Int?
  
  let preprocessed = result.stdout.decode("utf8")
  let includeDirs = try shlexSplit(lineIndex: lineIndex, line: preprocessed)
  for includeDir in includeDirs {
    // TODO: Make a validation test for text colorization, using abnormal 
    // whitespace configurations. The third command below should end with two
    // extra spaces.
    //
    // %install-extra-include-command echo -I/usr/include/glib-2.0
    // %install-extra-include-command pkg-config --cflags-only-I glib-2.0
    //   %install-extra-include-command  echo  "hello world c"
    if includeDir.prefix(2) != "-I" {
      let magicCommand = "%install-extra-include-command"
      if startColumn == nil {
        precondition(endColumn == nil, "This should never happen.")

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
      } else {
        precondition(endColumn != nil, "This should never happen.")
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
      sendStdout(
        formatString(file, ansiOptions: [1]) +
        formatString(warning, ansiOptions: [1, 35]) +
        formatString(message, ansiOptions: [1]) + "\n" +
        line + "\n" +
        spaces + formatString(marker, ansiOptions: [1, 32]))
      continue
    }
    swiftPMFlags.append(includeDir)
  }
}

// %install-location

// TODO: Validate that debugger finds correct modules after changing install
// location during notebook execution.
fileprivate func processInstallLocation(
  line: String, restOfLine: String, lineIndex: Int
) throws {
  // TODO: Make validation test for %install-location.
  let parsed = try shlexSplit(lineIndex: lineIndex, line: restOfLine)
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
  KernelContext.installLocation = try substituteCwd(
    template: restOfLine, lineIndex: lineIndex)
}

fileprivate func substituteCwd(
  template: String, lineIndex: Int
) throws -> String {
  do {
    let output = try string.Template(template).substitute.throwing
      .dynamicallyCall(withArguments: [
        "cwd": FileManager.default.currentDirectoryPath
      ])
    return String(output)!
  } catch {
    throw handleTemplateError(error, lineIndex: lineIndex)
  }
}

// %install

fileprivate var installedPackages: [String]! = nil
fileprivate var installedPackagesLocation: String! = nil
// To prevent the search for matching packages from becoming O(n^2).
fileprivate var installedPackagesMap: [String: Int]! = nil

fileprivate func readInstalledPackages() throws {
  installedPackages = []
  installedPackagesLocation = "\(KernelContext.installLocation)/index"
  installedPackagesMap = [:]
  
  if let packagesData = FileManager.default.contents(
     atPath: installedPackagesLocation) {
    let packagesString = String(data: packagesData, encoding: .utf8)!
    let lines = packagesString.split(separator: "\n").map(String.init)
    
    for i in 0..<lines.count {
      let spec = lines[i]
      installedPackages.append(spec)
      installedPackagesMap[spec] = i
    }
  }
}

fileprivate func writeInstalledPackages(lineIndex: Int) throws {
  let packagesString = installedPackages.reduce("") {
    $0 + $1 + "\n"
  }
  let packagesData = packagesString.data(using: .utf8)!
  
  guard FileManager.default.createFile(
        atPath: installedPackagesLocation, contents: packagesData) else {
    throw PackageInstallException(lineIndex: lineIndex, message: """
      Could not write to file "\(installedPackagesLocation!)"
      """)
  }
}

fileprivate var loadedClangModules: Set<String>!

fileprivate func readClangModules() {
  loadedClangModules = []
  let fm = FileManager.default
  
  let moduleSearchPath = "\(KernelContext.installLocation)/modules"
  let items = try! fm.contentsOfDirectory(atPath: moduleSearchPath)
  for item in items {
    guard item.hasPrefix("module-") else {
      continue
    }
    
    let itemFolder = "\(moduleSearchPath)/\(item)"
    let files = try? fm.contentsOfDirectory(atPath: itemFolder)
    if let files = files, files.contains("module.modulemap") {
      var moduleName = item
      moduleName.removeFirst("module-".count)
      loadedClangModules.insert(moduleName)
    }
  }
}

//===----------------------------------------------------------------------===//
// Compile Swift Packages
//===----------------------------------------------------------------------===//

fileprivate func processInstall(
  line: String, restOfLine: String, lineIndex: Int
) throws {
  let parsed = try shlexSplit(lineIndex: lineIndex, line: restOfLine)
  if parsed.count < 2 {
    var sentence: String
    if parsed.count == 0 {
      sentence = "Please enter a specification."
    } else {
      sentence = "Please specify one or more products."
    }
    throw PreprocessorException(lineIndex: lineIndex, message: """
      Usage: %install SPEC PRODUCT [PRODUCT ...]
      \(sentence) For more guidance, visit:
      https://github.com/philipturner/swift-colab/blob/main/Documentation/MagicCommands.md#install
      """)
  }

  KernelContext.log("checkpoint 1")
  
  // Expand template before writing to file.
  let spec = try substituteCwd(template: parsed[0], lineIndex: lineIndex)
  let products = Array(parsed[1...])

  KernelContext.log("checkpoint 2")

  // Ensure install location exists
  let fm = FileManager.default
  do {
    try fm.createDirectory(
      atPath: KernelContext.installLocation, withIntermediateDirectories: true)
  } catch {
    throw PackageInstallException(lineIndex: lineIndex, message: """
      Could not create directory "\(KernelContext.installLocation)". \
      Encountered error: \(error.localizedDescription)
      """)
  }

  KernelContext.log("checkpoint 3")
  
  let linkPath = "/opt/swift/install-location"
  try? fm.removeItem(atPath: linkPath)
  try fm.createSymbolicLink(
    atPath: linkPath, withDestinationPath: KernelContext.installLocation)
  
  KernelContext.log("checkpoint 4")
  
  if installedPackages == nil || 
     installedPackagesLocation != KernelContext.installLocation {
    try readInstalledPackages()
  }

  KernelContext.log("checkpoint 5")
  
  var packageID: Int
  if let index = installedPackagesMap[spec] {
    packageID = index
  } else {
    packageID = installedPackages.count
    installedPackages.append(spec)
    installedPackagesMap[spec] = packageID
  }
  try writeInstalledPackages(lineIndex: lineIndex)
  
  KernelContext.log("checkpoint 6")
  
  // Summary of how this works:
  // - create a Swift package that depends all the modules that
  //   the user requested
  // - ask SwiftPM to build that package
  // - copy all the .swiftmodule and module.modulemap files that SwiftPM
  //   created to the Swift module search path
  // - dlopen the .so file that SwiftPM created
  
  // Create the Swift package.
  
  let packageName = "jupyterInstalledPackages\(packageID + 1)"
  let packageNameQuoted = "\"\(packageName)\""
  
  let /*communist*/ manifest/*o*/ = """
    // swift-tools-version:4.2
    import PackageDescription
    let package = Package(
      name: \(packageNameQuoted),
      products: [
        .library(
          name: \(packageNameQuoted),
          type: .dynamic,
          targets: [\(packageNameQuoted)]
        )
      ],
      dependencies: [
        \(spec)
      ],
      targets: [
        .target(
          name: \(packageNameQuoted),
          dependencies: \(products),
          path: ".",
          sources: ["\(packageName).swift"]
        )
      ]
    )
    """
  
  let eightSpaces = String(repeating: Character(" "), count: 8)
  var modulesHumanDescription = products.reduce("") {
    $0 + eightSpaces + $1 + "\n"
  }
  modulesHumanDescription.removeLast()
  
  func makeBlue(_ label: String) -> String {
    return formatString(label, ansiOptions: [36])
  }
  sendStdout("""
    \(makeBlue("Installing package:"))
        \(spec)
    \(modulesHumanDescription)
    \(makeBlue("With SwiftPM flags: "))\(swiftPMFlags)
    \(makeBlue("Working in: "))\(KernelContext.installLocation)
    """)
  
  let packagePath = "\(KernelContext.installLocation)/\(packageID + 1)"
  try? fm.createDirectory(
    atPath: packagePath, withIntermediateDirectories: false)
  
  func createFile(name: String, contents: String) throws {
    let filePath = "\(packagePath)/\(name)"
    let data = contents.data(using: .utf8)!
    
    // If you overwrite the contents of "\(packageName).swift", regardless of 
    // whether you actually change it, you will trigger a massive JSON blob in 
    // stdout if the package has been built before. So, don't overwrite it.
    if data == fm.contents(atPath: filePath) {
      return
    }
    guard fm.createFile(atPath: filePath, contents: data) else {
      throw PackageInstallException(lineIndex: lineIndex, message: """
        Could not write to file "\(filePath)".
        """)
    }
  }
  
  try createFile(name: "Package.swift", contents: manifest)
  try createFile(name: "\(packageName).swift", contents: """
    // intentionally blank
    
    """)
  
  // Ask SwiftPM to build the package.
  let swiftBuildPath = "/opt/swift/toolchain/usr/bin/swift-build"
  let buildReturnCode = try runTerminalProcess(
    args: [swiftBuildPath] + swiftPMFlags, cwd: packagePath)
  if buildReturnCode != 0 {
    throw PackageInstallException(lineIndex: lineIndex, message: """
      swift-build returned nonzero exit code \(buildReturnCode).
      """)
  }
  
  let showBinPathResult = subprocess.run(
    [swiftBuildPath, "--show-bin-path"] + swiftPMFlags,
    stdout: subprocess.PIPE,
    stderr: subprocess.PIPE,
    cwd: packagePath)
  let binDirSrc = String(showBinPathResult.stdout.decode("utf8").strip())!
  let binDirLines = binDirSrc.split(
    separator: "\n", omittingEmptySubsequences: false)
  
  // `binDirLines` will always have at least one element. If `binDirSrc` is
  // blank, `binDirLines` is [""] because the call to `String.split` permits
  // empty subsequences.
  let binDir = binDirLines.last!
  let libPath = "\(binDir)/lib\(packageName).so"
  
  // Copy .swiftmodule and modulemap files to Swift module search path.
  let moduleSearchPath = "\(KernelContext.installLocation)/modules"
  try? fm.createDirectory(
    atPath: moduleSearchPath, withIntermediateDirectories: false)
  if loadedClangModules == nil {
    readClangModules()
  }
  
  let buildDBPath = "\(binDir)/../build.db"
  guard fm.fileExists(atPath: buildDBPath) else {
    throw PackageInstallException(lineIndex: lineIndex, message: 
      "build.db is missing.")
  }
  
  // Execute swift-package show-dependencies to get all dependencies' paths.
  let swiftPackagePath = "/opt/swift/toolchain/usr/bin/swift-package"
  let dependenciesResult = subprocess.run(
    [swiftPackagePath, "show-dependencies", "--format", "json"],
    stdout: subprocess.PIPE,
    stderr: subprocess.PIPE,
    cwd: packagePath)
  let dependenciesJSON = dependenciesResult.stdout.decode("utf8")
  let dependenciesObj = json.loads(dependenciesJSON)
  
  func flattenDepsPaths(_ dep: PythonObject) -> [PythonObject] {
    var paths = [dep["path"]]
    if let dependencies = dep.checking["dependencies"] {
      for d in dependencies {
        paths += flattenDepsPaths(d)
      }
    }
    return paths
  }
  
  // Make list of paths where we expect .swiftmodule and .modulemap files of 
  // dependencies.
  let dependenciesSet = Python.set(flattenDepsPaths(dependenciesObj))
  let dependenciesPaths = [String](Python.list(dependenciesSet))!
  
  func isValidDependency(_ path: String) -> Bool {
    for p in dependenciesPaths {
      if path.hasPrefix(p) {
        return true
      }
    }
    return false
  }
  
  // Query to get build files list from build.db.
  // SUBSTR because string starts with "N" (why?)
  let SQL_FILES_SELECT = 
    "SELECT SUBSTR(key, 2) FROM 'key_names' WHERE key LIKE ?"
  
  // Connect to build.db.
  let dbConnection = sqlite3.connect(buildDBPath)
  let cursor = dbConnection.cursor()
  
  // Process *.swiftmodule files.
  cursor.execute(SQL_FILES_SELECT, ["%.swiftmodule"])
  let swiftModules = cursor.fetchall().map { row in String(row[0])! }
    .filter(isValidDependency)
  for path in swiftModules {
    let fileName = URL(fileURLWithPath: path).lastPathComponent
    let linkPath = "\(moduleSearchPath)/\(fileName)"
    try? fm.removeItem(atPath: linkPath)
    do {
      try fm.createSymbolicLink(
        atPath: linkPath, withDestinationPath: path)
    } catch {
      throw PackageInstallException(lineIndex: lineIndex, message: """
        Could not create link "\(linkPath)" with destination "\(path)".
        """)
    }
  }
  
  var warningClangModules: Set<String> = []
  
  // Process modulemap files.
  cursor.execute(SQL_FILES_SELECT, ["%/module.modulemap"])
  let modulemapPaths = cursor.fetchall().map { row in String(row[0])! }
    .filter(isValidDependency)
  for index in 0..<modulemapPaths.count {
    // Create a separate directory for each modulemap file because the
    // ClangImporter requires that they are all named "module.modulemap".
    //
    // Use the module name to prevent two modulemaps for the same dependency
    // from ending up in multiple directories after several installations, 
    // causing the kernel to end up in a bad state. Make all relative header
    // paths in module.modulemap absolute because we copy file to different 
    // location.
    let filePath = modulemapPaths[index]
    var fileURL = URL(fileURLWithPath: filePath)
    fileURL.deleteLastPathComponent()
    let srcFolder = fileURL.path
    
    var modulemapContents = 
      String(data: fm.contents(atPath: filePath)!, encoding: .utf8)!
    let lambda = PythonFunction { (m: PythonObject) in
      let relativePath = m.group(1)
      var absolutePath: PythonObject
      if Bool(os.path.isabs(relativePath))! {
        absolutePath = relativePath
      } else {
        absolutePath = os.path.abspath(
          srcFolder + "/" + String(relativePath)!)
      }
      return """
        header "\(absolutePath)"
        """
    }
    let headerRegularExpression = ###"""
      header\s+"(.*?)"
      """###
    modulemapContents = String(re.sub(
      headerRegularExpression, lambda, modulemapContents))!
    
    let moduleRegularExpression = ###"""
      module\s+([^\s]+)\s.*{
      """###
    let moduleMatch = re.match(moduleRegularExpression, modulemapContents)
    var moduleFolderName: String
    if moduleMatch != Python.None {
      let moduleName = String(moduleMatch.group(1))!
      moduleFolderName = "module-\(moduleName)"
      if !loadedClangModules.contains(moduleName) {
        warningClangModules.insert(moduleName)
      }
    } else {
      moduleFolderName = "modulenoname-\(packageID + 1)-\(index + 1)"
    }
    
    let newFolderPath = "\(moduleSearchPath)/\(moduleFolderName)"
    try? fm.createDirectory(
      atPath: newFolderPath, withIntermediateDirectories: false)
    
    let newFilePath = "\(newFolderPath)/module.modulemap"
    let modulemapData = modulemapContents.data(using: .utf8)!
    guard fm.createFile(atPath: newFilePath, contents: modulemapData) else {
      throw PackageInstallException(lineIndex: lineIndex, message: """
        Could not write to file "\(newFilePath)".
        """)
    }
  }
  
  if !warningClangModules.isEmpty {
    sendStdout("""
      === ------------------------------------------------------------------------ ===
      === The following Clang modules cannot be imported in your source code until ===
      === you restart the runtime. If you do not intend to explicitly import       ===
      === modules listed here, ignore this warning.                                ===
      === \(warningClangModules)
      === ------------------------------------------------------------------------ ===
      """)
  }
  
  // dlopen the shared lib.
  let dynamicLoadResult = execute(code: """
    import func Glibc.dlopen
    import var Glibc.RTLD_NOW
    dlopen("\(libPath)", RTLD_NOW)
    """)
  guard let dynamicLoadResult = dynamicLoadResult as? SuccessWithValue else {
    throw PackageInstallException(lineIndex: lineIndex, message: """
      dlopen crashed: \(dynamicLoadResult)
      """)
  }

  if dynamicLoadResult.description.hasSuffix("nil") {
    let error = execute(code: "String(cString: dlerror())")
    throw PackageInstallException(lineIndex: lineIndex, message: """
      dlopen returned `nil`: \(error)
      """)
  }
}

//===----------------------------------------------------------------------===//
// Test Swift Packages
//===----------------------------------------------------------------------===//

// Used in "PreprocessAndExecute.swift".
func processTest(
  line: String, restOfLine: String, lineIndex: Int
) throws {
  let parsed = try shlexSplit(lineIndex: lineIndex, line: restOfLine)
  if parsed.count != 1 {
    var sentence: String
    if parsed.count == 0 {
      sentence = "Please enter a specification."
    } else {
      sentence = "Do not enter anything after the specification."
    }
    throw PreprocessorException(lineIndex: lineIndex, message: """
      Usage: %test SPEC
      \(sentence) For more guidance, visit:
      https://github.com/philipturner/swift-colab/blob/main/Documentation/MagicCommands.md#test
      """)
  }
}