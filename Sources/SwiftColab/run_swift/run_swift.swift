import Foundation
print("swift debug signpost 0")
print("=== Started running Swift string ===")
defer { print("=== Finished running Swift string ===") }

print("Arguments: \(CommandLine.arguments)")

let fm = FileManager.default

// Write script to temporary file


guard let scriptData = String("import Foundation").data(using: .utf8) else {
// guard let scriptData = CommandLine.arguments[1].data(using: .utf8) else {
    enum InvalidStringError: Error {
        case notUTF8
    }
    
    throw InvalidStringError.notUTF8
}

print("swift debug signpost 1")

let targetURL = URL(fileURLWithPath: "/opt/swift/tmp/string_script.swift")

// if fm.fileExists(at: targetURL) {
//     try scriptData.write(to: targetURL, options: .atomic)
// } else {
    print(fm.createFile(atPath: targetURL.path, contents: scriptData))
let readData = fm.contents(atPath: targetURL.path)
print(readData != nil)
// }

print(targetURL.path)
print("swift debug signpost 2")
// Execute script

let executeScript = Process()
executeScript.executableURL = .init(fileURLWithPath: "/usr/bin/env")
executeScript.arguments = ["swift", targetURL.path]
executeScript.currentDirectoryURL = .init(fileURLWithPath: "/content")
print("swift debug signpost 3")

do {
    try executeScript.run()
} catch {
    print(error.localizedDescription)
}

executeScript.waitUntilExit()

exit(0)

print("swift debug signpost 4")
