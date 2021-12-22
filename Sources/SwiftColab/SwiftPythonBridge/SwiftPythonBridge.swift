// small dynamic library for calling Swift functions from Python
// will import PythonKit eventually, but for now, use OpaquePointer instead of PythonObject
// can also be imported from Swift, as it defines the function wrapper struct

// 2 accepted Swift types:
// (PythonObject) throws -> Void
// (PythonObject) throws -> PythonObject

import PythonKit

let swift = Python.import("swift")

@_cdecl("callSwiftFromPython")
public func callSwiftFromPython(_ functionHandleRef: OpaquePointer, _ params: OwnedPyObjectPointer) -> PyObjectPointer {
    let params = PythonObject(params)
    var wrappedObject = Python.None
    var error = Python.None
    
    // initialize the function handle ref using Unmanaged<FunctionHandle>
    
    try {
        if ... { /* non-returning closure */
            _ = ...
        } else { /* returning closure */
            wrappedObject = ...
        }
    } catch {
        error = swift.SwiftError(PythonObject(error.localizedDescription))
    }
    
    let returnValue = swift.SwiftReturnValue(wrappedObject, error)
    return returnValue.borrowedPyObject
}
