import Foundation
import PythonKit
fileprivate let swiftModule = Python.import("swift")

// Takes a Python string object as input, then compiles and runs it
@_cdecl("runSwiftAsString")
public func runSwiftAsString(_ pythonStringRef: OwnedPyObjectPointer) -> PyObjectPointer {
    @inline(never)
    func getPythonError(message: String) -> PyObjectPointer {
        print(message)
        let errorObject = swiftModule.SwiftError(PythonObject(message))
        return swiftModule.SwiftReturnValue(Python.None, errorObject).ownedPyObject
    }
    
    func doCommand(_ args: [String], directory: String? = nil) throws {
        let command = Process()
        command.executableURL = .init(fileURLWithPath: "/usr/bin/env")
        command.arguments = args

        if let directory = directory {
            command.currentDirectoryURL = .init(fileURLWithPath: directory)
        }

        try command.run()
        command.waitUntilExit()
    }
    
    try! doCommand(["echo", "runSwift checkpoint 1.011"])
    
    // Try running another thread to work around this bug
    
    
    
//     Py_Initialize()
    print(PyEval_GetBuiltins)
    try! doCommand(["echo", "runSwift checkpoint 1.021"])    
    
    // I think I'm triggering a crash from the Python Global Interpreter Lock
    
    
    let builtinsResult = PyEval_GetBuiltins()
    try! doCommand(["echo", "runSwift checkpoint 1.03"])
    
    let builtinsObject = PythonObject(builtinsResult)
    try! doCommand(["echo", "runSwift checkpoint 1.04"])
    
    print(builtinsObject)
    try! doCommand(["echo", "runSwift checkpoint 1.05"])
    
    // Runtime Fixes:
    PyRun_SimpleString("""
        import sys
        import os

        # Some Python modules expect to have at least one argument in `sys.argv`.
        sys.argv = [""]
        # Some Python modules require `sys.executable` to return the path
        # to the Python interpreter executable. In Darwin, Python 3 returns the
        # main process executable path instead.
        if sys.version_info.major == 3 and sys.platform == "darwin":
            sys.executable = os.path.join(sys.exec_prefix, "bin", "python3")
        """)
    try! doCommand(["echo", "runSwift checkpoint 1.06"])
    
    print(Python)
    try! doCommand(["echo", "runSwift checkpoint 1.07"])
    
    guard let scriptString = String(PythonObject(pythonStringRef)) else {
        return getPythonError(message: "Could not decode the Python string passed into `runSwiftAsString(_:)`")
    }
    
    guard let scriptData = scriptString.data(using: .utf8) else {
        return getPythonError(message: "Python string was not decoded as UTF-8 when compiling a Swift script")
    }
    
    try! doCommand(["echo", "runSwift checkpoint 2"])
    
    let targetPath = "/opt/swift/tmp/string_script.swift"
    FileManager.default.createFile(atPath: targetPath, contents: scriptData)
    
    let executeScript = Process()
    executeScript.executableURL = .init(fileURLWithPath: "/usr/bin/env")
    executeScript.arguments = ["swift", targetPath]
    executeScript.currentDirectoryURL = .init(fileURLWithPath: "/content")
    
    var environment = ProcessInfo.processInfo.environment
    let path = environment["PATH"]!
    environment["PATH"] = "/opt/swift/toolchain/usr/bin:\(path)"
    executeScript.environment = environment
    
    do {
        try executeScript.run()
    } catch {
        return getPythonError(message: error.localizedDescription)
    }
    
    executeScript.waitUntilExit()
    
    try! doCommand(["echo", "runSwift checkpoint 3.2"])
    
    let noneObject = Python.None
    
    try! doCommand(["echo", "runSwift checkpoint 3.3"])
    
    let typeObject = swiftModule.SwiftReturnValue
    
    try! doCommand(["echo", "runSwift checkpoint 3.4"])
    
    let output = typeObject(noneObject, noneObject)
    
    try! doCommand(["echo", "runSwift checkpoint 3.7"])
    
    return output.ownedPyObject
}
