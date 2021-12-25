import PythonKit
import SwiftPythonBridge
import Foundation

fileprivate let swiftModule = Python.import("swift")
fileprivate let json = Python.import("json")
fileprivate let os = Python.import("os")

@_cdecl("JKRegisterKernel")
public func JKRegisterKernel() -> Void {
    print()
    print("=== Registering Swift Jupyter kernel ===")
    defer { print("=== Finished registering Swift Jupyter kernel ===") }
    
    let kernel_name: PythonObject = "Swift"
    let kernel_code_name: PythonObject = "swift"
}
