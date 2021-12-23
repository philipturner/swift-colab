// take a Python string object as input and compile and run it

import Foundation
import PythonKit
// pythonSwiftModule is defined in the header file

@_cdecl("runSwiftAsString")
public func runSwiftAsString(_ pythonStringRef: OwnedPyObjectPointer) -> PyObjectPointer {
    let pi = ProcessInfo.processInfo
    let path = pi.environment["PATH"]
    
    @inline(never)
    func getPythonError(stringValue: String) {
        let 
    }
    
    if !path.starts(with: "/opt/swift/toolchain/usr/bin") {
        pi.environment["PATH"] = "/opt/swift/toolchain/usr/bin:\(path)"
    }
    
    let codeString = String(PythonObject(pythonStringRef))
    let codeData = codeString.data(using: .utf8)
}
