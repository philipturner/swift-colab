// Small dynamic library for calling Swift functions from Python.
// Can also be imported by Swift because it declares the PythonObject
// method for filling the function table of a `SwiftDelegate`.

// Accepts two Swift types:
// (PythonObject) throws -> Void
// (PythonObject) throws -> PythonObject

import PythonKit
let swift = Python.import("swift")

@_cdecl("callSwiftFromPython")
public func callSwiftFromPython(_ functionHandleRef: UnsafeRawPointer, _ params: OwnedPyObjectPointer) -> PyObjectPointer {
    let functionHandle = Unmanaged<FunctionHandle>.fromOpaque(functionHandleRef).takeUnretainedValue()
    let params = PythonObject(params)
    
    var wrappedObject: PythonObject
    var errorObject: PythonObject
    
    do {
        wrappedObject = try functionHandle.call(params)
        errorObject = Python.None
    } catch {
        wrappedObject = Python.None
        errorObject = swift.SwiftError(PythonObject(error.localizedDescription))
    }
    
    let returnValue = swift.SwiftReturnValue(wrappedObject, errorObject)
    return returnValue.borrowedPyObject
}
