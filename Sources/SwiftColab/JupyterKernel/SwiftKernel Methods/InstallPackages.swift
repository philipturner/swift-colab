import Foundation
import PythonKit

fileprivate let json = Python.import("json")
fileprivate let os = Python.import("os")
fileprivate let shlex = Python.import("shlex")
fileprivate let subprocess = Python.import("subprocess")
fileprivate let tempfile = Python.import("tempfile")

func install_packages(_ selfRef: PythonObject, packages: [PythonObject], swiftpm_flags: [PythonObject], extra_include_commands: [PythonObject], user_install_location: PythonObject?) throws {
    if packages.count == 0 && swiftpm_flags.count == 0 {
        return
    }
    
    if selfRef.checking.debugger != nil {
        throw PackageInstallException(
            "Install Error: Packages can only be installed during the " +
            "first cell execution. Restart the kernel to install packages.")
    }
    
    guard let swift_build_path = Optional(os.environ.get("SWIFT_BUILD_PATH")) else {
        throw PackageInstallException(
            "Install Error: Cannot install packages because " +
            "SWIFT_BUILD_PATH is not specified.")
    }
    
    guard let swift_package_path = Optional(os.environ.get("SWIFT_PACKAGE_PATH")) else {
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
        
        try call_unlink(link_name: scratchwork_base_path)
        os.symlink(user_install_location, scratchwork_base_path, target_is_directory: true)
    }
    
    // Make the directory containing our synthesized package.
    os.makedirs(package_base_path, exist_ok: true)
    
    // Make the directory containing our built modules and other includes.
    os.makedirs(swift_module_search_path, exist_ok: true)
    
    // Make links from the install location to extra includes.
    for include_command in extra_include_commands {
        let result = subprocess.run(include_command, shell: true,
                                    stdout: subprocess.PIPE,
                                    stderr: subprocess.PIPE)
        
        let returncode = result.returncode
        let stdout = result.stdout.decode("utf8")
        
        if returncode != 0 {
            let stderr = result.stderr.decode("utf8")
            
            throw PackageInstallException(
                "%install-extra-include-command returned nonzero " +
                "exit code: \(returncode)\nStdout:\n\(stdout)\nStderr:\n\(stderr)\n")
        }
        
        let include_dirs = shlex[dynamicMember: "split"](stdout)
        
        for var include_dir in include_dirs {
            if include_dir[0..<2] != "-I" {
                selfRef.log.warn(
                    "Non \"-I\" output from " + 
                    "%install-extra-include-command: \(include_dir)")
                continue
            }
            
            include_dir = include_dir[2...]
            try link_extra_includes(selfRef, swift_module_search_path, include_dir)
        }
        
        // Summary of how this works:
        // - create a SwiftPM package that depends on all the packages that
        //   the user requested
        // - ask SwiftPM to build that package
        // - copy all the .swiftmodule and module.modulemap files that SwiftPM
        //   created to SWIFT_IMPORT_SEARCH_PATH
        // - dlopen the .so file that SwiftPM created
        
        // == Create the SwiftPM package ==
        
        var packages_specs = ""
        var packages_products = ""
        var packages_human_description = ""
        
        for package in packages {
            let spec = package["spec"]
            packages_specs += "\(spec),\n"
            packages_human_description += "\t\(spec)\n"
            
            for target in package["products"] {
                packages_products += "\(json.dumps(target)),\n"
                packages_human_description += "\t\t\(target)\n"
            }
        }
        
        let iopub_socket = selfRef.iopub_socket
        
        func send_response(_ message: String) throws {
            let function = selfRef.send_response.throwing
            try function.dynamicallyCall(withArguments: iopub_socket, "stream", [
                "name": "stdout",
                "text": message
            ])
        }
        
        send_response("Installing packages:\n\(packages_human_description)")
        send_response("With SwiftPM flags: \(swiftpm_flags)\n")
        send_response("Working in: \(scratcwork_base_path)\n")
        
        let package_swift = """
        // swift-tools-version:4.2
        import PackageDescription
        let package = Package(
            name: "jupyterInstalledPackages",
            products: [
                .library(
                    name: "jupyterInstalledPackages",
                    type: .dynamic,
                    targets: ["jupyterInstalledPackages"]),
            ],
            dependencies: [\(packages_specs)],
            targets: [
                .target(
                    name: "jupyterInstalledPackages",
                    dependencies: [\(packages_products)],
                    path: ".",
                    sources: ["jupyterInstalledPackages.swift"]),
            ]
        )
        """
        
        do {
            var f = Python.open("\(package_base_path)/Package.swift", "w")
            f.write(package_swift)
            f.close()
            
            f = Python.open("\(package_base_path)/jupyterInstalledPackages.swift", "w")
            f.write("// intentionally blank")
            f.close()
        }
        
        // == Ask SwiftPM to build the package ==
        
        
    }
}
