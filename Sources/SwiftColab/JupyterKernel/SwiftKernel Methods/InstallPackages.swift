import Foundation
import PythonKit

fileprivate let os = Python.import("os")

func install_packages(_ selfRef: PythonObject,
                      packages: [PythonObject],
                      swiftpm_flags: [PythonObject],
                      extra_include_commands: [PythonObject],
                      user_install_location: PythonObject?) throws {
    if packages.count == 0 && swiftpm_flags.count == 0 {
        return
    }
    
    if selfRef.checking.debugger != nil {
        throw PackageInstallException(
            "Install Error: Packages can only be installed during the " +
            "first cell execution. Restart the kernel to install packages.")
    }
    
    guard let swift_build_path = os.environ.get("SWIFT_BUILD_PATH") else {
        throw PackageInstallException(
            "Install Error: Cannot install packages because " +
            "SWIFT_BUILD_PATH is not specified.")
    }
}
