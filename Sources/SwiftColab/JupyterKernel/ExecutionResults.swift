import Foundation
import PythonKit

/// Protocol for the result of executing code.
protocol ExecutionResult: CustomDebugStringConvertible { }

/// Protocol for the result of successfully executing code.
protocol ExecutionResultSuccess: ExecutionResult { }

/// Protocol for the result of unsuccessfully executing code.
protocol ExecutionResultError: ExecutionResult { }

/// The code executed successfully, and did not produce a value.
struct SuccessWithoutValue: ExecutionResultSuccess {
    
}
