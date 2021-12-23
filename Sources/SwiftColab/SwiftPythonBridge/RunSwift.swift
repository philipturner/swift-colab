// take a Python string object as input and compile and run it

import Foundation
import PythonKit

@_cdecl("runSwiftAsString")
public func runSwiftAsString(_ pythonStringRef: OwnedPyObjectPointer) {
    let pi = ProcessInfo.processInfo
    let path = pi.environment["PATH"]
    
    if !path.startsWith("/opt/swift/toolchain/usr/bin") {
        pi.environment["PATH"] = "/opt/swift/toolchain/usr/bin:\(path)"
    }
    
    let codeString = String(PythonObject(pythonStringRef))
    
}
