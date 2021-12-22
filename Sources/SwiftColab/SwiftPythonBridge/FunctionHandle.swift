import PythonKit

public class FunctionHandle {
    @usableFromInline
    internal let functionPointer: (PythonObject) throws -> PythonObject
    
    @inlinable
    public init(wrapping functionPointer: @escaping (PythonObject) throws -> Void) {
        self.functionPointer = { params in
            try functionPointer(params)
            return Python.None
        }
    }
    
    @inlinable
    public init(wrapping functionPointer: @escaping (PythonObject) throws -> PythonObject) {
        self.functionPointer = functionPointer
    }
}

public extension PythonObject {
    // register a Swift function handle in its vtable
}
