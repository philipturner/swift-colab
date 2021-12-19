import Foundation
print("=== Started running Swift string ===")
defer { print("=== Finished running Swift string ===") }

print("Arguments: \(CommandLine.arguments)")

let fm = FileManager.default

// Write script to temporary file

guard let scriptData = CommandLine.arguments[1].data(using: .utf8) else {
    enum InvalidStringError: Error {
        case notUTF8
    }
    
    throw InvalidStringError.notUTF8
}

let targetURL = URL(fileURLWithPath: "/opt/swift/tmp/string_script.swift")

// if fm.fileExists(at: targetURL) {
//     try scriptData.write(to: targetURL, options: .atomic)
// } else {
    fm.createFile(atPath: targetURL.path, contents: scriptData)
// }


// Execute script

let executeScript = Process()
executeScript.executableURL = .init(fileURLWithPath: "/usr/bin/env")
executeScript.arguments = ["swift", targetURL.path]
executeScript.currentDirectoryURL = .init(fileURLWithPath: "/contents")

try executeScript.run()
executeScript.waitUntilExit()

