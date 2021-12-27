import Foundation
import PythonKit
let lldb = Python.import("lldb")

/// Protocol for the result of executing code.
protocol ExecutionResult: CustomDebugStringConvertible { }

/// Protocol for the result of successfully executing code.
protocol ExecutionResultSuccess: ExecutionResult { }

/// Protocol for the result of unsuccessfully executing code.
protocol ExecutionResultError: ExecutionResult { }

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
    }
}
