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
    
    let kernel_env = make_kernel_env()
    
    let kernel_name: PythonObject = "Swift"
    let kernel_code_name: PythonObject = "swift"
    
    
}

func make_kernel_env() -> PythonObject {
    let swift_toolchain = "/opt/swift/toolchain"
    
    let kernel_env: PythonObject = [:]
    kernel_env["PYTHONPATH"] = "\(swift_toolchain)/usr/lib/python3/dist-packages"
    kernel_env["LD_LIBRARY_PATH"] = "\(swift_toolchain)/usr/lib/swift/linux"
    kernel_env["REPL_SWIFT_PATH"] = "\(swift_toolchain)/usr/bin/repl_swift"
    kernel_env["SWIFT_BUILD_PATH"] = "\(swift_toolchain)/usr/bin/swift-build"
    kernel_env["SWIFT_PACKAGE_PATH"] = "\(swift_toolchain)/usr/bin/swift-package"
    
    return kernel_env
}
