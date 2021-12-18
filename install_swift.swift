import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let fm = FileManager.default
precondition(fm.currentDirectoryPath == "/swift", "Called `install_swift.swift` when the working directory was not `/swift`.")

func moveToParent(fileName: String) throws {
    let targetPath = "/swift/\(fileName)"
    
    if fm.fileExists(atPath: targetPath) {
        try fm.removeItem(atPath: targetPath)
    }
    
    try fm.moveItem(atPath: "/swift/swift-colab/\(fileName)", to: targetPath)
}

try moveToParent(fileName: "run_swift.sh")
try moveToParent(fileName: "run_swift.swift")

try fm.createDirectory(atPath: "/swift/tmp", withIntermediateDirectories: true)
