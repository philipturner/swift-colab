import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

let environment = ProcessInfo.processInfo.environment

for key in environment.keys.sorted() {
    print("Environment variable \(key) = \(environment[key]!)")
}

let fm = FileManager.default
