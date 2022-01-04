import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let shouldReinstall = CommandLine.arguments[1] == "true"

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
let shouldUpdateLLDB = CommandLine.arguments[2] == "false"

if shouldUpdateLLDB {
    for subpath in try fm.contentsOfDirectory(atPath: lldbSourceDirectory) {
        let sourcePath = "\(lldbSourceDirectory)/\(subpath)"
        let targetPath = "\(lldbTargetDirectory)/\(subpath)"

        try? fm.copyItem(atPath: sourcePath, toPath: targetPath)
    }
}

// Install Python packages
try fm.createDirectory(atPath: "/env/python", withIntermediateDirectories: true)

let packageSourceDirectory = "/opt/swift/swift-colab/PythonPackages"
let packageMetadata = [
    (name: "Swift", forceReinstall: false),
    (name: "lldb", forceReinstall: shouldReinstall && shouldUpdateLLDB)
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

print("debug checkpoint 3")

// Move the LLDB binary to Python search path

let lldbSymbolicLinkPath = "/opt/swift/toolchain/usr/lib/liblldb.so"

if shouldUpdateLLDB {
    var targetPath = "/usr/local/lib"
    
    let possibleFolders = try fm.contentsOfDirectory(atPath: targetPath).filter { $0.hasPrefix("python3.") }
    let folderNumbers = possibleFolders.map { $0.dropFirst("python3.".count) }
    let pythonVersion = "python3.\(folderNumbers.max()!)"
    
    targetPath += "/\(pythonVersion)/dist-packages/lldb/_lldb.so"
    
    try? fm.removeItem(atPath: targetPath)
    try fm.createSymbolicLink(atPath: targetPath, withDestinationPath: lldbSymbolicLinkPath)
    
    // Save LLDB files that aren't included in debug toolchains
    
    let saveDirectory = "/opt/swift/save-lldb"
    try fm.createDirectory(atPath: saveDirectory, withIntermediateDirectories: true)
}

do {
    var sourceDirectory = "/opt/swift/toolchain/usr/lib"
    var targetDirectory = "/opt/swift/save-lldb"
    let tempVar = try? fm.destinationOfSymbolicLink(atPath: "/opt/swift/toolchain/usr/lib/liblldb.so")
    print(tempVar ?? "no link")
    let tempVar2 = try? fm.destinationOfSymbolicLink(atPath: tempVar ?? "")
    print(tempVar2 ?? "no link")
    try fm.createDirectory(atPath: targetDirectory, withIntermediateDirectories: true)
    
    if !shouldUpdateLLDB {
        swap(&sourceDirectory, &targetDirectory)
    }
    
    for libFile in try fm.contentsOfDirectory(atPath: sourceDirectory).filter({ $0.starts(with: "liblldb") }) {
        let sourceLibFilePath = "\(sourceDirectory)/\(libFile)"
        let targetLibFilePath = "\(targetDirectory)/\(libFile)"
        
        do {
            try fm.copyItem(atPath: sourceLibFilePath, toPath: targetLibFilePath)
        } catch {
            print("Couldn't copy an LLDB lib file: \(error.localizedDescription)")
        }
    }
}

print("debug checkpoint 4")

try fm.createDirectory(atPath: "/opt/swift/tmp", withIntermediateDirectories: true)
try fm.createDirectory(atPath: "/opt/swift/lib", withIntermediateDirectories: true)
try fm.createDirectory(atPath: "/opt/swift/packages", withIntermediateDirectories: true)

// Install philipturner/PythonKit
let pythonKitProductsPath = "/opt/swift/packages/PythonKit/.build/release"
let pythonKitLibPath = "/opt/swift/lib/libPythonKit.so"

try doCommand(["swift", "build", "-c", "release", "-Xswiftc", "-Onone"],
              directory: "/opt/swift/packages/PythonKit")

try? fm.removeItem(atPath: pythonKitLibPath)
try fm.copyItem(atPath: "\(pythonKitProductsPath)/libPythonKit.so", toPath: pythonKitLibPath)

print("debug checkpoint 5")

// Install SwiftPythonBridge
let spbProductsPath = "/opt/swift/packages/SwiftPythonBridge"
let spbLibPath = "/opt/swift/lib/libSwiftPythonBridge.so"
let spbSourcePath = "/opt/swift/swift-colab/Sources/SwiftColab/SwiftPythonBridge"

if shouldReinstall {
    try? fm.removeItem(atPath: spbProductsPath)
}
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
