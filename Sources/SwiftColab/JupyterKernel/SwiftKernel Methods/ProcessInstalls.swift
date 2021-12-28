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
    guard var install_location = Optional(re.match(regexExpression, line))?.group(1) else {
        return (line, Python.None)
    }
    
    do {
        let function = Python.string.Template(install_location).substitute.throwing
        install_location = try function.dynamicallyCall(withArguments: ["cwd": os.getcwd()])
    } catch PythonError.exception(let error, let traceback) {
        let e = PythonError.exception(error, traceback: traceback)
    }
    
    return ("", install_location)
}
