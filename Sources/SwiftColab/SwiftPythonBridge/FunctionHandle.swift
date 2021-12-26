import Foundation
import PythonKit

class FunctionHandle {
    private let function: (PythonObject) throws -> PythonObject
    
    init(wrapping function: @escaping (PythonObject) throws -> PythonObject) {
        self.function = function
    }
    
    func call(_ params: PythonObject) throws -> PythonObject {
        try function(params)
    }
    
    static func release(address: Int) {
        let handleRef = UnsafeRawPointer(bitPattern: address)!
        Unmanaged<FunctionHandle>.fromOpaque(handleRef).release()
    }
}

extension PythonObject {
    private struct NotConvertibleError: LocalizedError { 
        let errorDescription: String? = "From within Python, called a Swift function did not return a PythonConvertible or Void"
    }
    
    public func registerFunction<T>(name: String, function: @escaping (PythonObject) throws -> T) {
        let wrapper = { (params: PythonObject) throws -> PythonObject in
            let output = try function(params)
            
            switch output {
            case let aPythonConvertible as PythonConvertible:
                return aPythonConvertible.pythonObject
            case _ as Void:
                return Python.None
            default:
                throw NotConvertibleError()
            }
        }
        
        let function_table = self.swift_delegate.function_table
        
        if let retrievedObject = function_table.checking[name], 
           let previousAddress = Int(retrievedObject) {
            FunctionHandle.release(address: previousAddress)
        }
        
        let handle = FunctionHandle(wrapping: wrapper)
        let handleRef = Unmanaged.passRetained(handle).toOpaque()
        function_table[name] = .init(Int(bitPattern: handleRef))
    }
}
