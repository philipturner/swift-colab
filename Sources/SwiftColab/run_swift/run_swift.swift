import Foundation
print("=== Started running Swift string ===")
defer { print("=== Finished running Swift string ===") }

FileManager.default.changeCurrentDirectoryPath("/contents")

print("Arguments: \(CommandLine.arguments)")
