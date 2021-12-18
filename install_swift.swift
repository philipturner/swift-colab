import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

if let value = ProcessInfo.processInfo.environment["PYTHONHOME"] {
    print("PYTHONHOME is \(value)")
} else {
    print("PYTHONHOME was not found")
}
