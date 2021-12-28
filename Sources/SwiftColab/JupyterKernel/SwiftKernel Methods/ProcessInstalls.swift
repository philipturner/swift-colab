import Foundation
import PythonKit

fileprivate let os = Python.import("os")
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")
fileprivate let subprocess = Python.import("subprocess")

fileprivate func process_install_location_line(_ selfRef: PythonObject, line_index: PythonObject, line: PythonObject) throws -> PythonObject {
    let regexExpression: PythonObject = ###"""
    ^\s*%install-location (.*)$
    """###
    guard var install_location = Optional(re.match(regexExpression, line))?.group(1) else {
        return (line, Python.None)
    }
    
    try process_install_substitute(template: &install_location, line_index: line_index)
    return ("", install_location)
}

fileprivate func process_extra_include_command_line(_ selfRef: PythonObject, line: PythonObject) -> PythonObject {
    let regexExpression: PythonObject = ###"""
    ^\s*%install-extra-include-command (.*)$
    """###
    if let extra_include_command = Optional(re.match(regexExpression, line))?.group(1) {
        return ("", extra_include_command)
    } else {
        return (line, Python.None)
    }
}

fileprivate func process_install_swiftpm_flags_line(_ selfRef: PythonObject, line: PythonObject) -> PythonObject {
    let regexExpression: PythonObject = ###"""
    ^\s*%install-swiftpm-flags (.*)$
    """###
    if let flags = Optional(re.match(regexExpression, line))?.group(1) {
        return ("", flags)
    } else {
        return (line, [])
    }
}

fileprivate func process_install_line(_ selfRef: PythonObject, line_index: PythonObject, line: PythonObject) throws -> PythonObject {
    let regexExpression: PythonObject = ###"""
    ^\s*%install (.*)$
    """###
    guard let install_match = Optional(re.match(regexExpression, line)) else {
        return (line, [])
    }
    
    let parsed = shlex.split(install_match.group(1))
    guard Python.len(parsed) >= 2 else {
        throw PackageInstallException(
            "Line: \(line_index + 1): %install usage: SPEC PRODUCT [PRODUCT ...]")
    }
    
    try process_install_substitute(template: &parsed[0], line_index: line_index)
    return ("", [[
        "spec": parsed[0],
        "products": parsed[1...]
    ]])
}

// Addition by Philip Turner

fileprivate func process_install_substitute(template: inout PythonObject, line_index: PythonObject) throws {
    do {
        let function = Python.string.Template(template).substitute.throwing
        template = try function.dynamicallyCall(withArguments: ["cwd": os.getcwd()])
    } catch PythonError.exception(let error, let traceback) {
        let e = PythonError.exception(error, traceback: traceback)
        
        if e.__class__ == Python.KeyError {
            throw PackageInstallException(
                "Line \(line_index + 1): Invalid template argument \(e)")
        } else if e.__class__ == Python.ValueError {
            throw PackageInstallException(
                "Line \(line_index + 1): \(e)")
        } else {
            throw e
        }
    }
}
