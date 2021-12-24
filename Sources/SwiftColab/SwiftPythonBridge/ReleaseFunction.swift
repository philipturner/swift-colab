import PythonKit
fileprivate let swiftModule = Python.import("swift")

@_cdecl("releaseFunctionTable")
public func releaseFunctionTable(_ tableRef: OwnedPyObjectPointer) -> PyObjectPointer {
    let tableObject = PythonObject(tableRef)
    print("Inside Swift code, releasing the retained function table \(tableObject)")
    
    let noneObject = Python.None
    let keys = [PythonObject](tableObject.keys())!
    
    for key in keys {
        guard let address = Int(tableObject[key]) else {
            continue
        }
        
        FunctionHandle.release(address: address)
        tableObject[key] = noneObject
    }
    
    return swiftModule.SwiftReturnValue(noneObject, noneObject).ownedPyObject
}

