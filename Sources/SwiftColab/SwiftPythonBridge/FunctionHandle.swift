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
    public func retainFunction(name: String, function: @escaping (PythonObject) throws -> Any) {
        let wrapper = { (params: PythonObject) throws -> PythonObject in
            let output = try function(params)
            
            switch output {
            case let aPythonConvertible as PythonConvertible:
                return aPythonConvertible.pythonObject
            case _ as Void:
                return Python.None
            default:
                struct NotConvertibleError: Error { let localizedDescription: String }
                throw NotConvertibleError(localizedDescription: "Called a Swift function from Python that did not return a PythonConvertible or Void")
            }
        }
        
        let handle = FunctionHandle(wrapping: wrapper)
        let handleRef = Unmanaged.passRetained(handle).toOpaque()
        
        self.swift_delegate.function_table[PythonObject(name)] = .init(Int(bitPattern: handleRef))
    }
    
    public func releaseFunction(name: String) throws {
        let nameObject = PythonObject(name)
        
        guard let retrievedInt = Int(self.function_table[nameObject]) else {
            struct ReleaseFunctionError: Error { let localizedDescription: String }
            throw ReleaseFunctionError(localizedDescription: "Attempted to release a non-retained \(name) function on a Python object")
        }
        
        let handleRef = UnsafeRawPointer(bitPattern: retrievedInt)!
        Unmanaged<FunctionHandle>.fromOpaque(handleRef).release()
        
        self.swift_delegate.function_table[nameObject] = Python.None
    }
}
