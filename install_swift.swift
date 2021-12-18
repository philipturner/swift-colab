import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let fm = FileManager.default

fm.moveItem(atPath: "/swift/swift-colab/run_swift.sh", to: "/swift/run_swift.sh")
fm.moveItem(atPath: "/swift/swift-colab/run_swift.swift", to: "/swift/run_swift.swift")
