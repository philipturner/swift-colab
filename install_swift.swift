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

// Remove any previously existing `run_swift` files
try fm.removeItemIfExists(atPath: "/swift/run_swift.sh")
try fm.removeItemIfExists(atPath: "/swift/run_swift.swift")

// Move `run_swift` to the `/swift` directory
try fm.moveItem(atPath: "/swift/swift-colab/run_swift.sh", toPath: "/swift/run_swift.sh")
try fm.moveItem(atPath: "/swift/swift-colab/run_swift.swift", toPath: "/swift/run_swift.swift")

// Create directory for temporary files created while executing a Swift script
try fm.createDirectory(atPath: "/swift/tmp", withIntermediateDirectories: true)

// Add `swift` python module to global search path
try fm.createDirectory(atPath: "/env/python", withIntermediateDirectories: true)
// try fm.removeItemIfExists(atPath: "/env/python/swift") --- execute this command in the code below
// try fm.moveItem(atPath: "/swift/swift-colab/PythonPa

let sourceURL = URL(fileURLWithPath: "/swift/swift-colab/PythonPackages")
let targetURL = URL(fileURLWithPath: "/env/python")

for package in try fm.contentsOfDirectory(atPath: sourceURL.path) {
    print("Downloaded Python package `\(package)`, must move to global search path")
    print("Source will be \(sourceURL.appendingPathComponent(package))")
    print("Target will be \(targetURL.appendingPathComponent(package))")
    
    let packageSourceURL = sourceURL.appendingPathComponent(package)
    let packageTargetURL = targetURL.appendingPathComponent(package)
    
    try fm.removeItemIfExists(atPath: packageSourceURL.path)
    try fm.moveItem(at: packageSourceURL, to: packageSourceURL)
}
