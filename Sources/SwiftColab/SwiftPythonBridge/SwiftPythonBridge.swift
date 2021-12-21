// small dynamic library for calling Swift functions from Python
// will import PythonKit eventually, but for now, use OpaquePointer instead of PythonObject
// can also be imported from Swift, as it defines the function wrapper struct

// 6 accepted Swift types;
// @convention(c) (PythonObject) throws -> Void
// @convention(c) (PythonObject) throws -> PythonObject
// (PythonObject) throws -> Void
// (PythonObject) throws -> PythonObject

// Workaround that lets me avoid modifying PythonKit: make a class that replicates the behavior of PyReference. Then, unsafe bit cast it to a PythonObject.

// could make this a one-file binary
