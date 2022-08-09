import Foundation

struct PackageContext {
  static func sendStdout(_ message: String, insertNewLine: Bool = true) {
    KernelContext.sendResponse("stream", [
      "name": "stdout",
      "text": "\(message)\(insertNewLine ? "\n" : "")"
    ])
  }
  
  static func shlexSplit(
    _ restOfLine: PythonConvertible, lineIndex: Int,
  ) throws -> [String] {
    let split = shlex[dynamicMember: "split"].throwing
    do {
      let output = try split.dynamicallyCall(withArguments: restOfLine)
      return [String](output)!
    } catch let error as PythonError {
      throw PreprocessorException(lineIndex: lineIndex, message: """
        Could not parse shell arguments: \(restOfLine)
        \(error)
        """)
    }
  }
  
  static func substituteCwd(
    _ template: String, lineIndex: Int
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
  
  static func handleTemplateError(
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
}