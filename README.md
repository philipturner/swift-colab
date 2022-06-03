# Swift-Colab

In March 2021, Google [ended](./Documentation/ColabSupportHistory.md) built-in Swift support on Colaboratory as part of their *attempt* to end [Swift for TensorFlow (S4TF)](https://github.com/tensorflow/swift). Now that new contributors are working on S4TF, Colab support is essential for ensuring that TPU acceleration still works. This repository is the successor to [google/swift-jupyter](https://github.com/google/swift-jupyter), rewritten entirely in Swift.

Swift-Colab is an accessible way to do programming with Swift. It runs in a browser, taking only 30 seconds to start up. It is perfect for programming on Chromebooks and tablets, which do not have the full functionality of a desktop. You can access a free NVIDIA GPU for machine learning, using the real C bindings for OpenCL and CUDA instead of Python wrappers. In the near future, you will be able to experiment with the [new S4TF](https://github.com/s4tf/s4tf) as well.

For an in-depth look at how and why this repository was created, check out the [summary of its history](./Documentation/ColabSupportHistory.md).

> Parts of this README from here on out are extremely out of date. This includes all test notebooks except SwiftPlot. They mirror how to use Swift-Colab 1.0, but this repository is on version 2.1. Furthermore, Swift-Colab is now recognized as the successor to google/swift-jupyter. In the future, there will no longer be a notice to look at the old repository for any instructions.

## How to run Swift on Google Colaboratory

Copy [this template](https://colab.research.google.com/drive/1EACIWrk9IWloUckRm3wu973bKUBXQDKR?usp=sharing) of a Swift Colab notebook. Do not create one directly from Google Drive, as notebooks are configured for Python by default. Copy the following commands into the first code cell and run it:

```swift
!curl "https://raw.githubusercontent.com/philipturner/swift-colab/release/latest/install_swift.sh" --output "install_swift.sh"
!bash "install_swift.sh" "5.6.1" #// Replace 5.6.1 with newest Swift version.
#// After this cell finishes, go to Runtime > Restart runtime.
```

You will be instructed to restart the runtime. This is necessary because it shuts down the Python kernel and starts the Swift kernel.

> Tip: If you exceed the time limit or disconnect and delete the runtime, Colab will restart in Python mode. Repeat the process outlined above to return to Swift mode.

Type the following code into the second code cell:

```swift
Int.bitWidth
```

After running it, the following output appears:
```
64
```

Swift-Colab has several features, such as built-in magic commands and Google Drive integration. Unfortunately, they are not adequately documented at the moment. Follow the [usage instructions](https://github.com/google/swift-jupyter#usage-instructions) of the old [google/swift-jupyter](https://github.com/google.swift-jupyter) in the meantime.

## Installing packages

To install a Swift package, first add an `%install` command followed by a Swift 4.2-style package specification. After that, type the module names you want to compile. In another line, import the module. Unlike with [swift-jupyter](https://github.com/google.swift-jupyter), you can install packages in any cell, even after some code has already executed. 

If you restart the runtime, you must replay the `%install` command for installing it. This command tells the Swift interpreter that the package is ready to be imported. It will also take less time to compile, because it's utilizing cached build products from the previous Jupyter session.

# Plotting support

To use IPython graphs or SwiftPlot, enter a few magic commands as shown below. [`EnableIPythonDisplay.swift`](https://github.com/philipturner/swift-colab/blob/main/Sources/include/EnableIPythonDisplay.swift) depends on the PythonKit and SwiftPlot libraries. SwiftPlot takes 23 seconds to compile, so avoid importing it unless you intend to use it. If you change your mind an want to display plots coming from SwiftPlot, restart the runtime.

> If you change your mind an want to display plots coming from SwiftPlot, restart the runtime.

To use Python interop or automatic differentiation, you must explicitly import their packages in first cell executed in Swift mode. Also, you cannot include `EnableJupyterDisplay.swift` (include `EnableIPythonDisplay.swift` instead).

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit", .branch("master"))' PythonKit
%install '.package(url: "https://github.com/KarthikRIyer/swiftplot", .branch("master"))' SwiftPlot AGGRenderer
```

You must include `EnableIPythonDisplay.swift` after installing the Swift packages, otherwise it will allow plotting. The file injects code for importing the PythonKit, SwiftPlot, and AGGRenderer modules. The code samples here do not explicitly import them, as that would be redundant.


```swift
%include "EnableIPythonDisplay.swift"
```

## Sample code

The code on the README of google/swift-jupyter about SwiftPlot will not compile. Replace it with the following:

```swift
import Foundation
import SwiftPlot
import AGGRenderer

func function(_ x: Float) -> Float {
    return 1.0 / x
}

var aggRenderer = AGGRenderer()
var lineGraph = LineGraph<Float, Float>()
lineGraph.addFunction(
    function,
    minX: -5.0,
    maxX: 5.0,
    numberOfSamples: 400,
    clampY: -50...50,
    label: "1/x",
    color: .orange)
lineGraph.plotTitle.title = "FUNCTION"
lineGraph.drawGraph(renderer: aggRenderer)
display(base64EncodedPNG: aggRenderer.base64Png())
```

And add these statements to the bottom of the code cell that imports PythonKit and Differentiation:

```swift
%install-swiftpm-flags -Xcc -isystem/usr/include/freetype2 -Xswiftc -lfreetype
%install '.package(url: "https://github.com/KarthikRIyer/swiftplot", .branch("master"))' SwiftPlot AGGRenderer
```

## Testing

To test Swift-Colab against recent Swift toolchains and ensure support is never dropped from Colab again, you can run the following tests. These Colab notebooks originated from Python [unit tests](https://github.com/google/swift-jupyter/tree/main/test/tests) in google/swift-jupyter:

<!-- Emoji shortcuts for reference: ✅ ❌ -->

| Test | Passing | Last Tested |
| ---- | --------------- | ----------- |
| [kernel tests](https://colab.research.google.com/drive/1vooU1XVHSpolOSmVUKM4Wj6opEJBt7zs?usp=sharing) | ✅ | Swift 5.5.3 (March 2022) |
| [own kernel tests](https://colab.research.google.com/drive/1nHitEZm9QZNheM-ALajARyRZY2xpZr00?usp=sharing) | ✅ | Swift 5.5.3 (March 2022) |
| [simple notebook tests](https://colab.research.google.com/drive/18316eFVMw-NIlA9OandB7djvp0J4jI0-?usp=sharing) | ✅ | Swift 5.5.3 (March 2022) |
| [SwiftPlot](https://colab.research.google.com/drive/1Rxs7OfuKIJ_hAm2gUQT2gWSuIcyaeZfz?usp=sharing) | ✅ | Swift 5.6 (April 2022) |
| [S4TF with TF 2.4](https://colab.research.google.com/drive/1v3ZhraaHdAS2TGj03hE0cK-KRFzsqxO1?usp=sharing)* | ❌ | 2021-11-12 Nightly Snapshot (June 2022) |

\*See https://github.com/philipturner/swift-colab/issues/15 for the status of this failure.
