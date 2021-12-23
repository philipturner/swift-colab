import PythonKit
fileprivate let swiftModule = Python.import("swift")

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
        errorObject = swiftModule.SwiftError(PythonObject(error.localizedDescription))
    }
    
    let returnValue = swiftModule.SwiftReturnValue(wrappedObject, errorObject)
    return returnValue.borrowedPyObject
}
