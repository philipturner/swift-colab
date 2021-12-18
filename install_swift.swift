import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

if let value = ProcessInfo.processInfo.environment["PATH"] {
    print("PATH is \(value)")
} else {
    print("PATH was not found")
}
