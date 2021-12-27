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

struct NotImplementedError: LocalizedError {
    let errorDescription: String?
    
    init(file: String = #file, line: String = #line, function: String = #function) {
        errorDescription = "Something was not implemented in Swift file: \(file), line: \(line), function: \(function)"
    }
}

extension ExecutionResultError {
    func description() throws {
        throw NotImplementedError()
    }
}
