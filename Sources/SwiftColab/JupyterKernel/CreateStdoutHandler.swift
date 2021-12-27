import Foundation
import PythonKit
import SwiftPythonBridge
fileprivate let SwiftModule = Python.import("Swift")

@_cdecl("JKCreateStdoutHandler")
public func JKCreateStdoutHandler(_ argsRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let noneObject = Python.None
    let errorObject = noneObject
    
    let args = PythonObject(stdoutHandlerRef)
    let (handler, kernel) = (args[0], args[1])
    
    
    return SwiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
