import PythonKit
import SwiftPythonBridge
import Foundation

fileprivate let swiftModule = Python.import("swift")
fileprivate let json = Python.import("json")
fileprivate let os = Python.import("os")

fileprivate let KernelSpecManager = Python.import("jupyter_client").kernelspec.KernelSpecManager
fileprivate let TemporaryDirectory = Python.import("IPython").utils.tempdir.TemporaryDirectory
fileprivate let glob = Python.import("glob").glob

@_cdecl("JKRegisterKernel")
public func JKRegisterKernel() -> Void {
    print("=== Registering Swift Jupyter kernel ===")
    defer { print("=== Finished registering Swift Jupyter kernel ===") }
    
    let kernel_name: PythonObject = "Swift"
    let kernel_code_name: PythonObject = "swift"
    
    print(swiftModule)
    print(json)
    print(os)
    
    print(KernelSpecManager)
    print(TemporaryDirectory)
    print(glob)
}
