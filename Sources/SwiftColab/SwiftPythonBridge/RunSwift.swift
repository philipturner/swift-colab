import Foundation
import PythonKit
fileprivate let swiftModule = globalSwiftModule

// takes a Python string object as input and compile and run it
@_cdecl("runSwiftAsString")
public func runSwiftAsString(_ pythonStringRef: OwnedPyObjectPointer) -> PyObjectPointer {
    let pi = ProcessInfo.processInfo
    let path = pi.environment["PATH"]
    
    @inline(never)
    func getPythonError(message: String) -> PythonObject {
        swiftModule.SwiftError(PythonObject(message))
    }
    
    if !path.starts(with: "/opt/swift/toolchain/usr/bin") {
        pi.environment["PATH"] = "/opt/swift/toolchain/usr/bin:\(path)"
    }
    
    let codeString = String(PythonObject(pythonStringRef))
    guard let codeData = codeString.data(using: .utf8) else {
        return getPythonError(message: "Python string was not decoded as UTF-8 when compiling a Swift script")
    }
    
    
}
