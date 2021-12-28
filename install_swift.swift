import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let fm = FileManager.default
precondition(fm.currentDirectoryPath == "/opt/swift", "Called `install_swift.swift` when the working directory was not `/opt/swift`.")

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

// Copy lldb package to swift-colab/PythonPackages
let lldbSourceDirectory = "/opt/swift/toolchain/usr/lib/python3/dist-packages"
let lldbTargetDirectory = "/opt/swift/swift-colab/PythonPackages/lldb"

for subpath in try fm.contentsOfDirectory(atPath: lldbSourceDirectory) {
    let sourcePath = "\(lldbSourceDirectory)/\(subpath)"
    let targetPath = "\(lldbTargetDirectory)/\(subpath)"
    
    try? fm.copyItem(atPath: sourcePath, toPath: targetPath)
}

// Install Python packages
try fm.createDirectory(atPath: "/env/python", withIntermediateDirectories: true)

let packageSourceDirectory = "/opt/swift/swift-colab/PythonPackages"
let packageMetadata = [
    (name: "Swift", forceReinstall: false),
    (name: "lldb", forceReinstall: true)
]

for metadata in packageMetadata {
    let targetPath = "/env/python/\(metadata.name)"
    
    if metadata.forceReinstall || !fm.fileExists(atPath: targetPath) {
        try fm.createDirectory(atPath: targetPath, withIntermediateDirectories: true)
        
        try? fm.removeItem(atPath: targetPath)
        try fm.moveItem(atPath: "\(packageSourceDirectory)/\(metadata.name)", toPath: targetPath)
        
        try doCommand(["pip", "install", "--use-feature=in-tree-build", "./"], 
                      directory: targetPath)
    }
}

// Move the LLDB binary to Python search path
var pythonSearchPath = "/usr/local/lib"

do {
    var possibleFolders = try fm.contentsOfDirectory(atPath: pythonSearchPath).filter { $0.hasPrefix("python3.") }
    let folderNumbers = possibleFolders.map { $0.dropFirst("python3.".count) }
    let pythonVersion = "python3.\(folderNumbers.max()!)"
    pythonSearchPath += "/\(pythonVersion)/dist-packages"
}

do {
    let sourcePath = "\(lldbSourceDirectory)/lldb/_lldb.so"
    let targetPath = "\(pythonSearchPath)/lldb/_lldb.so"
    
    try? fm.removeItem(atPath: targetPath)
    try fm.createSymbolicLink(atPath: targetPath, withDestinationPath: sourcePath)
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
               "-Onone"],
               directory: "/opt/swift/tmp")
try doCommand(["/opt/swift/tmp/InstallBacktrace"])
*/

// Install philipturner/PythonKit
let pythonKitProductsPath = "/opt/swift/packages/PythonKit/.build/release"
let pythonKitLibPath = "/opt/swift/lib/libPythonKit.so"

try doCommand(["swift", "build", "-c", "release", "-Xswiftc", "-Onone"],
              directory: "/opt/swift/packages/PythonKit")

try? fm.removeItem(atPath: pythonKitLibPath)
try fm.copyItem(atPath: "\(pythonKitProductsPath)/libPythonKit.so", toPath: pythonKitLibPath)

// Install SwiftPythonBridge
let spbProductsPath = "/opt/swift/packages/SwiftPythonBridge"
let spbLibPath = "/opt/swift/lib/libSwiftPythonBridge.so"
let spbSourcePath = "/opt/swift/swift-colab/Sources/SwiftColab/SwiftPythonBridge"

// try fm.removeItemIfExists(atPath: spbProductsPath)
try fm.createDirectory(atPath: spbProductsPath, withIntermediateDirectories: true)

let spbSourceFilePaths = try fm.subpathsOfDirectory(atPath: spbSourcePath).filter {
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

try? fm.removeItem(atPath: spbLibPath)
try fm.copyItem(atPath: "\(spbProductsPath)/libSwiftPythonBridge.so", toPath: spbLibPath)

try doCommand(["patchelf", "--replace-needed", "libPythonKit.so", pythonKitLibPath, spbLibPath])

// Install JupyterKernel
let jupyterProductsPath = "/opt/swift/packages/JupyterKernel"
let jupyterLibPath = "/opt/swift/lib/libJupyterKernel.so"
let jupyterSourcePath = "/opt/swift/swift-colab/Sources/SwiftColab/JupyterKernel"

try? fm.removeItem(atPath: jupyterProductsPath)
try fm.createDirectory(atPath: jupyterProductsPath, withIntermediateDirectories: true)

let jupyterSourceFilePaths = try fm.subpathsOfDirectory(atPath: jupyterSourcePath).filter {
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

try? fm.removeItem(atPath: jupyterLibPath)
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

// Move include files
try? fm.removeItem(atPath: "/opt/swift/include")
try fm.moveItem(atPath: "/opt/swift/swift-colab/Sources/SwiftColab/include", toPath: "/opt/swift/include")
