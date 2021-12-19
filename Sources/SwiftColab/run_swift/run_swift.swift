import Foundation
print("=== Running Swift string ===")
defer { print("=== Finished running Swift string ===") }

FileManager.default.currentDirectoryPath = "/contents"

print("Arguments: \(CommandLine.arguments)")
