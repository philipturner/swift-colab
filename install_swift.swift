import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let fm = FileManager.default
precondition(fm.currentDirectoryPath == "/opt/swift", "Called `install_swift.swift` when the working directory was not `/opt/swift`.")

extension FileManager {
    func removeItemIfExists(atPath path: String) throws {
        if fileExists(atPath: path) {
            try removeItem(atPath: path)
        }
    }
}

#if false
// Log the environment
for key in ProcessInfo.processInfo.environment.keys {
    print("Environment variable \(key) = \(ProcessInfo.processInfo.environment[key]!)")
}
#endif

// Remove any previously existing `run_swift` files
try fm.removeItemIfExists(atPath: "/opt/swift/run_swift.sh")
try fm.removeItemIfExists(atPath: "/opt/swift/run_swift.swift")

// Move `run_swift` to the `/swift` directory
let baseDirectory = "/opt/swift/swift-colab/Sources/SwiftColab/run_swift"
try fm.moveItem(atPath: "\(baseDirectory)/run_swift.sh", toPath: "/opt/swift/run_swift.sh")
try fm.moveItem(atPath: "\(baseDirectory)/run_swift.swift", toPath: "/opt/swift/run_swift.swift")

// Create directory for temporary files created while executing a Swift script
try fm.createDirectory(atPath: "/opt/swift/tmp", withIntermediateDirectories: true)

// Move `swift` Python package to `/env/python` directory
try fm.createDirectory(atPath: "/env/python", withIntermediateDirectories: true)

if !fm.fileExists(atPath: "/env/python/swift") {
    try fm.createDirectory(atPath: "/env/python/swift", withIntermediateDirectories: true)
    
    let sourcePath = "/opt/swift/swift-colab/PythonPackages/swift"
    let targetPath = "/env/python/swift"

    try fm.removeItemIfExists(atPath: targetPath)
    try fm.moveItem(atPath: sourcePath, toPath: targetPath)

    // Register `swift` Python package
    let registerPackage = Process()
    registerPackage.executableURL = .init(fileURLWithPath: "/usr/bin/env")
    registerPackage.currentDirectoryURL = .init(fileURLWithPath: "/env/python/swift")
    registerPackage.arguments = ["pip", "install", "--use-feature=in-tree-build", "./"]

    try registerPackage.run()
    registerPackage.waitUntilExit()
}
