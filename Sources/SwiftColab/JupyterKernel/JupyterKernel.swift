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
        jupyterKernel.swift_delegate = swiftModule.SwiftDelegate()
        print("Modified log 4444 statement: \(jupyterKernel)")
    } catch {
        errorObject = swiftModule.SwiftError(error.localizedDescription)
    }
    
    return swiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
