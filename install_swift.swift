import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let fm = FileManager.default
precondition(fm.currentDirectoryPath == "/opt/swift", "Called `install_swift.swift` when the working directory was not `/opt/swift`.")

extension FileManager {
    @inline(never)
    func removeItemIfExists(atPath path: String) throws {
        if fileExists(atPath: path) {
            try removeItem(atPath: path)
        }         
    }
}

@inline(never)
func writeString(to target: String, _ contents: String) {
    let contentsData = contents.data(using: .utf8)!
    let contentsURL = URL(fileURLWithPath: target)
    fm.createFile(atPath: contentsURL.path, contents: contentsData)
}

@inline(never)
func doCommand(_ args: [String], directory: String? = nil) throws {
    let command = Process()
    command.executableURL = .init(fileURLWithPath: "/usr/bin/env")
    command.arguments = args
    
    if let directory = directory {
        command.currentDirectoryURL = .init(fileURLWithPath: directory)
    }
    
    try command.run()
    command.waitUntilExit()
}

// Install Python packages
try fm.createDirectory(atPath: "/env/python", withIntermediateDirectories: true)

let packageSourceDirectory = "/opt/swift/swift-colab/PythonPackages"
let packageMetadata = [
    (name: "swift", forceReinstall: false),
]

for metadata in packageMetadata {
    let targetPath = "/env/python/\(metadata.name)"
    
    if metadata.forceReinstall || !fm.fileExists(atPath: targetPath) {
        try fm.createDirectory(atPath: targetPath, withIntermediateDirectories: true)
        
        try fm.removeItemIfExists(atPath: targetPath)
        try fm.moveItem(atPath: "\(packageSourceDirectory)/\(metadata.name)", toPath: targetPath)
        
        try doCommand(["pip", "install", "--use-feature=in-tree-build", "./"], 
                      directory: targetPath)
    }
}

try fm.createDirectory(atPath: "/opt/swift/tmp", withIntermediateDirectories: true)
try fm.createDirectory(atPath: "/opt/swift/lib", withIntermediateDirectories: true)
try fm.createDirectory(atPath: "/opt/swift/packages", withIntermediateDirectories: true)

// Not installing Backtrace because I don't see it helping anything.

/*
// Install philipturner/swift-backtrace
try doCommand(["swift", "build"], directory: "/opt/swift/packages/swift-backtrace")
let backtraceProductsPath = "/opt/swift/packages/swift-backtrace/.build/debug"
try doCommand(["swiftc", "/opt/swift/swift-colab/Sources/SwiftColab/InstallBacktrace.swift",
               "-L", backtraceProductsPath, "-lBacktrace",
               "-I", backtraceProductsPath,
               "-D", "DEBUG"],
               directory: "/opt/swift/tmp")
try doCommand(["/opt/swift/tmp/InstallBacktrace"])
*/

// Install philipturner/PythonKit
let pythonKitProductsPath = "/opt/swift/packages/PythonKit/.build/release"
let pythonKitLibPath = "/opt/swift/lib/libPythonKit.so"

try doCommand(["swift", "build", "-c", "release", "-Xswiftc", "-Onone"],
              directory: "/opt/swift/packages/PythonKit")

try fm.removeItemIfExists(atPath: pythonKitLibPath)
try fm.copyItem(atPath: "\(pythonKitProductsPath)/libPythonKit.so", toPath: pythonKitLibPath)

// Install SwiftPythonBridge
let spbProductsPath = "/opt/swift/packages/SwiftPythonBridge"
let spbLibPath = "/opt/swift/lib/libSwiftPythonBridge.so"
let spbSourcePath = "/opt/swift/swift-colab/Sources/SwiftColab/SwiftPythonBridge"

try fm.removeItemIfExists(atPath: spbProductsPath)
try fm.createDirectory(atPath: spbProductsPath, withIntermediateDirectories: true)

let spbSourceFilePaths = try fm.contentsOfDirectory(atPath: spbSourcePath).filter {
    $0.hasSuffix(".swift")
}.map {
    "\(spbSourcePath)/\($0)"
}

try doCommand(["swiftc", "-Onone"] + spbSourceFilePaths + [
               "-L", pythonKitProductsPath, "-lPythonKit",
               "-I", pythonKitProductsPath,
               "-emit-module", "-emit-library",
               "-module-name", "SwiftPythonBridge"],
               directory: spbProductsPath)

try fm.removeItemIfExists(atPath: spbLibPath)
try fm.copyItem(atPath: "\(spbProductsPath)/libSwiftPythonBridge.so", toPath: spbLibPath)

try doCommand(["patchelf", "--replace-needed", "libPythonKit.so", pythonKitLibPath, spbLibPath])

// Install JupyterKernel
let jupyterProductsPath = "/opt/swift/packages/JupyterKernel"
let jupyterLibPath = "/opt/swift/lib/libJupyterKernel.so"
let jupyterSourcePath = "/opt/swift/swift-colab/Sources/SwiftColab/JupyterKernel"

try fm.removeItemIfExists(atPath: jupyterProductsPath)
try fm.createDirectory(atPath: jupyterProductsPath, withIntermediateDirectories: true)

let jupyterSourceFilePaths = try fm.contentsOfDirectory(atPath: jupyterSourcePath).filter {
    $0.hasSuffix(".swift") 
}.map {
    "\(jupyterSourcePath)/\($0)"
}

try doCommand(["swiftc", "-Onone"] + jupyterSourceFilePaths + [
               "-L", pythonKitProductsPath, "-lPythonKit",
               "-I", pythonKitProductsPath,
               "-L", spbProductsPath, "-lSwiftPythonBridge",
               "-I", spbProductsPath,
               "-emit-module", "-emit-library",
               "-module-name", "JupyterKernel"],
              directory: jupyterProductsPath)

try fm.removeItemIfExists(atPath: jupyterLibPath)
try fm.copyItem(atPath: "\(jupyterProductsPath)/libJupyterKernel.so", toPath: jupyterLibPath)

for pair in [("libPythonKit.so", pythonKitLibPath), ("libSwiftPythonBridge.so", spbLibPath)] {
    try doCommand(["patchelf", "--replace-needed", pair.0, pair.1, jupyterLibPath])
}

// Register Jupyter kernel
guard let libJupyterKernel = dlopen(jupyterLibPath, RTLD_LAZY | RTLD_GLOBAL) else {
    fatalError("Could not load the \(jupyterLibPath) dynamic library")
}

guard let JKRegisterKernelRef = dlsym(libJupyterKernel, "JKRegisterKernel") else {
    fatalError("Could not load the helloC function")
}

typealias JKRegisterKernelType = @convention(c) () -> Void
let JKRegisterKernel = unsafeBitCast(JKRegisterKernelRef, to: JKRegisterKernelType.self)
JKRegisterKernel()
