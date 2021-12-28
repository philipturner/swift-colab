import Foundation
import PythonKit

fileprivate let os = Python.import("os")
fileprivate let tempfile = Python.import("tempfile")

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
    
    guard let swift_package_path = os.environ.get("SWIFT_PACKAGE_PATH") else {
        throw PackageInstallException(
            "Install Error: Cannot install packages because " +
            "SWIFT_PACKAGE_PATH is not specified.")
    }
    
    var package_install_scratchwork_base = tempfile.mkdtemp()
    package_install_scratchwork_base = os.path.join(package_install_scratchwork_base, "swift-install")
    
    let swift_module_search_path = os.path.join(package_install_scratchwork_base, "modules")
    selfRef.swift_module_search_path = swift_module_search_path
    
    let scratchwork_base_path = os.path.dirname(swift_module_search_path)
    let package_base_path = os.path.join(scratchwork_base_path, "package")
    
    // If the user has specified a custom install location, make a link from
    // the scratchwork base path to it.
    if let user_install_location = user_install_location {
        // symlink to the specified location
        // Remove existing base if it is already a symlink
        os.makedirs(user_install_location, exist_ok: true)
    }
}
