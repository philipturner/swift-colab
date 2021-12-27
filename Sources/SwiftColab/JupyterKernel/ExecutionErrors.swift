import Foundation
import PythonKit

struct NotImplementedError: LocalizedError {
    let errorDescription: String?
    
    init(file: String = #file, line: String = #line, function: String = #function) {
        errorDescription = "Something was not implemented in Swift file: \(file), line: \(line), function: \(function)"
    }
}

extension ExecutionResultError {
    func description() throws -> String {
        throw NotImplementedError()
    }
}
