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

// Move `swift` Python package to `/env/python` directory
try fm.createDirectory(atPath: "/env/python", withIntermediateDirectories: true)

if !fm.fileExists(atPath: "/env/python/swift") {
    try fm.createDirectory(atPath: "/env/python/swift", withIntermediateDirectories: true)
    
    let sourcePath = "/opt/swift/swift-colab/PythonPackages/swift"
    let targetPath = "/env/python/swift"

    try fm.removeItemIfExists(atPath: targetPath)
    try fm.moveItem(atPath: sourcePath, toPath: targetPath)
    
    try doCommand(["pip", "install", "--use-feature=in-tree-build", "./"], 
                  directory: "/env/python/swift")
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

try doCommand(["swift", "build", "-c", "release"],
              directory: "/opt/swift/packages/PythonKit")

try fm.removeItemIfExists(atPath: pythonKitLibPath)
try fm.copyItem(atPath: "\(pythonKitProductsPath)/libPythonKit.so", toPath: pythonKitLibPath)

// Install SwiftPythonBridge
let spbProductsPath = "/opt/swift/packages/SwiftPythonBridge"
let spbLibPath = "/opt/swift/lib/libSwiftPythonBridge.so"
let spbSourcePath = "/opt/swift/swift-colab/Sources/SwiftColab/SwiftPythonBridge"

try fm.removeItemIfExists(atPath: spbProductsPath)
try fm.createDirectory(atPath: spbProductsPath, withIntermediateDirectories: true)

let spbSourceFilePaths = try fm.contentsOfDirectory(atPath: spbSourcePath).map {
    "\(spbSourcePath)/\($0)"
}

try doCommand(["swiftc"] + spbSourceFilePaths + [
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

let jupyterSourceFilePaths = try fm.contentsOfDirectory(atPath: jupyterSourcePath).map {
    "\(jupyterSourcePath)/\($0)"
}

try doCommand(["swiftc"] + jupyterSourceFilePaths + [
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
