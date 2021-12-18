import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

// if let value = ProcessInfo.processInfo.environment["PYTHONHOME"] {
//     print("PYTHONHOME is \(value)")
// } else {
//     print("PYTHONHOME was not found")
// }

let environment = ProcessInfo.processInfo.environment

for key in environment.keys.sorted() {
    print("Environment variable \(key) = \(environment[key])")
}
