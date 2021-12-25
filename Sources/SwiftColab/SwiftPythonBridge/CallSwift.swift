import PythonKit
fileprivate let swiftModule = Python.import("swift")

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
        errorObject = swiftModule.SwiftError(error.localizedDescription)
    }
    
    let returnValue = swiftModule.SwiftReturnValue(wrappedObject, errorObject)
    return returnValue.ownedPyObject
}
