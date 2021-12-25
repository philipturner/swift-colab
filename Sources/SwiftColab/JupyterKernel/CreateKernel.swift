import Foundation
import PythonKit
import SwiftPythonBridge
// import the Python Jupyter kernel library too
fileprivate let swiftModule = Python.import("swift")

@_cdecl("JKCreateKernel")
public func JKCreateKernel(_ jupyterKernelRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let noneObject = Python.None
    let errorObject = noneObject
    
    let jupyterKernel = PythonObject(jupyterKernelRef)
    jupyterKernel.swift_delegate = swiftModule.SwiftDelegate()
    
    jupyterKernel.registerFunction(name: "helloC") { params -> PythonConvertible in
        helloC(Int32(params)!)
    }
    
    return swiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
