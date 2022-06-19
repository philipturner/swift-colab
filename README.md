# Swift-Colab

In March 2021, Google [ended](./Documentation/ColabSupportHistory.md) built-in Swift support on Colaboratory as part of their <s>evil plot</s> attempt to archive [Swift for TensorFlow (S4TF)](https://github.com/tensorflow/swift). Now that new contributors are working on S4TF, Colab support is essential for ensuring that TPU acceleration still works. This repository is the successor to [google/swift-jupyter](https://github.com/google/swift-jupyter), rewritten entirely in Swift.

Swift-Colab is an accessible way to do programming with Swift. It runs in a browser, taking only 30 seconds to start up. It is perfect for programming on Chromebooks and tablets, which do not have the full functionality of a desktop. You can access a free NVIDIA GPU for machine learning, using the real C bindings for OpenCL and CUDA instead of Python wrappers. Soon, you will be able to experiment with the [new S4TF](https://github.com/s4tf/s4tf) as well.

For an in-depth look at how and why this repository was created, check out the [summary of its history](./Documentation/ColabSupportHistory.md).

- [Getting Started](#getting-started)
- [Using Swift-Colab](#using-swift-colab)
- [Installing Packages](#installing-packages)
- [Swift for TensorFlow Integration](#swift-for-tensorflow-integration)
- [SwiftPlot Integration](#swiftplot-integration)
- [Testing](#testing)

## Getting Started

Colab notebooks created directly from Google Drive are tailored for Python programming. When making a Swift notebook, copy the [official template](https://colab.research.google.com/drive/1EACIWrk9IWloUckRm3wu973bKUBXQDKR?usp=sharing) instead. It contains the commands listed below, which download and compile the Jupyter kernel. Run the first code cell and follow the instructions for restarting the runtime.

```swift
!curl "https://raw.githubusercontent.com/philipturner/swift-colab/release/latest/install_swift.sh" --output "install_swift.sh"
!bash "install_swift.sh" "5.6.2" #// Replace 5.6.2 with newest Swift version.
#// After this cell finishes, go to Runtime > Restart runtime.
```

> Tip: If you exceed the time limit of Colab's free tier, it restarts in Python mode. That means Swift code executes as if it's Python code. In that situation, repeat the process outlined above to return to Swift mode.

When Google sponsored S4TF from 2018 - 2021, the Swift community created several Jupyter notebooks. To run those notebooks now, slightly modify them. Create a new cell at the top of each notebook, including the commands shown above*. No further changes are necessary because of Swift-Colab's backward-compatibility. If you experience a problem, please [file an issue](https://github.com/philipturner/swift-colab/issues).

\*For a more future-proof solution, fill that cell with only a comment directing the user to Swift-Colab's repository. Whoever runs the notebook will likely not update the Swift version passed into `install_swift.sh`. I recommend this approach for the [fastai/swiftai](https://github.com/fastai/swiftai) notebooks and anything else that must be maintained indefinitely.

## Using Swift-Colab

Google Colab is like the Swift REPL, but it submits several lines of code at once. Fill the second code cell with the first example below. Run it, and `64` will show. No matter how many lines a cell has, only the last one's return value appears. To get around this restriction, use `print(...)` to display values.

```swift
Int.bitWidth
// Output: (you can include this comment in the cell; it doesn't count as the "last line")
// 64
```

```swift
Int.bitWidth
Int.bitWidth
// Output:
// 64
```

```swift
print(Int.bitWidth)
Int.bitWidth
// Output:
// 64
// 64
```

Swift-Colab has several powerful features, including [magic commands](./Documentation/MagicCommands.md) and [Google Drive integration](./Documentation/GoogleDriveIntegration.md). Unfortunately, they are not fully documented yet. The old swift-jupyter's [usage instructions](https://github.com/google/swift-jupyter#usage-instructions) may be useful in the meantime.

## Installing Packages

To install a Swift package, type `%install` followed by a Swift 4.2-style package declaration. The declaration should appear between two single quotes. After that, type the modules you want to compile. Before importing any module via a Swift `import` statement, execute its `%install` command. You can install packages in any cell, even after other Swift code has executed.

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
```

Upon restarting the runtime, remember to rerun the `%install` command for each package. This command tells the Swift interpreter that the package is ready to be imported. It runs much more quickly than the first time through, because Swift-Colab utilizes cached build products from the previous Jupyter session. Try testing this mechanism by redundantly importing the same package. Make sure both commands match character-for-character!

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
```

## Swift for TensorFlow Integration

Coming in the future! Initial support may come from an old branch of S4TF, not the head branch. This task is tracked by https://github.com/philipturner/swift-colab/issues/15.

<!--
For in the future, when S4TF works in Colab. Either I fix the build system, or I hard-code some way to install the X10 binary.

`%install-x10 TF_VERSION` command? If I change my mind, it's source-breaking.
-->

## SwiftPlot Integration

To use IPython graphs or SwiftPlot plots, enter the magic commands shown below. [`EnableIPythonDisplay.swift`](https://github.com/philipturner/swift-colab/blob/main/Sources/include/EnableIPythonDisplay.swift) depends on the PythonKit and SwiftPlot libraries. SwiftPlot takes 23 seconds to compile, so you may skip its install command unless you intend to use it. However, you must restart the runtime if you change your mind.

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
%install '.package(url: "https://github.com/KarthikRIyer/swiftplot", .branch("master"))' SwiftPlot AGGRenderer
%include "EnableIPythonDisplay.swift"
```

Include `EnableIPythonDisplay.swift` after (rather than before) installing the Swift packages, or else plots will not show. The file injects the following code into the interpreter, gated under multiple import guards. The code samples here do not explicitly import these libraries, as doing so would be redundant. If you do not include `EnableIPythonDisplay.swift`, explicitly import them before running other Swift code.

```swift
import PythonKit
import SwiftPlot
import AGGRenderer
```

For tutorials on using the SwiftPlot API, check out [KarthikRIyer/swiftplot](https://github.com/KarthikRIyer/swiftplot).

## Testing

> Tests are being updated for the v2.2 release. The table below may provide incorrect data at the moment.

These tests ensure that Swift-Colab runs on recent Swift toolchains. Some of them originate from [unit tests](https://github.com/google/swift-jupyter/tree/main/test/tests) in swift-jupyter, while others cover fixed bugs and third-party libraries. If any notebook fails or you have a suggestion for a new test, please [open an issue](https://github.com/philipturner/swift-colab/issues).

To run a test, replace `"5.6.2"` in the first code cell with the newest Swift version. Run the installation commands, then go to `Runtime > Restart runtime`. Click on the second code cell and instruct Colab to execute every cell in the notebook (`Runtime > Run after`). Compare each cell's expected output with its actual output. If a notebook provides additional instructions, read them before running the test.

<!-- Emoji shortcuts for reference: ✅ ❌ -->

<!-- 
TODO: Test Concurrency 

-->

| Test | Passing | Date of Last Test Run | Swift Version |
| ---- | ------- | --------------------- | ------------- |
| [kernel_tests.py](https://colab.research.google.com/drive/1vooU1XVHSpolOSmVUKM4Wj6opEJBt7zs?usp=sharing) | ✅ | June 2022 | 5.6.2 Release |
| [own_kernel_tests.py](https://colab.research.google.com/drive/1nHitEZm9QZNheM-ALajARyRZY2xpZr00?usp=sharing) (outdated) | ✅ | March 2022 | 5.5.3 Release |
| [simple_notebook_tests.py](https://colab.research.google.com/drive/18316eFVMw-NIlA9OandB7djvp0J4jI0-?usp=sharing) (outdated) | ✅ | March 2022 | 5.5.3 Release |
| [SwiftPlot](https://colab.research.google.com/drive/1Rxs7OfuKIJ_hAm2gUQT2gWSuIcyaeZfz?usp=sharing) | ✅ | June 2022 | 5.6.2 Release
| [Swift for TensorFlow](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing) | ✅ | June 2022 | June 13, 2022 v5.7 Development Snapshot |

<!-- 
TODO: Test Concurrency 

-->
