// to be compiled into the dylib and called by the install_swift script, synchronizing its output with shell (need to ensure that's the case)

import PythonKit
import SwiftPythonBridge
import Foundation
fileprivate let swiftModule = Python.import("swift")

@_cdecl("JupyterKernelRegister")
public func JupyterKernelRegister() -> Void {
    print(swiftModule.SwiftReturnValue)
    print(52)
}
