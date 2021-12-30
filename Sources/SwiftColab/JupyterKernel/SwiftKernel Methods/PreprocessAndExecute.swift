import Foundation
import PythonKit

fileprivate let lldb = Python.import("lldb")
fileprivate let re = Python.import("re")
fileprivate let os = Python.import("os")
fileprivate let sys = Python.import("sys")

func preprocess_and_execute(_ selfRef: PythonObject, code: PythonObject) throws -> Any {
    do {
        let (includes, other) = try preprocess(selfRef, code: code)
        
        if let includes = includes {
            let returnVal = execute(selfRef, code: includes)
            if returnVal is SwiftError { return returnVal } 
        }
        
        return execute(selfRef, code: other)
    } catch let e as PreprocessorException {
        return PreprocessorError(exception: e)
    }
}

func execute(_ selfRef: PythonObject, code: PythonObject) -> ExecutionResult {
    let fileName = file_name_for_source_location(selfRef)
    let locationDirective = PythonObject("#sourceLocation(file: \"\(fileName)\", line: 1)")
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

fileprivate typealias PreprocessReturn = (PythonObject?, PythonObject)

fileprivate func preprocess(_ selfRef: PythonObject, code: PythonObject) throws -> PreprocessReturn {
    let lines = Array(code[dynamicMember: "split"]("\n"))
    var preprocessed_includes: [PythonObject] = []
    var preprocessed_other: [PythonObject] = []
    
    for i in 0..<lines.count {
        let line = lines[i]
        let (isInclude, returnLine) = try preprocess_line(selfRef, line_index: PythonObject(i), line: line)
        
        if isInclude {
            preprocessed_includes.append(returnLine)
        } else {
            preprocessed_other.append(returnLine)
        }
    }
    
    let preprocessed_lines = preprocessed_includes + preprocessed_other
    
//     let preprocessed_lines = try (0..<lines.count).map { i -> PythonObject in
//         let line = lines[i]
//         return try preprocess_line(selfRef, line_index: PythonObject(i), line: line)
//     }
    
    let includes_output = preprocessed_includes.count > 0 ? PythonObject("\n").join(preprocessed_includes) : nil
    let other_output = PythonObject("\n").join(preprocessed_other)
    
    return (includes_output, other_output)
    
//     return PythonObject("\n").join(preprocessed_lines)
}

// Goal: swap the role of system commands and %include commands.
// For now, sort out the %include commands and execute them first.
// Then, work into executing them in process_installs
fileprivate typealias PreprocessReturn = (isInclude: Bool, line: PythonObject)

/// Returns the preprocessed line.
///
/// Does not process "%install" directives, because those need to be
/// handled before everything else.
fileprivate func preprocess_line(_ selfRef: PythonObject, line_index: PythonObject, line: PythonObject) throws -> PreprocessReturn {
    let include_match = re.match(###"""
    ^\s*%include (.*)$
    """###, line)
    if include_match != Python.None {
        return (true, try read_include(selfRef, line_index: line_index, rest_of_line: include_match.group(1)))
    }
    
    let disable_completion_match = re.match(###"""
    ^\s*%disableCompletion\s*$
    """###, line)
    if disable_completion_match != Python.None {
        try handle_disable_completion(selfRef)
        return (false, "")
    }
    
    let enable_completion_match = re.match(###"""
    ^\s*%enableCompletion\s*$
    """###, line)
    if enable_completion_match != Python.None {
        try handle_enable_completion(selfRef)
        return (false, "")
    }
    
    return (false, line)
}

fileprivate var previouslyReadPaths: [String] = []

fileprivate func read_include(_ selfRef: PythonObject, line_index: PythonObject, rest_of_line: PythonObject) throws -> PythonObject {
    let name_match = re.match(###"""
    ^\s*"([^"]+)"\s*$
    """###, rest_of_line)
    guard name_match != Python.None else {
        throw PreprocessorException(
            "Line \(line_index + 1): %include must be followed by a name in quotes")
    }
    
    let name = name_match.group(1)
    
    let include_paths = [
        PythonObject("/opt/swift/include"),
        os.path.realpath(".")
    ]
    
    var code = Python.None
    var chosenPath: String = ""
    var rejectedAPath = false
    
    for include_path in include_paths {
        do {
            let path = String(os.path.join(include_path, name))!
            if previouslyReadPaths.contains(path) { 
                rejectedAPath = true
                continue 
            }
            
            let f = try Python.open.throwing.dynamicallyCall(withArguments: path, "r")
            code = try f.read.throwing.dynamicallyCall(withArguments: [])
            f.close()
            
            chosenPath = path
        } catch PythonError.exception(let error, let traceback) {
            guard Bool(Python.isinstance(error, Python.IOError))! else {
                throw PythonError.exception(error, traceback: traceback)
            }
        }
    }
    
    guard code != Python.None else {
        if rejectedAPath {
            return ""
        }
        
        throw PreprocessorException(
            "Line \(line_index + 1): Could not find \"\(name)\". Searched \(include_paths).")
    }
    
    previouslyReadPaths.append(chosenPath)
    let secondName = file_name_for_source_location(selfRef)
    
    return PythonObject("\n").join([
        "#sourceLocation(file: \"\(name)\", line: 1)".pythonObject,
        code,
        "#sourceLocation(file: \"\(secondName)\", line: \(line_index + 1))".pythonObject,
        ""
    ])
}
