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

let sourceURL = URL(fileURLWithPath: "/swift/swift-colab/PythonPackages")
let targetURL = URL(fileURLWithPath: "/env/python")

for package in try fm.contentsOfDirectory(atPath: sourceURL.path) {
    print("Registering Python package \"\(package)\"")
    let packageSourceURL = sourceURL.appendingPathComponent(package)
    let packageTargetURL = targetURL.appendingPathComponent(package)
    
    try fm.removeItemIfExists(atPath: packageTargetURL.path)
    try fm.moveItem(at: packageSourceURL, to: packageTargetURL)
    
    // Register Python package
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.currentDirectoryURL = packageTargetURL
    process.arguments = ["python", "setup.py", "sdist", "bdist_wheel"]
    
    try process.run()
    process.waitUntilExit()
}

print("Finished Swift script. Current working directory is \(fm.currentDirectoryPath)")

// fm.changeCurrentDirectoryPath("/swift")
