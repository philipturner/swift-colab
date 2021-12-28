import Foundation
import PythonKit

fileprivate let json = Python.import("json")
fileprivate let os = Python.import("os")
fileprivate let shlex = Python.import("shlex")
fileprivate let shutil = Python.import("shutil")
fileprivate let sqlite3 = Python.import("sqlite3")
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
    
    let build_p = subprocess.Popen([swift_build_path] + swiftpm_flags,
                                   stdout: subprocess.PIPE,
                                   stderr: subprocess.STDOUT,
                                   cwd: package_base_path)
    
    for build_output_line in Python.iter(build_p.stdout.readline, PythonBytes(Data())) {
        try send_response(String(build_output_line.decode("utf8"))!)
    }
    
    let build_returncode = build_p.wait()
    guard build_returncode != 0 else {
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
    let build_db_candidates = [
        os.path.join(bin_dir, "..", "build.db"),
        os.path.join(package_base_path, ".build", "build.db"),
    ]
    let filtered_db_candidates = Python.filter(os.path.exists, build_db_candidates)
    guard let build_db_file = Optional(Python.next(filtered_db_candidates, Python.None)) else {
        throw PackageInstallException("build.db is missing")
    }
    
    // Execute swift-package show-dependencies to get all dependencies' paths
    let dependencies_result = subprocess.run([swift_package_path, "show-dependencies", "--format", "json"],
                                             stdout: subprocess.PIPE, 
                                             stderr: subprocess.PIPE,
                                             cwd: package_base_path)
    let dependencies_json = dependencies_result.stdout.decode("utf8")
    let dependencies_obj = json.loads(dependencies_json)
    
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
    }
}
