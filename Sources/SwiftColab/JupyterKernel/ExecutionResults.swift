import Foundation
import PythonKit
let lldb = Python.import("lldb")

/// Protocol for the result of executing code.
protocol ExecutionResult: CustomDebugStringConvertible { }

/// Protocol for the result of successfully executing code.
protocol ExecutionResultSuccess: ExecutionResult { }

/// Protocol for the result of unsuccessfully executing code.
protocol ExecutionResultError: ExecutionResult { 
    var description: String
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
    
    /// A description of the vaule, e.g.
    ///   (Int) $R0 = 64
    func valueDescription() -> String {
        let stream = lldb.SBStream()
        result.GetDescription(stream)
        return stream.GetData()
    }
    
    var debugDescription: String {
        "SuccessWithValue(result: \(Python.repr(result)), description: \(Python.repr(result.checking.description ?? "not found"))"
    }
}

/// There was an error preprocessing the code.
struct PreprocessorError: ExecutionResultError {
    var exception: PreprocessorException
    
    var description: String {
        String(self.exception)
    }
    
    var debugDescription: String {
        "PreprocessorError(exception: \(String(reflecting: exception)))"
    }
}
