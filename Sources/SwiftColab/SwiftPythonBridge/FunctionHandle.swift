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
                throw NotConvertibleError(localizedDescription: "From within Python, called a Swift function did not return a PythonConvertible or Void")
            }
        }
        
        let function_table = self.swift_delegate.function_table
        
        if let retrievedObject = function_table[name], let previousAddress = Int(retrievedObject) {
           releaseFunction(address: previousAddress)
        }
        
        let handle = FunctionHandle(wrapping: wrapper)
        let handleRef = Unmanaged.passRetained(handle).toOpaque()
        function_table[name] = .init(Int(bitPattern: handleRef))
    }
    
    public func releaseFunction(name: String) throws {
        let function_table = self.swift_delegate.function_table
        
        guard let address = Int(function_table[name]) else {
            struct ReleaseFunctionError: Error { let localizedDescription: String }
            throw ReleaseFunctionError(localizedDescription: "Attempted to release a non-retained \(name) function on a Python object")
        }
        
        releaseFunction(address: address)
        function_table[name] = Python.None
    }
    
    private func releaseFunction(address: Int) {
        let handleRef = UnsafeRawPointer(bitPattern: address)!
        Unmanaged<FunctionHandle>.fromOpaque(handleRef).release()
    }
}
