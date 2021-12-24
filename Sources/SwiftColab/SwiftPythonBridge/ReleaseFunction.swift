import PythonKit
fileprivate let swiftModule = Python.import("swift")

@_cdecl("releaseSwiftFunction")
public func releaseSwiftFunction(_ selfRef: OwnedPyObjectPointer, _ functionStringRef: OwnedPyObjectPointer) -> PyObjectPointer {
    let selfObject = PythonObject(selfRef)
    let name = String(PythonObject(functionString))
    
    print("Inside Swift code, releasing the retained function \(name)")
    
    let noneObject = Python.None
    var errorObject: PythonObject
    
    do {
        try selfObject.releaseFunction(name: name)
        errorObject = noneObject
    } catch {
        errorObject = swiftModule.SwiftError(error.localizedDescription)
    }

    let returnValue = swiftModule.SwiftReturnValue(noneObject, errorObject)
    return returnValue.ownedPyObject
}
