import Foundation
import PythonKit
import SwiftPythonBridge
fileprivate let SwiftModule = Python.import("Swift")

@_cdecl("JKCreateStdoutHandler")
public func JKCreateStdoutHandler(_ stdoutHandlerRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let noneObject = Python.None
    let errorObject = noneObject
    
    return SwiftModule.SwiftReturnValue(noneObject, errorObject).ownedPyObject
}
