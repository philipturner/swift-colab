import Foundation
import PythonKit
fileprivate let lldb = Python.import("lldb")

/// Protocol for the result of executing code.
protocol ExecutionResult: CustomDebugStringConvertible { }

/// Protocol for the result of successfully executing code.
protocol ExecutionResultSuccess: ExecutionResult { }

/// Protocol for the result of unsuccessfully executing code.
protocol ExecutionResultError: ExecutionResult { 
    var description: String { get }
}

/// The code executed successfully, and did not produce a value.
struct SuccessWithoutValue: ExecutionResultSuccess {
    var debugDescription: String {
        "SuccessWithoutValue()"
    }
}

/// The code executed successfully, and produced a value.
struct SuccessWithValue: ExecutionResultSuccess {
    var result: PythonObject // SBValue
    
    /// A description of the value, e.g.
    ///   (Int) $R0 = 64
    func value_description() -> PythonObject {
        let stream = lldb.SBStream()
        result.GetDescription(stream)
        return stream.GetData()
    }
    
    var debugDescription: String {
        "SuccessWithValue(result: \(Python.repr(result)), description: \(Python.repr(result.description))"
    }
}

/// There was an error preprocessing the code.
struct PreprocessorError: ExecutionResultError {
    var exception: PreprocessorException
    
    var description: String {
        String(describing: self.exception)
    }
    
    var debugDescription: String {
        "PreprocessorError(exception: \(String(reflecting: exception)))"
    }
}

struct PreprocessorException: LocalizedError {
    var errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

struct PackageInstallException: LocalizedError {
    var errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// There was a compile or runtime error.
struct SwiftError: ExecutionResultError {
    var result: PythonObject // SBValue
    
    var description: String {
        result.error.description
    }
    
    var debugDescription: String {
        "SwiftError(result: \(Python.repr(result)), description: \(description))"
    }
}
