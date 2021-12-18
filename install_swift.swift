import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let fm = FileManager.default
precondition(fm.currentDirectoryPath == "/swift", "Called `install_swift.swift` when the working directory was not `/swift`.")

try fm.removeItem(atPath: "/swift/run_swift.sh")
try fm.removeItem(atPath: "/swift/run_swift.swift")

try fm.moveItem(atPath: "/swift/swift-colab/run_swift.sh", toPath: "/swift/run_swift.sh")
try fm.moveItem(atPath: "/swift/swift-colab/run_swift.swift", toPath: "/swift/run_swift.swift")

// func moveToParent(fileName: String) throws {
//     let targetPath = "/swift/\(fileName)"
    
// //     if fm.fileExists(atPath: targetPath) {
//         try fm.removeItem(atPath: targetPath)
// //     }
    
//     try fm.moveItem(atPath: "/swift/swift-colab/\(fileName)", toPath: targetPath)
// }

// try moveToParent(fileName: "run_swift.sh")
// try moveToParent(fileName: "run_swift.swift")



try fm.createDirectory(atPath: "/swift/tmp", withIntermediateDirectories: true)
