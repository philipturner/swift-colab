import Foundation

//===----------------------------------------------------------------------===//
// Test Swift Packages (%test)
//===----------------------------------------------------------------------===//

func processTest(
  restOfLine: String, lineIndex: Int
) throws {
  let parsed = try PackageContext.shlexSplit(restOfLine, lineIndex)
  if parsed.count != 1 {
    var sentence: String
    if parsed.count == 0 {
      sentence = "Please enter a specification."
    } else {
      sentence = "Do not enter anything after the specification."
    }
    throw PreprocessorException(lineIndex: lineIndex, message: """
      Usage: %test SPEC
      \(sentence) For more guidance, visit:
      https://github.com/philipturner/swift-colab/blob/main/Documentation/MagicCommands.md#test
      """)
  }
}