import Foundation
import PythonKit
import SwiftPythonBridge
fileprivate let SwiftModule = Python.import("Swift")

@_cdecl("JKCreateKernel")
public func JKCreateKernel(_ jupyterKernelRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let noneObject = Python.None
    let errorObject = noneObject
    
    let kernel = PythonObject(jupyterKernelRef)
    kernel.implementation = "SwiftKernel"
    kernel.implementation_version = "0.1"
    kernel.banner = ""
    
    kernel.language_info = [
        "name": "swift",
        "mimetype": "text/x-swift",
        "file_extension": ".swift",
        "version": ""
    ]
    
    // We don't initialize Swift yet, so that the user has a chance to
    // "%install" packages before Swift starts. (See doc comment in
    // `_init_swift`).
    
    // Whether to do code completion. Since the debugger is not yet
    // initialized, we can't do code completion yet.
    kernel.completion_enabled = false
    
    kernel.swift_delegate = SwiftModule.SwiftDelegate()
    kernel.registerFunction(name: "do_execute", function: doExecute)
    kernel.registerFunction(name: "do_complete", function: doComplete)
    
    return SwiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
