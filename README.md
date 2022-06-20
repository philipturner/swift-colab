# Swift-Colab

In March 2021, Google [ended](./Documentation/ColabSupportHistory.md) built-in Swift support on Colaboratory as part of their <s>evil plot</s> attempt to archive [Swift for TensorFlow (S4TF)](https://github.com/tensorflow/swift). Now that new contributors are working on S4TF, Colab support is essential for ensuring that TPU acceleration still works. This repository is the successor to [google/swift-jupyter](https://github.com/google/swift-jupyter), rewritten entirely in Swift.

Swift-Colab is an accessible way to do programming with Swift. It runs in a browser, taking only 30 seconds to start up. It is perfect for programming on Chromebooks and tablets, which do not have the full functionality of a desktop. You can access a free NVIDIA GPU for machine learning, using the real C bindings for OpenCL and CUDA instead of Python wrappers. Most importantly, the [new S4TF](https://github.com/s4tf/s4tf) finally runs on Colab.

For an in-depth look at how and why this repository was created, check out the [summary of its history](./Documentation/ColabSupportHistory.md).

- [Getting Started](#getting-started)
- [Using Swift-Colab](#using-swift-colab)
- [Installing Packages](#installing-packages)
- [SwiftPlot Integration](#swiftplot-integration)
- [Swift for TensorFlow Integration](#swift-for-tensorflow-integration)
- [Swift Tutorials](#swift-tutorials)
- [Testing](#testing)

## Getting Started

Colab notebooks created directly from Google Drive are tailored for Python programming. When making a Swift notebook, copy the [official template](https://colab.research.google.com/drive/1EACIWrk9IWloUckRm3wu973bKUBXQDKR?usp=sharing) instead. It contains the commands listed below, which download and compile the Jupyter kernel. Run the first code cell and click on `Runtime > Restart runtime` in the menu bar.

```swift
!curl "https://raw.githubusercontent.com/philipturner/swift-colab/release/latest/install_swift.sh" --output "install_swift.sh"
!bash "install_swift.sh" "5.6.2" #// Replace 5.6.2 with newest Swift version.
#// After this cell finishes, go to Runtime > Restart runtime.
```

> Tip: Colab measures how long you keep a notebook open without interacting with it. If you exceed the time limit of Colab's free tier, it may restart in Python mode. That means Swift code executes as if it's Python code. In that situation, repeat the process outlined above to return to Swift mode.

When Google sponsored S4TF from 2018 - 2021, the Swift community created several Jupyter notebooks. To run these notebooks now, slightly modify them. Create a new cell at the top of each notebook, including the commands shown above*. No further changes are necessary because of Swift-Colab's backward-compatibility. If you experience a problem, please [file an issue](https://github.com/philipturner/swift-colab/issues).

> \*For a more future-proof solution, fill that cell with only a comment directing the user to Swift-Colab's repository. Whoever runs the notebook will likely not update the Swift version passed into `install_swift.sh`. I recommend this approach for the [fastai/swiftai](https://github.com/fastai/swiftai) notebooks and anything else that must be maintained indefinitely.

This repository contains a [growing list of tutorials](#swift-tutorials) sourced from [s4tf/s4tf-docs](https://github.com/s4tf/s4tf-docs) (formerly tensorflow/swift) and [fastai/swiftai](https://github.com/fastai/swiftai). Before following them, read through this README and familiarize yourself with the peculiarities of Swift-Colab.

## Using Swift-Colab

Google Colab is like the Swift REPL, but it submits several lines of code at once. Create a new cell with `Insert > Code cell` and fill it with the first example below. Run it, and `64` appears in the output. No matter how many lines a cell has, only the last one's return value appears. To get around this restriction, use `print(...)` to display values.

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

The Swift kernel has several powerful features, including [magic commands](./Documentation/MagicCommands.md) and [Google Drive integration](./Documentation/GoogleDriveIntegration.md). Unfortunately, they are not fully documented yet. The old swift-jupyter's [usage instructions](https://github.com/google/swift-jupyter#usage-instructions) may be helpful in the meantime.

## Installing Packages

To install a Swift package, type `%install` and a Swift 4.2-style package declaration. The declaration should appear between two single quotes. After that, enter the modules you want to compile. Before importing any module with a Swift `import` statement, execute its `%install` command. You can install packages in any cell, even after other Swift code has executed.

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
```

Upon restarting the runtime, remember to rerun the `%install` command for each package. This command tells the Swift interpreter that the package is ready to be imported. It runs much more quickly than the first time through, because Swift-Colab utilizes cached build products from the previous Jupyter session. Try testing this mechanism by redundantly importing the same package. Make sure both commands match character-for-character!

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
```

## SwiftPlot Integration

To use IPython graphs or SwiftPlot plots, enter the magic commands shown below. Include [`EnableIPythonDisplay.swift`](https://github.com/philipturner/swift-colab/blob/main/Sources/include/EnableIPythonDisplay.swift) after installing the Swift packages, because the file depends on both of them. SwiftPlot takes 23 seconds to compile, so you may skip its install command unless you intend to use it. However, you must restart the runtime if you change your mind.

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
%install '.package(url: "https://github.com/KarthikRIyer/swiftplot", .branch("master"))' SwiftPlot AGGRenderer
%include "EnableIPythonDisplay.swift"
```

`EnableIPythonDisplay.swift` injects the following code into the interpreter, gated under multiple import guards. The code samples here do not explicitly import these libraries, as doing so would be redundant. If you do not include `EnableIPythonDisplay.swift`, explicitly import them before running other Swift code.

```swift
import PythonKit
import SwiftPlot
import AGGRenderer
```

For tutorials on using the SwiftPlot API, check out [KarthikRIyer/swiftplot](https://github.com/KarthikRIyer/swiftplot).

## Swift for TensorFlow Integration

S4TF has a quite complex build setup. The easiest way to use it is copying the [Swift for TensorFlow test notebook](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing) into your Google Drive. To configure it manually, read the instructions below.

Swift for TensorFlow does not compile on release toolchains, so download a Swift development toolchain. A bug in the latest trunk snapshot [prevents S4TF from compiling](https://github.com/apple/swift/issues/59467), but a few trunk snapshots were released before the bug appeared. Also, every toolchain created from the `release/5.7` branch works. Some of your options are:

- May 4, 2022 Trunk Development Snapshot
- May 11, 2022 Trunk Development Snapshot
- May 15, 2022 v5.7 Development Snapshot
- June 13, 2022 v5.7 Development Snapshot

Modify the installation command at the very top of your Colab notebook. The second line of the first code cell says "Replace 5.6.2 with newest Swift version." Delete the `"5.6.2"` after `"install_swift.sh"` and enter your chosen snapshot. If you chose the May 11, 2022 trunk snapshot, you should have:

```swift
!bash "install_swift.sh" "2022-05-11" #// Replace 5.6.2 with newest Swift version.
```

You can easily download trunk snapshots by entering their date in YYYY-MM-DD format. For v5.7 snapshots, the entire URL must be present. Go to [swift.org/download](https://www.swift.org/download) and scroll to "Swift 5.7 Development". Right-click the large "x86_64" link for Ubuntu 18.04, copy the address, and paste it into the notebook.

```swift
!bash "install_swift.sh" "https://download.swift.org/swift-5.7-branch/ubuntu1804/swift-5.7-DEVELOPMENT-SNAPSHOT-2022-06-13-a/swift-5.7-DEVELOPMENT-SNAPSHOT-2022-06-13-a-ubuntu18.04.tar.gz" #// Replace 5.6.2 with newest Swift version.
```

Execute the installation script and go to `Runtime > Restart runtime`. Next, download the X10 binary created from [tensorflow/tensorflow](https://github.com/tensorflow/tensorflow) and the C++ code in [s4tf/s4tf](https://github.com/s4tf/s4tf). Paste the commands below into a unique code cell, which you only run once. Do not add anything else to this cell, unless you enjoy [I/O deadlocks](https://github.com/philipturner/swift-colab/issues/17).

```swift
%system curl "https://storage.googleapis.com/swift-tensorflow-artifacts/oneoff-builds/tensorflow-ubuntu1804-x86.zip" --output "x10-binary.zip"
%system unzip "x10-binary.zip"
%system cp -r "/content/Library/tensorflow-2.4.0/usr/include/tensorflow" "/usr/include/tensorflow"
```

Top-of-tree S4TF is currently tested against TensorFlow 2.9, as shown in the [S4TF build script](https://gist.github.com/philipturner/7aa063af04277d463c14168275878511). Because the script does not yet run on every platform, I cannot host modern X10 binaries online. The previous command downloaded the last X10 binary that Google created, which uses TF 2.4. Using an outdated binary [brings some caveats](https://github.com/s4tf/s4tf/pull/16), as the raw TensorFlow bindings were recently [updated for v2.9](https://github.com/s4tf/s4tf/pull/10). As a rule of thumb, avoid the `_Raw` namespace.

Now, the real action begins. The `TensorFlow` Swift package takes 3 minutes to compile on Google Colab, which sounds worse than it is.  Swift-Colab 2.0 made this a one-time cost, so the package rebuilds instantaneously after restarting the runtime. Grab a cup of coffee or read a Medium article while it compiles, and that's the only waiting you ever need to do. If you accidentally close the browser tab with S4TF loaded, salvage it with `Runtime > Manage sessions`.

> To access your closed notebook, first open a new notebook. `Runtime > Manage sessions` shows a list of recent Colab instances. Click on the old one, and its notebook opens in a new browser tab.

Go to `Insert > Code cell` and paste the following commands. The SwiftPM flags `-c release -Xswiftc -Onone` are commented out. They shorten build time to 2 minutes, but require [restarting the runtime twice](https://github.com/philipturner/swift-colab/issues/15) because of a [compiler bug](https://github.com/apple/swift/issues/59569). Consider using these flags if compile time becomes a serious bottleneck in your workflow.

```swift
%install-swiftpm-flags $clear
// %install-swiftpm-flags -c release -Xswiftc -Onone
%install-swiftpm-flags -Xswiftc -DTENSORFLOW_USE_STANDARD_TOOLCHAIN
%install-swiftpm-flags -Xlinker "-L/content/Library/tensorflow-2.4.0/usr/lib"
%install-swiftpm-flags -Xlinker "-rpath=/content/Library/tensorflow-2.4.0/usr/lib"
%install '.package(url: "https://github.com/s4tf/s4tf", .branch("main"))' TensorFlow
```

Finally, import Swift for TensorFlow into the interpreter.

```swift
import TensorFlow
```

## Swift Tutorials

These notebooks do not include commands for installing Swift-Colab; you must add the commands described in [Getting Started](#getting-started). They also depend on packages such as PythonKit and TensorFlow, which were previously included in the custom S4TF toolchains. Now, you must download as described in [Installing Packages](#installing-packages) and [Swift for TensorFlow Integration](#swift-for-tensorflow-integration). For tutorials that involve automatic differentiation, either use [Differentiation](https://github.com/philipturner/differentiation) or download a development toolchain.

Multiple tutorial notebooks depend on S4TF. <s>You must recompile the Swift package in each notebook, waiting 3 minutes each time.</s> You can save time by compiling S4TF in one Colab instance, then reusing it for multiple tutorials. To start, open up the [Swift for TensorFlow test notebook](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing). While the package is compiling, read the rest of these instructions.

> I'm testing an idea of reusing the same session across multiple notebooks, avoiding the 2 minutes of recompiling S4TF. Solution: delete all the cells in one notebook, then copy/paste all cells from another notebook. (show how to select all the cells in menu bar) - `Edit > Select all cells` -> Cmd/Ctrl + C -> `Edit > Select all cells` -> Cmd/Ctrl + V

Tutorial | Compatible Swift Version |
-------- | ------------ |
[A Swift Tour](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/a_swift_tour.ipynb) | ???
[Protocol-Oriented Programming & Generics](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/protocol_oriented_generics.ipynb) | ???
[Python Interoperability](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/python_interoperability.ipynb) | ???
[Custom Differentiation](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/custom_differentiation.ipynb) | ???
[Sharp Edges in Differentiability](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/Swift_autodiff_sharp_edges.ipynb) | ???
[Model Training Walkthrough](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/model_training_walkthrough.ipynb) | ???
[Raw TensorFlow Operators](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/raw_tensorflow_operators.ipynb) | ???
[Introducing X10, an XLA-Based Backend](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/introducing_x10.ipynb) |???

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

