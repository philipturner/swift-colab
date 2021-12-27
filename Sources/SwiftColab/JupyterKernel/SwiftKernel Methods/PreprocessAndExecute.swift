import Foundation
import PythonKit
fileprivate let lldb = Python.import("lldb")
fileprivate let re = Python.import("re")

func execute(_ selfRef: PythonObject, code: PythonObject) -> ExecutionResult {
    let fileName = file_name_for_source_location(selfRef)
    let locationDirective = "#sourceLocation(file: \(fileName), line: 1)"
    let codeWithLocationDirective: PythonObject = "\(locationDirective)\n\(code)"
    
    let result = selfRef.target.EvaluateExpression(
        codeWithLocationDirective, selfRef.expr_opts)
    let errorType = result.error.type
    
    if errorType == lldb.eErrorTypeInvalid {
        return SuccessWithValue(result)
    } else if errorType == lldb.eErrorTypeGeneric {
        return SuccessWithoutValue()
    } else {
        return SwiftError(result)
    }
}

fileprivate func file_name_for_source_location(_ selfRef: PythonObject) -> String {
    "<Cell \(selfRef.execution_count)>"
}

fileprivate func read_include(_ selfRef: PythnonObject, line_index: PythonObject, rest_of_line: PythonObject) throws -> PythonObject {
    let regexExpression = PythonObject("""
    ^\s*"([^"]+)"\s*$
    """)
    guard let name_match = Optional(re.match(regexExpression, rest_of_line)) else {
        throw PreprocessorException(
            "Line \(line_index + 1): %%include must be followed by a name in quotes"
    }
    
    
}
