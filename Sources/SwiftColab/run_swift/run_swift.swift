import Foundation
print("=== Started running Swift string ===")
defer { print("=== Finished running Swift string ===") }

print("Arguments: \(CommandLine.arguments)")

// Write the script to temporary file

guard let scriptData = CommandLine.arguments[1].data(using: .utf8) else {
    enum InvalidStringError: Error {
        case wasNotUTF8
    }
    
    throw InvalidStringError()
}

let targetURL = URL(fileURLWithPath: "/opt/swift/tmp/string_script.swift")
try scriptData.write(to: targetURL, options: .atomic)

print("successfully wrote string script")

// Execute the script

FileManager.default.changeCurrentDirectoryPath("/contents")


