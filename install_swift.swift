import Foundation

print()
print("=== Swift successfully downloaded ===")
defer { print("=== Swift successfully installed ===") }

// Show environment

let environment = ProcessInfo.processInfo.environment

for key in environment.keys.sorted() {
    print("Environment variable \(key) = \(environment[key]!)")
}

// Investigate the Python directory

let fm = FileManager.default

do {
    let pathContents = try fm.contentsOfDirectory(atPath: "/env")
    print(pathContents)
} catch {
    print("Couldn't find path contents: \(error.localizedDescription)")
}
