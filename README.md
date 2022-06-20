# Swift-Colab

In March 2021, Google [ended](./Documentation/ColabSupportHistory.md) built-in Swift support on Colaboratory as part of their <s>evil plot</s> attempt to archive [Swift for TensorFlow (S4TF)](https://github.com/tensorflow/swift). Now that new contributors are working on S4TF, Colab support is essential for ensuring that TPU acceleration still works. This repository is the successor to [google/swift-jupyter](https://github.com/google/swift-jupyter), rewritten entirely in Swift.

Swift-Colab is an accessible way to do programming with Swift. It runs in a browser, taking only 30 seconds to start up. It is perfect for programming on Chromebooks and tablets, which do not have the full functionality of a desktop. You can access a free NVIDIA GPU for machine learning, using the real C bindings for OpenCL and CUDA instead of Python wrappers. Soon, you will be able to experiment with the [new S4TF](https://github.com/s4tf/s4tf) as well.

For an in-depth look at how and why this repository was created, check out the [summary of its history](./Documentation/ColabSupportHistory.md).

- [Getting Started](#getting-started)
- [Using Swift-Colab](#using-swift-colab)
- [Installing Packages](#installing-packages)
- [SwiftPlot Integration](#swiftplot-integration)
- [Swift for TensorFlow Integration](#swift-for-tensorflow-integration)
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

## Swift for TensorFlow Integration

The build setup for S4TF is a bit complex. The easiest way to use it is to copy the [Swift for TensorFlow test notebook](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing). To configure it manually, read the instructions below.

Swift for TensorFlow does not compile on release toolchains, so choose a Swift development toolchain. A bug in the main branch of Swift's GitHub repository [prevents S4TF from compiling](https://github.com/apple/swift/issues/59467), but luckily a few snapshots were released before the bug was exposed. Also, every snapshot created from the `release/5.7` branch works. Some of the snapshots you can choose are:

- May 4, 2022 Trunk Development Snapshot
- May 11, 2022 Trunk Development Snapshot
- May 15, 2022 v5.7 Development Snapshot
- June 13, 2022 v5.7 Development Snapshot

Modify the install command at the very top of your Colab notebook. The second line of the first code cell says "Replace 5.6.2 with newest Swift version." Delete `"5.6.2"` and replace it with your chosen snapshot. If you chose the May 11, 2022 snapshot, you should have:

```swift
!bash "install_swift.sh" "2022-05-11" #// Replace 5.6.2 with newest Swift version.
```

Colab lets you easily download trunk snapshots by typing their date. But for v5.7 snapshots, you must enter the entire URL. Go to [swift.org/download](https://www.swift.org/download) and scroll to "Swift 5.7 Development". Right-click the "x86_64" link for Ubuntu 18.04 and paste it into the notebook.

```swift
!bash "install_swift.sh" "https://download.swift.org/swift-5.7-branch/ubuntu1804/swift-5.7-DEVELOPMENT-SNAPSHOT-2022-06-13-a/swift-5.7-DEVELOPMENT-SNAPSHOT-2022-06-13-a-ubuntu18.04.tar.gz" #// Replace 5.6.2 with newest Swift version.
```

Execute the installation script and go to `Runtime > Restart runtime`. The next cell will download the CTensorFlow/X10 binary, created from [tensorflow/tensorflow](https://github.com/tensorflow/tensorflow) and the C++ code in [s4tf/s4tf](https://github.com/s4tf/s4tf). Keep the next set of commands in a unique code cell, which you only run once. Do not add anything else to this code cell, unless you enjoy [I/O deadlocks](https://github.com/philipturner/swift-colab/issues/17).

```swift
%system curl "https://storage.googleapis.com/swift-tensorflow-artifacts/oneoff-builds/tensorflow-ubuntu1804-x86.zip" --output "x10-binary.zip"
%system unzip "x10-binary.zip"
%system cp -r "/content/Library/tensorflow-2.4.0/usr/include/tensorflow" "/usr/include/tensorflow"
```

These aren't the full build instructions! I will finish them tomorrow. In the meantime, check out https://github.com/s4tf/s4tf/pull/16 and https://github.com/philipturner/swift-colab/issues/15.

<!--
TF 2.4, S4TF PR listing the caveats

https://github.com/philipturner/swift-colab/issues/15. - can't use -c release -Xswiftc -Onone

Comment on issue 15

-->

## Testing

These tests ensure that Swift-Colab runs on recent Swift toolchains. Some of them originate from [unit tests](https://github.com/google/swift-jupyter/tree/main/test/tests) in swift-jupyter, while others cover fixed bugs and third-party libraries. If any notebook fails or you have a suggestion for a new test, please [open an issue](https://github.com/philipturner/swift-colab/issues).

To run a test, replace `"5.6.2"` in the first code cell with the newest Swift version. Run the installation commands, then go to `Runtime > Restart runtime`. Click on the second code cell and instruct Colab to execute every cell in the notebook (`Runtime > Run after`). Compare each cell's expected output with its actual output. If additional instructions appear at the top of the notebook, read them before running the test.

<!-- Emoji shortcuts for reference: ✅ ❌ -->

| Test | Passing | Date of Last Test Run | Swift Version |
| ---- | ------- | --------------------- | ------------- |
| [Swift Kernel Tests](https://colab.research.google.com/drive/1vooU1XVHSpolOSmVUKM4Wj6opEJBt7zs?usp=sharing) | ✅ | June 2022 | 5.6.2 Release |
| [Own Kernel Tests](https://colab.research.google.com/drive/1nHitEZm9QZNheM-ALajARyRZY2xpZr00?usp=sharing) | ✅ | June 2022 | 5.6.2 Release |
| [Simple Notebook Tests](https://colab.research.google.com/drive/18316eFVMw-NIlA9OandB7djvp0J4jI0-?usp=sharing) | ✅ | June 2022 | 5.6.2 Release |
| [SwiftPlot](https://colab.research.google.com/drive/1Rxs7OfuKIJ_hAm2gUQT2gWSuIcyaeZfz?usp=sharing) | ✅ | June 2022 | 5.6.2 Release
| [Swift for TensorFlow](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing) | ✅ | June 2022 | June 13, 2022 v5.7 Development Snapshot |
| [Concurrency](https://colab.research.google.com/drive/1du6YzWL9L_lbjoLl8qvrgPvyZ_8R7MCq?usp=sharing) | ✅ | June 2022 | 5.6.2 Release |

<!--

S4TF notebooks made by Google, make them tests now

-->
