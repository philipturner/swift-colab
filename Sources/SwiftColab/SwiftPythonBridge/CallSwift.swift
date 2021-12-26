import PythonKit
fileprivate let SwiftModule = Python.import("Swift")

@_cdecl("callSwiftFromPython")
public func callSwiftFromPython(_ functionHandleRef: UnsafeRawPointer, _ params: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let functionHandle = Unmanaged<FunctionHandle>.fromOpaque(functionHandleRef).takeUnretainedValue()
    let params = PythonObject(params)
    
    var wrappedObject: PythonObject
    var errorObject: PythonObject
    
    do {
        wrappedObject = try functionHandle.call(params)
        errorObject = Python.None
    } catch {
        print(error.localizedDescription)
        wrappedObject = Python.None
        errorObject = SwiftModule.SwiftError(error.localizedDescription)
    }
    
    let returnValue = SwiftModule.SwiftReturnValue(wrappedObject, errorObject)
    return returnValue.ownedPyObject
}
