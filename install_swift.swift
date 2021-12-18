import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let fm = FileManager.default

try fm.moveItem(atPath: "/swift/swift-colab/run_swift.sh", toPath: "/swift/run_swift.sh")
try fm.moveItem(atPath: "/swift/swift-colab/run_swift.swift", toPath: "/swift/run_swift.swift")
