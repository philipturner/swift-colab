import Foundation
import PythonKit
fileprivate let lldb = Python.import("lldb")
fileprivate let re = Python.import("re")
fileprivate let os = Python.import("os")
fileprivate let sys = Python.import("sys")

func execute(_ selfRef: PythonObject, code: PythonObject) -> ExecutionResult {
    let fileName = file_name_for_source_location(selfRef)
    let locationDirective = PythonObject("#sourceLocation(file: \(fileName), line: 1)")
    let codeWithLocationDirective = locationDirective + "\n" + code
    
    let result = selfRef.target.EvaluateExpression(
        codeWithLocationDirective, selfRef.expr_opts)
    let errorType = result.error.type
    
    if errorType == lldb.eErrorTypeInvalid {
        return SuccessWithValue(result: result)
    } else if errorType == lldb.eErrorTypeGeneric {
        return SuccessWithoutValue()
    } else {
        return SwiftError(result: result)
    }
}

fileprivate func file_name_for_source_location(_ selfRef: PythonObject) -> String {
    "<Cell \(selfRef.execution_count)>"
}

/// Returns the preprocessed line.
///
/// Does not process "%install" directives, because those need to be
/// handled before everything else.
fileprivate func preprocess_line(_ selfRef: PythonObject, line_index: PythonObject, line: PythonObject) throws -> PythonObject {
    var regexExpression: PythonObject = ###"""
    ^\s*%include (.*)$
    """###
    if let include_match = Optional(re.match(regexExpression, line)) {
        return try read_include(selfRef, line_index: line_index, rest_of_line: include_match.group(1))
    }
    
    regexExpression = ###"""
    ^\s*%disableCompletion\s*$
    """###
    if let disable_completion_match = Optional(re.match(regexExpression, line)) {
        // try handle disable completion
        return ""
    }
    
    regexExpression = ###"""
    ^\s*%enableCompletion\s*$
    """###
    if let enable_completion_match = Optional(re.match(regexExpression, line)) {
        // try enable disable completion
        return ""
    }
    
    return line
}

fileprivate func read_include(_ selfRef: PythonObject, line_index: PythonObject, rest_of_line: PythonObject) throws -> PythonObject {
    let regexExpression: PythonObject = ###"""
    ^\s*"([^"]+)"\s*$
    """###
    guard let name = Optional(re.match(regexExpression, rest_of_line))?.group(1) else {
        throw PreprocessorException(
            "Line \(line_index + 1): %include must be followed by a name in quotes")
    }
    
    let include_paths = [
        os.path.dirname(os.path.realpath(sys.argv[0])),
        os.path.realpath("."),
    ]
    var code = Python.None
    
    for include_path in include_paths {
        do {
            let path = os.path.join(include_path, name)
            let f = try Python.open.throwing
                .dynamicallyCall(withArguments: path, "r")
            
            code = try f.read.throwing.dynamicallyCall(withArguments: [])
            f.close()
        } catch PythonError.exception(let error, _) {
            precondition(error.__class__ == Python.IOError)
        }
    }
    
    guard code != Python.None else {
        throw PreprocessorException(
            "Line \(line_index + 1): Could not find \"\(name)\". Searched \(include_paths).")
    }
    
    let secondName = file_name_for_source_location(selfRef)
    
    return PythonObject("\n").join([
        "#sourceLocation(file: \"\(name)\", line: 1)".pythonObject,
        code,
        "#sourceLocation(file: \"\(secondName)\", line: \(line_index + 1)".pythonObject,
        ""
    ])
}
