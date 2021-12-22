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
    // initialize the function handle ref using Unmanaged<FunctionHandle>
    let paramsObject = PythonObject(params)
    var returnObject = Python.None
    var returnError = Python.None
    
    // call the function, either get an object or don't
    
    try {
        if ... { /* non-returning closure */
            _ = ...
        } else { /* returning closure */
            returnObject = ...
        }
    } catch {
        returnError = Python.Exception(PythonObject(error.localizedDescription))
    }
    
    
    
    
    // return the output's borrowedPythonObject
}
