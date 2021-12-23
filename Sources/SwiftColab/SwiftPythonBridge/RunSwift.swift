import Foundation
import PythonKit
fileprivate let swiftModule = Python.import("swift")

// takes a Python string object as input and compile and run it
@_cdecl("runSwiftAsString")
public func runSwiftAsString(_ pythonStringRef: OwnedPyObjectPointer) -> PyObjectPointer {
    @inline(never)
    func getPythonError(message: String) -> PyObjectPointer {
        let errorObject = swiftModule.SwiftError(PythonObject(message))
        return swiftModule.SwiftReturnValue(Python.None, errorObject).borrowedPyObject
    }
    
    let scriptString = String(PythonObject(pythonStringRef))
    guard let scriptData = scriptString.data(using: .utf8) else {
        let message = "Python string was not decoded as UTF-8 when compiling a Swift script"
        print(message)
        return getPythonError(message: message)
    }
    
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
        print(error.localizedDescription)
        return getPythonError(message: error.localizedDescription)
    }
    
    executeScript.waitUntilExit()
    
    let noneObject = Python.None
    return swiftModule.SwiftReturnValue(noneObject, noneObject).borrowedPyObject
}
