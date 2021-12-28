import Foundation
import PythonKit

let os = Python.import("os")
let re = Python.import("re")
let shlex = Python.import("shlex")
let subprocess = Python.import("subprocess")

fileprivate func process_install_location_line(_ selfRef: PythonObject, line: PythonObject) throws -> PythonObject {
    let regexExpression: PythonObject = ###"""
    ^\s*%install-location (.*)$
    """###
    guard let install_location = Optional(re.match(regexExpression, line)?.group(1) else {
        return (line, Python.None)
    }
}
