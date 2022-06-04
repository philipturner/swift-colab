# Swift-Colab

In March 2021, Google [ended](./Documentation/ColabSupportHistory.md) built-in Swift support on Colaboratory as part of their *attempt* to end [Swift for TensorFlow (S4TF)](https://github.com/tensorflow/swift). Now that new contributors are working on S4TF, Colab support is essential for ensuring that TPU acceleration still works. This repository is the successor to [google/swift-jupyter](https://github.com/google/swift-jupyter), rewritten entirely in Swift.

Swift-Colab is an accessible way to do programming with Swift. It runs in a browser, taking only 30 seconds to start up. It is perfect for programming on Chromebooks and tablets, which do not have the full functionality of a desktop. You can access a free NVIDIA GPU for machine learning, using the real C bindings for OpenCL and CUDA instead of Python wrappers. In the near future, you will be able to experiment with the [new S4TF](https://github.com/s4tf/s4tf) as well.

For an in-depth look at how and why this repository was created, check out the [summary of its history](./Documentation/ColabSupportHistory.md).

## Getting started

Colab notebooks created directly from Google Drive have syntax coloring tailored for Python. When making a Swift notebook, copy the [official template](https://colab.research.google.com/drive/1EACIWrk9IWloUckRm3wu973bKUBXQDKR?usp=sharing) instead. It contains the commands listed below, which download and compile the Jupyter kernel. Run the first code cell and follow the instructions for restarting the runtime.

```swift
!curl "https://raw.githubusercontent.com/philipturner/swift-colab/release/latest/install_swift.sh" --output "install_swift.sh"
!bash "install_swift.sh" "5.6.1" #// Replace 5.6.1 with newest Swift version.
#// After this cell finishes, go to Runtime > Restart runtime.
```

> Tip: If you exceed the time limit or disconnect and delete the runtime, Colab will restart in Python mode. That means Swift code will execute as if it's Python code. Repeat the process outlined above to return to Swift mode.

When Google sponsored S4TF from 2018 - 2021, several Swift Jupyter notebooks were made. To run those notebooks now, you must slightly modify them. Create a new cell at the top, adding the commands shown above. Swift-Colab is backward-compatible with swift-jupyter, so no further changes are necessary. If you experience a problem, please [file an issue](https://github.com/philipturner/swift-colab/issues).

Colab is similar to the Swift REPL, but it submits several lines of code at once. Fill the second code cell with the example shown below. Run it, and you will see `64`. If you had run several lines, only the last one would show in output. To get around this restriction, you can use Swift's `print(...)` function to display values.

```swift
Int.bitWidth
```

Swift-Colab has several powerful features, including magic commands and Google Drive integration. Unfortunately, they are not adequately documented at the moment. Refer to the old google/swift-jupyter's [usage instructions](https://github.com/google/swift-jupyter#usage-instructions) in the meantime.

## Installing packages

To install a Swift package, make an `%install` command followed by a Swift 4.2-style package specification. After that, type the modules you want to compile. Before importing the module with a Swift `import` statement, execute the `%install` command. You can install packages in any cell, which was not possible with [swift-jupyter](https://github.com/google.swift-jupyter).

If you restart the runtime, you must replay the `%install` command for installing it. This command tells the Swift interpreter that the package is ready to be imported. It will also take less time to compile, because it's utilizing cached build products from the previous Jupyter session.

<!--
## Swift for TensorFlow integration

For in the future, when S4TF works in Colab. Either I fix the build system, or I hard-code some way to install the X10 binary.
-->

## SwiftPlot integration

To use IPython graphs or SwiftPlot, enter a few magic commands as shown below. [`EnableIPythonDisplay.swift`](https://github.com/philipturner/swift-colab/blob/main/Sources/include/EnableIPythonDisplay.swift) depends on the PythonKit and SwiftPlot libraries. SwiftPlot takes 23 seconds to compile, so avoid importing it unless you intend to use it. If you change your mind an want to use SwiftPlot later, just restart the runtime.

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
%install '.package(url: "https://github.com/KarthikRIyer/swiftplot", .branch("master"))' SwiftPlot AGGRenderer
%include "EnableIPythonDisplay.swift"
```

You must include `EnableIPythonDisplay.swift` after (instead of before) installing the Swift packages, otherwise it will not allow plotting. The file injects the following code into the interpreter, gated under import guards. The code samples here do not explicitly import them, as that would be redundant.

```swift
import PythonKit
import SwiftPlot
import AGGRenderer
```

## Testing

The following tests ensure Swift-Colab still runs with recent Swift toolchains. Some of these originated from [unit tests](https://github.com/google/swift-jupyter/tree/main/test/tests) in swift-jupyter, while others test popular libraries or bug fixes to Swift-Colab. If any up-to-date notebook fails or you have a suggestion for a new test notebook, please [open an issue](https://github.com/philipturner/swift-colab/issues).

<!-- Emoji shortcuts for reference: ✅ ❌ -->

| Test | Passing | Last Tested |
| ---- | --------------- | ----------- |
| [kernel_tests.py](https://colab.research.google.com/drive/1vooU1XVHSpolOSmVUKM4Wj6opEJBt7zs?usp=sharing) (outdated) | ✅ | Swift 5.5.3 (March 2022) |
| [own_kernel_tests.py](https://colab.research.google.com/drive/1nHitEZm9QZNheM-ALajARyRZY2xpZr00?usp=sharing) (outdated) | ✅ | Swift 5.5.3 (March 2022) |
| [simple_notebook_tests.py](https://colab.research.google.com/drive/18316eFVMw-NIlA9OandB7djvp0J4jI0-?usp=sharing) (outdated) | ✅ | Swift 5.5.3 (March 2022) |
| [SwiftPlot](https://colab.research.google.com/drive/1Rxs7OfuKIJ_hAm2gUQT2gWSuIcyaeZfz?usp=sharing) | ✅ | Swift 5.6 (April 2022) |
| [S4TF with TF 2.4](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing)* | ❌ | 2021-11-12 Nightly Snapshot (June 2022) |

\*https://github.com/philipturner/swift-colab/issues/15 tracks this failure.
