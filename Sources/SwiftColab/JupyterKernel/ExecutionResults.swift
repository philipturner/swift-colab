import Foundation
import PythonKit

protocol ExecutionResult {
    // Protocol for the result of executing code.
}

protocol ExecutionResultSuccess: ExecutionResult {
    // Protocol for the result of successfully executing code.
}

protocol ExecutionResultError: ExecutionResult {
    // Protocol for the result of unsuccessfully executing code.
}
