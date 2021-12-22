// small dynamic library for calling Swift functions from Python
// will import PythonKit eventually, but for now, use OpaquePointer instead of PythonObject
// can also be imported from Swift, as it defines the function wrapper struct

// 2 accepted Swift types:
// (PythonObject) throws -> Void
// (PythonObject) throws -> PythonObject

import PythonKit

@_cdecl("callSwiftFromPython")
public func callSwiftFromPython(_ functionHandleRef: OpaquePointer, _ params: OwnedPyObjectPointer) -> PyObjectPointer {
    // initialize the function handle ref using Unmanaged<FunctionHandle>
    // initialize the PythonObject from params using PythonObject+ID
}
