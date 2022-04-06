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

/// There was an error preprocessing the code.
struct PreprocessorError: ExecutionResultError {
  var exception: PreprocessorException

  var description: String {
    String(describing: exception)
  }
}

/// There was a compile or runtime error.
struct SwiftError: ExecutionResultError {
  var description: String
}

struct Exception: LocalizedError {
  var errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

struct PreprocessorException: LocalizedError {
  var errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

struct PackageInstallException: LocalizedError {
  var errorDescription: String?
  init(_ message: String) { errorDescription = message }
}
