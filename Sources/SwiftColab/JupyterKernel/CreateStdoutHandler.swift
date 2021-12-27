import Foundation
import PythonKit
import SwiftPythonBridge

fileprivate let SwiftModule = Python.import("Swift")
fileprivate let threading = Python.import("threading")

@_cdecl("JKCreateStdoutHandler")
public func JKCreateStdoutHandler(_ argsRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let noneObject = Python.None
    let errorObject = noneObject
    
    let args = PythonObject(stdoutHandlerRef)
    let (handler, kernel) = (args[0], args[1])
    handler.kernel = kernel
    handler.stop_event = threading.Event()
    handler.had_stdout = false
    
    return SwiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
