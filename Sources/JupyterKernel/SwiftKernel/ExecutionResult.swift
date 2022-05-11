import Foundation

/// Protocol for the result of executing code.
protocol ExecutionResult: CustomStringConvertible { 
  var description: String { get }
}

/// Protocol for the result of successfully executing code.
protocol ExecutionResultSuccess: ExecutionResult {}

/// Protocol for the result of unsuccessfully executing code.
protocol ExecutionResultError: ExecutionResult {}

/// The code executed successfully, and did not produce a value.
struct SuccessWithoutValue: ExecutionResultSuccess {
  var description: String { "" }
}

/// The code executed successfully, and produced a value.
struct SuccessWithValue: ExecutionResultSuccess {
  var description: String
}

/// There was a compile or runtime error.
struct SwiftError: ExecutionResultError {
  var description: String
}

protocol PreprocessorError: LocalizedError {
  static var label: String { get }
  var line: Int?
}

struct ParseException: LocalizedError {
  static let label = "Parse error"
  var errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

struct PackageInstallException: LocalizedError {
  static let label = "Package install error"
  var errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

// Miscellaneous

struct Exception: LocalizedError {
  var errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

struct InterruptException: LocalizedError {
  var errorDescription: String?
  init(_ message: String) { errorDescription = message }
}
