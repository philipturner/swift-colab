import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

print("debug signpost 1")

let fm = FileManager.default
precondition(fm.currentDirectoryPath == "/swift", "Called `install_swift.swift` when the working directory was not `/swift`.")

extension FileManager {
    func removeItemIfExists(atPath path: String) throws {
        if fileExists(atPath: path) {
            try removeItem(atPath: path)
        }
    }
}

// Remove any previously existing `run_swift` files
try fm.removeItemIfExists(atPath: "/swift/run_swift.sh")
try fm.removeItemIfExists(atPath: "/swift/run_swift.swift")


print("debug signpost 2")

// Move `run_swift` to the `/swift` directory
try fm.moveItem(atPath: "/swift/swift-colab/run_swift.sh", toPath: "/swift/run_swift.sh")
try fm.moveItem(atPath: "/swift/swift-colab/run_swift.swift", toPath: "/swift/run_swift.swift")

// Create directory for temporary files created while executing a Swift script
try fm.createDirectory(atPath: "/swift/tmp", withIntermediateDirectories: true)

print("debug signpost 3")

// Add `swift` python module to global search path
try fm.createDirectory(atPath: "/env/python", withIntermediateDirectories: true)
try fm.removeItemIfExists(atPath: "/env/python/swift")
// try fm.moveItem(atPath: "/swift/swift-colab/PythonPa

print("debug signpost 4")

print("Testing contentsOfDirectory method")
print(try fm.contentsOfDirectory(atPath: "/swift/swift-colab/PythonPackages"))

print("debug signpost 5")

print("Testing subpaths method")
print(try fm.subpaths(atPath: "/swift/swift-colab/PythonPackages"))
