import PythonKit
fileprivate let swiftModule = Python.import("swift")

@_cdecl("releaseFunctionTable")
public func releaseFunctionTable(_ tableRef: OwnedPyObjectPointer) -> PyObjectPointer {
    let tableObject = PythonObject(tableRef)
    print("Inside Swift code, releasing the retained function table \(tableObject)")
    
//     let errorObject = swiftModule.SwiftError("this error should be created from Swift") // forcing this function to fail for now
//     var errorObject = Python.None
//     let keys = [PythonObject](tableObject.keys())
    
//     for key in keys {
//         do {
//             try selfObject.releaseFunction(name: .init(key))
//         } catch {
//             errorObject = swiftModule.SwiftError(error.localizedDescription)
//         }
//     }
    
    let items = [PythonObject](tableObject.items())!
    
    for address in items.compactMap(Int.init) {
        let handleRef = UnsafeRawPointer(bitPattern: address)!
        Unmanaged<FunctionHandle>.fromOpaque(handleRef).release()
    }
    
    let noneObject = Python.None
    return swiftModule.SwiftReturnValue(noneObject, noneObject).ownedPyObject
}

