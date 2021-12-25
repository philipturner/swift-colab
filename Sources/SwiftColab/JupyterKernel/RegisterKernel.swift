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
    try! validate_kernel_env(kernel_env)
    
    let kernel_name: PythonObject = "Swift"
    let kernel_code_name: PythonObject = "swift"
}

/// Returns environment variables that tell the kernel where things are.
fileprivate func make_kernel_env() -> PythonObject {
    let swift_toolchain = "/opt/swift/toolchain"
    
    let kernel_env: PythonObject = [:]
    kernel_env["PYTHONPATH"] = .init("\(swift_toolchain)/usr/lib/python3/dist-packages")
    kernel_env["LD_LIBRARY_PATH"] = .init("\(swift_toolchain)/usr/lib/swift/linux")
    kernel_env["REPL_SWIFT_PATH"] = .init("\(swift_toolchain)/usr/bin/repl_swift")
    kernel_env["SWIFT_BUILD_PATH"] = .init("\(swift_toolchain)/usr/bin/swift-build")
    kernel_env["SWIFT_PACKAGE_PATH"] = .init("\(swift_toolchain)/usr/bin/swift-package")
    
    return kernel_env
}

fileprivate struct Exception: Error {
    var localizedDescription: String

    init(_ localizedDescription: String) { 
        self.localizedDescription = localizedDescription 
    }
}

/// Validates that the env vars refer to things that actually exist.
fileprivate func validate_kernel_env(_ kernel_env: PythonObject) throws {
    guard Bool(os.path.isfile(kernel_env["PYTHONPATH"] + "/lldb/_lldb.so"))! else {
        throw Exception("lldb python libs not found at \(kernel_env["PYTHONPATH"])")
    }
    
    guard Bool(os.path.isfile(kernel_env["REPL_SWIFT_PATH"]))! else {
        throw Exception("repl_swift binary not found at \(kernel_env["REPL_SWIFT_PATH"])")
    }
    
    if let filePath = kernel_env.checking["SWIFT_BUILD_PATH"], !Bool(os.path.isfile(filePath)) {
        throw Exception("swift-build binary not found at \(filePath)")
    }
    
    // for debugging, first check whether a `contains` method on Sequence will help translate the Python if ... in ...
}
