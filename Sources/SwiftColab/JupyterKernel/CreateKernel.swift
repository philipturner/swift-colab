import Foundation
import PythonKit
import SwiftPythonBridge
fileprivate let SwiftModule = Python.import("Swift")

@_cdecl("JKCreateKernel")
public func JKCreateKernel(_ jupyterKernelRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let noneObject = Python.None
    let errorObject = noneObject
    
    let jupyterKernel = PythonObject(jupyterKernelRef)
    jupyterKernel.swift_delegate = SwiftModule.SwiftDelegate()
    
    jupyterKernel.registerFunction(name: "helloC") { params -> PythonConvertible in
        helloC(Int32(params)!)
    }
    
    return SwiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
