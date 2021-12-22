import PythonKit

class FunctionHandle {
    private let function: (PythonObject) throws -> PythonObject
    
    init(wrapping function: @escaping (PythonObject) throws -> PythonObject) {
        self.function = function
    }
    
    func call(_ params: PythonObject) throws -> PythonObject {
        try function(params)
    }
}

extension PythonObject {
    public func retainFunction(name: String, function: @escaping (PythonObject) throws -> Void) {
        retainFunction(name: name) { params -> PythonObject in
            try function(params)
            return Python.None
        }
    }
    
    public func retainFunction(name: String, function: @escaping (PythonObject) throws -> PythonObject) {
        let handle = FunctionHandle(wrapping: function)
        let handleRef = Unmanaged.passRetained(handle).toOpaque()
        
        self.function_table[PythonObject(name)] = .init(Int(bitPattern: handleRef))
    }
    
    public func releaseFunction(name: String) {
        let nameObject = PythonObject(name)
        
        let retrievedInt = Int(self.function_table[nameObject])!
        let handleRef = UnsafeRawPointer(bitPattern: retrievedInt)!
        Unmanaged<FunctionHandle>.fromOpaque(handleRef).release()
        
        self.function_table[nameObject] = Python.None
    }
}
