import Foundation
import PythonKit
fileprivate let swiftModule = globalSwiftModule

// takes a Python string object as input and compile and run it
@_cdecl("runSwiftAsString")
public func runSwiftAsString(_ pythonStringRef: OwnedPyObjectPointer) -> PyObjectPointer {
    let pi = ProcessInfo.processInfo
    let path = pi.environment["PATH"]
    
    @inline(never)
    func getPythonError(message: String) -> PyObjectPointer {
        swiftModule.SwiftError(PythonObject(message)).borrowedPyObject
    }
    
    if !path.starts(with: "/opt/swift/toolchain/usr/bin") {
        pi.environment["PATH"] = "/opt/swift/toolchain/usr/bin:\(path)"
    }
    
    let scriptString = String(PythonObject(pythonStringRef))
    guard let scriptData = scriptString.data(using: .utf8) else {
        let message = "Python string was not decoded as UTF-8 when compiling a Swift script"
        print(message)
        return getPythonError(message: message)
    }
    
    let targetPath = "/opt/swift/tmp/string_script.swift")
    FileManager.default.createFile(atPath: targetPath, contents: scriptData)
    
    let executeScript = Process()
    executeScript.executableURL = .init(fileURLWithPath: "/usr/bin/env")
    executeScript.arguments = ["swift", targetPath]
    executeScript.currentDirectoryURL = .init(fileURLWithPath: "/content")
    
    do {
        try executeScript.run()
    } catch {
        print(error.localizedDescription)
        return getPythonError(message: error.localizedDescription)
    }
    
    executeScript.waitUntilExit()
    return Python.None.borrowedPythonObject
}
