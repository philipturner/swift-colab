import Foundation
import PythonKit
import SwiftPythonBridge
// import the Python Jupyter kernel library too
fileprivate let swiftModule = Python.import("swift")

@_cdecl("JupyterKernelCreate")
public func JupyterKernelCreate(_ jupyterKernelRef: OwnedPyObjectPointer) -> PyObjectPointer {
    let noneObject = Python.None
    var errorObject = noneObject
    
    do {
        let jupyterKernel = PythonObject(jupyterKernelRef)
    } catch {
        errorObject = swiftModule.SwiftError(error.localizedDescription)
    }
    
    return swiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
