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
    private struct NotConvertibleError: Error { let localizedDescription: String }
    
    public func retainFunction<T>(name: String, function: @escaping (PythonObject) throws -> T) {
        let wrapper = { (params: PythonObject) throws -> PythonObject in
            let output = try function(params)
            
            switch output {
            case let aPythonConvertible as PythonConvertible:
                return aPythonConvertible.pythonObject
            case _ as Void:
                return Python.None
            default:
                throw NotConvertibleError(localizedDescription: "Called a Swift function from Python that did not return a PythonConvertible or Void")
            }
        }
        
        let handle = FunctionHandle(wrapping: wrapper)
        let handleRef = Unmanaged.passRetained(handle).toOpaque()
        
        self.swift_delegate.function_table[name] = .init(Int(bitPattern: handleRef))
    }
    
    public func releaseFunction(name: String) throws {
        guard let retrievedInt = Int(self.function_table[name]) else {
            struct ReleaseFunctionError: Error { let localizedDescription: String }
            throw ReleaseFunctionError(localizedDescription: "Attempted to release a non-retained \(name) function on a Python object")
        }
        
        let handleRef = UnsafeRawPointer(bitPattern: retrievedInt)!
        Unmanaged<FunctionHandle>.fromOpaque(handleRef).release()
        
        self.swift_delegate.function_table[name] = Python.None
    }
}
