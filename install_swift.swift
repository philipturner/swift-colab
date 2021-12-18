import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let fm = FileManager.default
precondition(fm.currentDirectoryPath == "/swift", "Called `install_swift.swift` when the working directory was not `/swift`.")

// Remove any previously existing `run_swift` files
try fm.removeItem(atPath: "/swift/run_swift.sh")
try fm.removeItem(atPath: "/swift/run_swift.swift")

// Move `run_swift` to the `/swift` directory
try fm.moveItem(atPath: "/swift/swift-colab/run_swift.sh", toPath: "/swift/run_swift.sh")
try fm.moveItem(atPath: "/swift/swift-colab/run_swift.swift", toPath: "/swift/run_swift.swift")

// Create directory for temporary files created while executing a Swift script
try fm.createDirectory(atPath: "/swift/tmp", withIntermediateDirectories: true)
