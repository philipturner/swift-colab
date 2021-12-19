import Foundation
print("=== Started running Swift string ===")
defer { print("=== Finished running Swift string ===") }

print("Arguments: \(CommandLine.arguments)")

// Write script to temporary file

guard let scriptData = CommandLine.arguments[1].data(using: .utf8) else {
    enum InvalidStringError: Error {
        case notUTF8
    }
    
    throw InvalidStringError.notUTF8
}

let targetURL = URL(fileURLWithPath: "/opt/swift/tmp/string_script.swift")
try scriptData.write(to: targetURL, options: .atomic)

// Execute script

let executeScript = Process()
executeScript.executableURL = .init(fileURLWithPath: "/usr/bin/env")
executeScript.arguments = ["swift", targetURL.path]
executeScript.currentDirectoryURL = .init(fileURLWithPath: "/contents")

try executeScript.run()
executeScript.waitUntilExit()

