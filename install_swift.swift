import Foundation

print("=== Swift successfully downloaded ===")

if let value = ProcessInfo.processInfo.environment["PATH"] {
    print("PATH is \(value)")
} else {
    print("PATH was not found")
}

print("=== Swift successfully installed ===") // try putting this in a defer statement
