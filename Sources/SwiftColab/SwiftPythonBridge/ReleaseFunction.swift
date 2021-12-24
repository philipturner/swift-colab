import PythonKit
fileprivate let swiftModule = Python.import("swift")

@_cdecl("releaseFunctionTable")
public func releaseFunctionTable(_ tableRef: OwnedPyObjectPointer) -> PyObjectPointer {
    let tableObject = PythonObject(tableRef)
    print("Inside Swift code, releasing the retained function table \(tableObject)")
    
    var errorObject = Python.None
    let keys = [PythonObject](tableObject.keys())
    
    for key in keys {
        do {
            try selfObject.releaseFunction(name: .init(key))
        } catch {
            errorObject = swiftModule.SwiftError(error.localizedDescription)
        }
    }
    
    let returnValue = swiftModule.SwiftReturnValue(Python.None, errorObject)
    return returnValue.ownedPyObject
}

