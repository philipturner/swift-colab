import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let fm = FileManager.default
precondition(fm.currentDirectoryPath == "/swift", "Called `install_swift.swift` when the working directory was not `/swift`.")

extension FileManager {
    func removeItemIfExists(atPath path: String) throws {
        if fileExists(atPath: path) {
            try removeItem(atPath: path)
        }
    }
}

// for key in ProcessInfo.processInfo.environment.keys {
//     print("Environment variable \(key) = \(ProcessInfo.processInfo.environment[key]!)")
// }

// Remove any previously existing `run_swift` files
try fm.removeItemIfExists(atPath: "/swift/run_swift.sh")
try fm.removeItemIfExists(atPath: "/swift/run_swift.swift")

// Move `run_swift` to the `/swift` directory
let baseDirectory = "/swift/swift-colab/Sources/SwiftColab/run_swift"
try fm.moveItem(atPath: "\(baseDirectory)/run_swift.sh", toPath: "/swift/run_swift.sh")
try fm.moveItem(atPath: "\(baseDirectory)/run_swift.swift", toPath: "/swift/run_swift.swift")

// Create directory for temporary files created while executing a Swift script
try fm.createDirectory(atPath: "/swift/tmp", withIntermediateDirectories: true)

// Add `swift` python package to `/env/python` directory
try fm.createDirectory(atPath: "/env/python", withIntermediateDirectories: true)
try fm.createDirectory(atPath: "/env/python/swift", withIntermediateDirectories: true)

let sourcePath = "/swift/swift-colab/PythonPackages/swift"
let targetPath = "/env/python/swift"

try fm.removeItemIfExists(atPath: targetPath)
try fm.moveItem(atPath: sourcePath, toPath: targetPath)



print("swift debug marker 0")



let registerPackage = Process()
registerPackage.executableURL = "/usr/bin/env"
registerPackage.currentDirectoryURL = "/env/python/swift"
registerPackage.arguments = ["pip", "install", "./"]

try registerPackage.run()
registerPackage.waitUntilExit()


print("swift debug marker 1")
