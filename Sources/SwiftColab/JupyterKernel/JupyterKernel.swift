import Foundation
import PythonKit
import SwiftPythonBridge
// import the Python Jupyter kernel library too
fileprivate let swiftModule = Python.import("swift")

@_cdecl("JupyterKernelCreate")
public func JupyterKernelCreate(_ jupyterKernelRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let noneObject = Python.None
    let errorObject = noneObject
//     var errorObject = noneObject
    
//     do {
    let jupyterKernel = PythonObject(jupyterKernelRef)
    jupyterKernel.swift_delegate = swiftModule.SwiftDelegate()
    
    jupyterKernel.registerFunction(name: "helloC") { params -> PythonConvertible in
        helloC(Int32(params)!)
    }
//     } catch {
//         print(error.localizedDescription)
//         errorObject = swiftModule.SwiftError(error.localizedDescription)
//     }
    
    return swiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
