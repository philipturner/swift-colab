import Foundation
import PythonKit
import SwiftPythonBridge
fileprivate let SwiftModule = Python.import("Swift")

@_cdecl("JKCreateKernel")
public func JKCreateKernel(_ jupyterKernelRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let noneObject = Python.None
    var errorObject = noneObject
    
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
    // `init_swift`).
    
    // Whether to do code completion. Since the debugger is not yet
    // initialized, we can't do code completion yet.
    kernel.completion_enabled = false
    
    kernel.swift_delegate = SwiftModule.SwiftDelegate()
    kernel.registerFunction(name: "do_execute", function: do_execute)
    kernel.registerFunction(name: "do_complete", function: do_complete)
    
    func doCommand(_ args: [String], directory: String? = nil) throws {
        let command = Process()
        command.executableURL = .init(fileURLWithPath: "/usr/bin/env")
        command.arguments = args

        if let directory = directory {
            command.currentDirectoryURL = .init(fileURLWithPath: directory)
        }

        try command.run()
        command.waitUntilExit()
    }
    
    do {
        try doCommand(["/opt/swift/toolchain/usr/bin/sourcekit-lsp"])
    } catch {
        errorObject = SwiftModule.SwiftError(error.localizedDescription)
    }
    
    return SwiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
