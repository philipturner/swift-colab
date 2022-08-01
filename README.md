# Swift-Colab

In March 2021, Google [ended](./Documentation/ColabSupportHistory.md) built-in Swift support on Colaboratory as part of their <s>evil plot</s> attempt to archive [Swift for TensorFlow (S4TF)](https://github.com/tensorflow/swift). Now that new contributors are working on S4TF, a Swift Colab kernel is essential for ensuring that TPU acceleration still works. This repository is the successor to [google/swift-jupyter](https://github.com/google/swift-jupyter), rewritten entirely in Swift.

Swift-Colab is an accessible way to do programming with Swift. It runs in a browser, taking only 30 seconds to start up. It is perfect for programming on Chromebooks and tablets, which do not have the full functionality of a desktop. You can access a free NVIDIA GPU for machine learning and use the real C bindings for OpenCL - instead of Python wrappers. Most importantly, the [new S4TF](https://github.com/s4tf/s4tf) finally runs on Colab.

For an in-depth look at how and why this repository was created, check out the [summary of its history](./Documentation/ColabSupportHistory.md).

- [Getting Started](#getting-started)
- [Using Swift-Colab](#using-swift-colab)
- [Installing Packages](#installing-packages)
- [SwiftPlot Integration](#swiftplot-integration)
- [Swift for TensorFlow Integration](#swift-for-tensorflow-integration)
- [Swift Tutorials](#swift-tutorials)
- [Testing](#testing)

---

This repository does not currently run local Jupyter notebooks, but the v3.0 release will support [JupyterLab](https://jupyterlab.readthedocs.io/en/stable/) (ETA: early 2023). In the meantime, [liuliu/swift-jupyter](https://github.com/liuliu/swift-jupyter) provides an actively maintained local notebook experience.

<details>
<summary>Why use Swift-'Colab' for experiences outside of Colaboratory?</summary>

---

Since [swift-jupyter](https://github.com/google/swift-jupyter) went unmaintained, Swift-Colab became the dominant "source of truth" for Jupyter notebook support. It's well-maintained and receives a high volume of internet traffic. Some users have tried running `install_swift.sh` on personal computers, with limited success. People will probably continue doing this despite the existence of [liuliu/swift-jupyter](https://github.com/liuliu/swift-jupyter). Furthermore, the repo's maintainer has a motive for supporting [JupyterLab](https://jupyterlab.readthedocs.io/en/stable/) (but not for supporting Docker\*).

> \*This presents a security risk: virtual machines encapsulate their code and stop it from harming the user's computer. When running vanilla JupyterLab, an ill-formed notebook could delete important files - in absence of proper security measures. Swift-Colab will harness any available mechanisms for limiting a process's access to the file system, and clearly document how it uses them.

Local environments have faster CPUs than virtual machines, compiling Swift packages more quickly than Google Colaboratory. They can store data persistently, bypassing the bottleneck of Swift for TensorFlow's excessively long build time. Furthermore, they permit using your personal computer's GPU for machine learning (<s>only with NVIDIA/CUDA</s> an upcoming S4TF backend will support any Metal or OpenCL-capable GPU).

</details>


## Getting Started

Colab notebooks created directly from Google Drive are tailored for Python programming. When making a Swift notebook, copy the [official template](https://colab.research.google.com/drive/1EACIWrk9IWloUckRm3wu973bKUBXQDKR?usp=sharing) instead. It contains the commands listed below, which download and compile the Jupyter kernel. Run the first code cell and click on `Runtime > Restart runtime` in the menu bar.

```swift
!curl "https://raw.githubusercontent.com/philipturner/swift-colab/release/latest/install_swift.sh" --output "install_swift.sh"
!bash "install_swift.sh" "5.6.2" #// Replace 5.6.2 with newest Swift version.
#// After this cell finishes, go to Runtime > Restart runtime.
```

> Tip: Colab measures how long you keep a notebook open without interacting with it. If you exceed the time limit of Colab's free tier, it may restart in Python mode. That means Swift code executes as if it's Python code. In that situation, repeat the process outlined above to return to Swift mode.

To automatically crash and restart the runtime, add the following line to the code cell. This is [not strictly necessary](https://github.com/philipturner/swift-colab/pull/19) and absent from the official template notebook. You can also restart the runtime with `Cmd/Ctrl + M + .`.

```swift
import os; import sys; sys.stdout.flush(); os.kill(os.getpid(), 9)
```

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

S4TF has a quite complex build setup. The easiest way to use it is copying the [S4TF test notebook](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing) into your Google Drive. To configure it manually, read the instructions below.

Swift for TensorFlow does not compile on Linux release toolchains, so select a Swift development toolchain. Visit [swift.org/download](https://www.swift.org/download) and scroll to "Trunk Development (main)". Note the date next to "Ubuntu 18.04" - at the time of writing, July 20, 2022. At the top of your Colab notebook, the first code cell says "Replace 5.6.2 with newest Swift version." Delete the `"5.6.2"` after `"install_swift.sh"` and enter the snapshot's date in YYYY-MM-DD format.

```swift
!bash "install_swift.sh" "2022-07-20" #// Replace 5.6.2 with newest Swift version.
```

You can easily download trunk snapshots by pasting their date. For other toolchains, the entire URL must be present. The code below downloads the July 5, 2022 snapshot from Swift's `release/5.7` branch. Do not enter it into the notebook; it is only here for reference.

```swift
!bash "install_swift.sh" "https://download.swift.org/swift-5.7-branch/ubuntu1804/swift-5.7-DEVELOPMENT-SNAPSHOT-2022-07-05-a/swift-5.7-DEVELOPMENT-SNAPSHOT-2022-07-05-a-ubuntu18.04.tar.gz" #// Replace 5.6.2 with newest Swift version.
```

Execute the installation script and go to `Runtime > Restart runtime`. Next, download the X10 binary created from [tensorflow/tensorflow](https://github.com/tensorflow/tensorflow) and the C++ code in [s4tf/s4tf](https://github.com/s4tf/s4tf). Paste the commands below into a unique code cell, which you only run once. Do not add anything else to this cell, unless you enjoy [I/O deadlocks](https://github.com/philipturner/swift-colab/issues/17).

```swift
%system curl "https://storage.googleapis.com/swift-tensorflow-artifacts/oneoff-builds/tensorflow-ubuntu1804-cuda11-x86.zip" --output "x10-binary.zip"
%system unzip "x10-binary.zip"
%system cp -r "/content/Library/tensorflow-2.4.0/usr/include/tensorflow" "/usr/include/tensorflow"
```

Top-of-tree S4TF is currently tested against TensorFlow 2.9, as shown in the [S4TF build script](https://gist.github.com/philipturner/7aa063af04277d463c14168275878511). The script does not yet run on every platform and a major [XLA bug](https://github.com/s4tf/s4tf/issues/14) exists, so I cannot host modern X10 binaries online. The previous command downloaded the last X10 binary that Google created, which uses TF 2.4. Using an outdated binary [brings some caveats](https://github.com/s4tf/s4tf/pull/16), as the raw TensorFlow bindings were recently [updated for v2.9](https://github.com/s4tf/s4tf/pull/10). As a rule of thumb, avoid the `_Raw` namespace.

Now, the real action begins. [s4tf/s4tf](https://github.com/s4tf/s4tf) takes 3 minutes to compile on Google Colab, which sounds worse than it is. Swift-Colab 2.0 made this a one-time cost, so the package rebuilds instantaneously after restarting the runtime. Grab a cup of coffee or read a Medium article while it compiles, and that's the only waiting you ever need to do. If you accidentally close the browser tab with S4TF loaded, salvage it with `Runtime > Manage sessions`.

> To access your closed notebook, first open a new notebook. `Runtime > Manage sessions` shows a list of active Colab sessions. Click on the closed notebook's name, and it opens in a new browser tab.

Go to `Insert > Code cell` and paste the following commands. The SwiftPM flags `-c release -Xswiftc -Onone` are commented out. They shorten build time to 2 minutes, but require [restarting the runtime twice](https://github.com/philipturner/swift-colab/issues/15) because of a [compiler bug](https://github.com/apple/swift/issues/59569). Consider using these flags if compile time becomes a serious bottleneck in your workflow.

```swift
%install-swiftpm-flags $clear
// %install-swiftpm-flags -c release -Xswiftc -Onone
%install-swiftpm-flags -Xlinker "-L/content/Library/tensorflow-2.4.0/usr/lib"
%install-swiftpm-flags -Xlinker "-rpath=/content/Library/tensorflow-2.4.0/usr/lib"
%install '.package(url: "https://github.com/s4tf/s4tf", .branch("main"))' TensorFlow
```

Finally, import Swift for TensorFlow into the interpreter.

```swift
import TensorFlow
```

## Swift Tutorials

Tutorial notebooks do not include commands for installing Swift-Colab; you must add the commands described in [Getting Started](#getting-started). They also depend on modules such as PythonKit and TensorFlow, which were previously part of custom S4TF toolchains. We now use stock toolchains, so download the packages as described in [Installing Packages](#installing-packages) and [Swift for TensorFlow Integration](#swift-for-tensorflow-integration). For tutorials that involve automatic differentiation, either use [Differentiation](https://github.com/philipturner/differentiation) or download a development toolchain.

Multiple tutorial notebooks depend on Swift for TensorFlow. <s>You must recompile the Swift package in each notebook, waiting 3 minutes each time.</s> Save time by compiling S4TF in one Colab instance, then reusing it for multiple tutorials. To start, open up the [Swift for TensorFlow test notebook](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing). Append the commands below to the cell that compiles S4TF. When S4TF starts building, read the rest of these instructions.

```swift
%install-swiftpm-flags $clear
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
import _Differentiation // If using a development toolchain.

// If using a release toolchain.
// %install '.package(url: "https://github.com/philipturner/differentiation", .branch("main"))' _Differentiation
// import Differentiation
```

In another browser tab, open one of the tutorials. Click `Edit > Select all cells` in the menu bar. Every cell should turn blue. Press `Cmd/Ctrl + C` to copy the cells. Switch back to the original Colab notebook and click the last cell. Press `Cmd/Ctrl + V`. Every cell from the tutorial should appear in the notebook that is compiling S4TF.

When following a tutorial for the first time, run its cells one by one. To run all of them at once, click the first code cell of the tutorial. Then, go to `Runtime > Run after`. If you are lucky, the cells can be deleted with `Edit > Undo insert X cells`. Otherwise, select all cells, delete them, and paste the contents of the [S4TF test notebook]((https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing)). After resetting the notebook, go to `Runtime > Restart runtime`. Rerun the cell that installs TensorFlow and PythonKit, which should take 4 seconds to execute. Proceed with the second tutorial.

In the table below, "Compatible Swift Versions" lists whether each notebook runs under the latest release or development toolchain.
- Release = 5.6.2 Release
- Development = July 20, 2022 Development Snapshot

<!-- Dependency shortcuts for reference: AutoDiff PythonKit S4TF SwiftAI SwiftModels -->

| Tutorial | Dependencies | Compatible Swift Versions |
| -------- | ------------ | ------------------------- |
| [A Swift Tour](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/a_swift_tour.ipynb) | | Release, Development |
| [Protocol-Oriented Programming & Generics](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/protocol_oriented_generics.ipynb) | | Release, Development |
| [Python Interoperability](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/python_interoperability.ipynb)<sup>[1]</sup> | PythonKit, S4TF<sup>[2]</sup> | Release, Development |
| [Sharp Edges in Differentiability](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/Swift_autodiff_sharp_edges.ipynb)<sup>[3][4]</sup> | AutoDiff | Release, Development |
| [Model Training Walkthrough](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/model_training_walkthrough.ipynb) | AutoDiff, PythonKit, S4TF | Development |
| [Raw TensorFlow Operators](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/raw_tensorflow_operators.ipynb) | AutoDiff, S4TF | Development |
| [Introducing X10, an XLA-Based Backend](https://colab.research.google.com/github/tensorflow/swift/blob/main/docs/site/tutorials/introducing_x10.ipynb)<sup>[5]</sup> | S4TF, S4TF Models | n/a |

> <sup>1</sup>One cell fails because of ambiguous overloads for `PythonObject.==` and `PythonObject.<`. Work around this by explicitly casting the comparison result to `Bool` before printing.
>
> <sup>2</sup>When using release toolchains, skip the cell that contains `Tensor<Float>`.
>
> <sup>3</sup>Several cells fail because `gradient(at:in)` was renamed to `gradient(at:of:)`. Fix the second argument label and rerun the failed cells.
>
> <sup>4</sup>One cell fails because of the ambiguous line `gradient(at: 2, 2, of: pow)`. Fix this by replacing either `2` with `Double(2)`.
>
> <sup>5</sup>This notebook depends on [tensorflow/swift-models](https://github.com/tensorflow/swift-models), which you must change to [s4tf/models](https://github.com/s4tf/models). The repository is not updated for recent Swift toolchains, and I need to decide how to link the `TensorFlow` Swift module into it.

More tutorials are in development. Upon completion, they will appear in the table above. The notation `(New)` distinguishes them from tutorials created by Google.

| Planned Tutorial | Dependencies | Compatible Swift Versions |
| ---------------- | ------------ | ------------------------- |
| General-Purpose GPU with OpenCL (New) | [SwiftOpenCL](https://github.com/philipturner/swift-opencl) | Release, Development |

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
| [Swift for TensorFlow](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing) | ✅ | July 2022 | July 20, 2022 Development Snapshot |
| [Concurrency](https://colab.research.google.com/drive/1du6YzWL9L_lbjoLl8qvrgPvyZ_8R7MCq?usp=sharing) | ✅ | June 2022 | 5.6.2 Release |
| [TPU Tests](https://colab.research.google.com/drive/1DfkbU_JQnSw1_xLAlDyDvDT3S1G45i6d?usp=sharing) | ✅ | July 2022 | July 5, 2022 v5.7 Development Snapshot |
