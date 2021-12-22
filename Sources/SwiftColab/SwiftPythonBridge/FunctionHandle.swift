import PythonKit

class FunctionHandle {
    private let functionPointer: (PythonObject) throws -> PythonObject
    
    init(wrapping functionPointer: @escaping (PythonObject) throws -> Void) {
        self.functionPointer = { params in
            try functionPointer(params)
            return Python.None
        }
    }
    
    init(wrapping functionPointer: @escaping (PythonObject) throws -> PythonObject) {
        self.functionPointer = functionPointer
    }
    
    func call(_ params: PythonObject) throws -> PythonObject {
        try functionPointer(params)
    }
}

public extension PythonObject {
    // register a Swift function handle in its vtable
}
