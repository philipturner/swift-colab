import Foundation
import PythonKit
fileprivate let lldb = Python.import("lldb")
fileprivate let re = Python.import("re")
fileprivate let os = Python.import("os")
fileprivate let sys = Python.import("sys")

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
    let regexExpression = PythonObject(###"""
    ^\s*"([^"]+)"\s*$
    """###)
    guard let name = Optional(re.match(regexExpression, rest_of_line)).group(1) else {
        throw PreprocessorException(
            "Line \(line_index + 1): %%include must be followed by a name in quotes")
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
        } catch(let e) {
        
        }
    }
}
