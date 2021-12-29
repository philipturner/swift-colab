import Foundation
import PythonKit

fileprivate let json = Python.import("json")
fileprivate let os = Python.import("os")
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")
fileprivate let shutil = Python.import("shutil")
fileprivate let sqlite3 = Python.import("sqlite3")
fileprivate let subprocess = Python.import("subprocess")
fileprivate let tempfile = Python.import("tempfile")

fileprivate func encode(_ input: PythonObject) throws -> PythonObject {
    try json.dumps.throwing.dynamicallyCall(withArguments: input)
}

fileprivate func decode(_ input: PythonObject) throws -> PythonObject {
    try json.loads.throwing.dynamicallyCall(withArguments: input)
}

func install_packages(_ selfRef: PythonObject, packages: [PythonObject], swiftpm_flags: [PythonObject], extra_include_commands: [PythonObject], user_install_location: PythonObject?) throws {
    if packages.count == 0 && swiftpm_flags.count == 0 {
        return
    }
    
    if selfRef.checking.debugger != nil {
        throw PackageInstallException(
            "Install Error: Packages can only be installed during the " +
            "first cell execution. Restart the kernel to install packages.")
    }
    
    let swift_toolchain = "/opt/swift/toolchain"
    let swift_build_path = PythonObject("\(swift_toolchain)/usr/bin/swift-build")
    let swift_package_path = PythonObject("\(swift_toolchain)/usr/bin/swift-package")
    
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
        
        if Int(returncode)! != 0 {
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
            packages_products += "\(try encode(target)),\n"
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

    try send_response("Installing packages:\n\(packages_human_description)")
    try send_response("With SwiftPM flags: \(swiftpm_flags)\n")
    try send_response("Working in: \(scratchwork_base_path)\n")

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
    
    let swiftpm_env = os.environ
    let libuuid_path: PythonObject = "/lib/x86_64-linux-gnu/libuuid.so.1"
    swiftpm_env["LD_PRELOAD"] = libuuid_path
    
    guard Bool(os.path.isfile(libuuid_path))! else {
        fatalError("The library \(libuuid_path) was not found!")
    }
    
    let build_p = subprocess.Popen([swift_build_path] + swiftpm_flags,
                                   stdout: subprocess.PIPE,
                                   stderr: subprocess.STDOUT,
                                   cwd: package_base_path,
                                   env: swiftpm_env)
    
    for build_output_line in Python.iter(build_p.stdout.readline, PythonBytes(Data())) {
        try send_response(String(build_output_line.decode("utf8"))!)
    }
    
    let build_returncode = build_p.wait()
    guard Int(build_returncode)! == 0 else {
        throw PackageInstallException(
            "Install Error: swift-build returned nonzero exit code \(build_returncode)")
    }
    
    let show_bin_path_result = subprocess.run([swift_build_path, "--show-bin-path"] + swiftpm_flags,
                                              stdout: subprocess.PIPE, 
                                              stderr: subprocess.PIPE,
                                              cwd: package_base_path)
    let bin_dir = show_bin_path_result.stdout.decode("utf8").strip()
    let lib_filename = os.path.join(bin_dir, "libjupyterInstalledPackages.so")
    
    // == Copy .swiftmodule and modulemap files to SWIFT_IMPORT_SEARCH_PATH ==
    
    // Search for build.db
    let db_candidates = Python.filter(os.path.exists, [
        os.path.join(bin_dir, "..", "build.db"),
        os.path.join(package_base_path, ".build", "build.db"),
    ])
    let build_db_file = Python.next(db_candidates, Python.None)
    guard build_db_file != Python.None else {
        throw PackageInstallException("build.db is missing")
    }
    
    // Execute swift-package show-dependencies to get all dependencies' paths
    let dependencies_result = subprocess.run([swift_package_path, "show-dependencies", "--format", "json"],
                                             stdout: subprocess.PIPE, 
                                             stderr: subprocess.PIPE,
                                             cwd: package_base_path)
    let dependencies_json = dependencies_result.stdout.decode("utf8")
    let dependencies_obj = try decode(dependencies_json)
    
    func flatten_deps_paths(_ dep: PythonObject) -> PythonObject {
        let paths: PythonObject = [dep["path"]]
        
        if let dependencies = dep.checking["dependencies"] {
            for d in dependencies {
                paths.extend(flatten_deps_paths(d))
            }
        }
        
        return paths
    }
    
    // Make list of paths where we expect .swiftmodule and .modulemap files of dependencies
    var dependencies_paths = flatten_deps_paths(dependencies_obj)
    dependencies_paths = Python.list(Python.set(dependencies_paths))
    
    func is_valid_dependency(_ path: PythonObject) -> Bool {
        for p in dependencies_paths {
            if Bool(path.startswith(p))! {
                return true
            }
        }
        
        return false
    }
    
    // Query to get build files list from build.db
    // SUBSTR because string starts with "N" (why?)
    let SQL_FILES_SELECT = "SELECT SUBSTR(key, 2) FROM 'key_names' WHERE key LIKE ?"
    
    // Connect to build.db
    let db_connection = sqlite3.connect(build_db_file)
    let cursor = db_connection.cursor()
    
    func queryDatabase(_ input: String) -> [PythonObject] {
        cursor.execute(SQL_FILES_SELECT, [input])
        return cursor.fetchall().map { $0[0] }.filter(is_valid_dependency)
    }
    
    // Process *.swiftmodules files
    let swift_modules = queryDatabase("%.swiftModule")
    for filename in swift_modules {
        shutil.copy(filename, swift_module_search_path)
    }
    
    // Process modulemap files
    let modulemap_files = queryDatabase("%/module.modulemap")
    for index in 0..<modulemap_files.count {
        let filename = modulemap_files[index]
        // Create a separate directory for each modulemap file because the
        // ClangImporter requires that they are all named
        // "module.modulemap".
        // Use the module name to prevent two modulemaps for the same
        // dependency ending up in multiple directories after several
        // installations, causing the kernel to end up in a bad state.
        // Make all relative header paths in module.modulemap absolute
        // because we copy file to different location.
        
        let (src_folder, src_filename) = os.path[dynamicMember: "split"](filename).tuple2
        let file = Python.open(filename, encoding: "utf8")
        defer { file.close() }
        
        var modulemap_contents = file.read()
        modulemap_contents = re.sub(
            ###"""
            header\s+"(.*?)"
            """###,
            selfRef.lambda1(src_folder),
            modulemap_contents
        )
        
        let module_match = re.match(###"""
                                    module\s+([^\s]+)\s.*{
                                    """###, modulemap_contents)
        let module_name = (module_match != Python.None) ? module_match.group(1) : Python.str(index)
        let modulemap_dest = os.path.join(swift_module_search_path, "modulemap-\(module_name)")
        os.makedirs(modulemap_dest, exist_ok: true)
        
        let dst_path = os.path.join(modulemap_dest, src_filename)
        let outfile = Python.open(dst_path, "w", encoding: "utf8")
        outfile.write(modulemap_contents)
        outfile.close()
    }
    
    // == dlopen the shared lib ==
    try send_response("Initializing Swift...\n")
    try init_swift(selfRef)
    
    let dynamic_load_code = PythonObject("""
    import func Glibc.dlopen
    import var Glibc.RTLD_NOW
    dlopen(\(try encode(lib_filename)), RTLD_NOW)
    """)
    let dynamic_load_result = execute(selfRef, code: dynamic_load_code)
    guard let dynamic_load_result = dynamic_load_result as? SuccessWithValue else {
        throw PackageInstallException("Install error: dlopen crashed: \(dynamic_load_result)")
    }
    
    if Bool(dynamic_load_result.value_description().endswith("nil"))! {
        let error = execute(selfRef, code: "String(cString: dlerror())")
        throw PackageInstallException("Install error: dlopen returned `nil`: \(String(describing: error))")
    }
    
//     guard let _ = dlopen(String(lib_filename)!, RTLD_NOW) else {
//         throw PackageInstallException("Install error: dlopen error: \(String(cString: dlerror()))")
//     }
    
    try send_response("Installation complete!\n")
    selfRef.already_installed_packages = true
}
