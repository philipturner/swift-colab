# Swift-Colab

In March 2021, Google [ended](./Documentation/ColabSupportHistory.md) built-in Swift support on Colaboratory as part of their *attempt* to end [Swift for TensorFlow (S4TF)](https://github.com/tensorflow/swift). Now that new contributors are working on S4TF, Colab support is essential for ensuring that TPU acceleration still works. This repository is the successor to [google/swift-jupyter](https://github.com/google/swift-jupyter), rewritten entirely in Swift.

Swift-Colab is an accessible way to do programming with Swift. It runs in a browser, taking only 30 seconds to start up. It is perfect for programming on Chromebooks and tablets, which do not have the full functionality of a desktop. You can access a free NVIDIA GPU for machine learning, using the real C bindings for OpenCL and CUDA instead of Python wrappers. In the near future, you will be able to experiment with the [new S4TF](https://github.com/s4tf/s4tf) as well.

For an in-depth look at how and why this repository was created, check out the [summary of its history](./Documentation/ColabSupportHistory.md).

> Parts of this README from here on out are extremely out of date. They mirror how to use Swift-Colab 1.0, yet version 2.1 is currently in development. Furthermore, Swift-Colab may soon become the official successor to google/swift-jupyter. There will no longer be a notice to look at the old repository for any instructions.

## How to run Swift on Google Colaboratory

Copy [this template](https://colab.research.google.com/drive/1EACIWrk9IWloUckRm3wu973bKUBXQDKR?usp=sharing) of a Swift Colab notebook. Do not create one directly from Google Drive, as notebooks are configured for Python by default. Copy the following commands into the first code cell and run it:

```swift
!curl "https://raw.githubusercontent.com/philipturner/swift-colab/release/latest/install_swift.sh" -o "install_swift.sh"
!bash "install_swift.sh" "5.6" #// Replace 5.6 with newest Swift version.
#// After this command finishes, go to Runtime > Restart runtime.
```

In the output stream, you will see:

```
=== Downloading Swift ===
...
=== Swift successfully downloaded ===
...
=== Swift successfully installed ===
```

You will be instructed to restart the runtime. This is necessary because it shuts down the Python kernel and starts the Swift kernel.

> Tip: If you factory reset the runtime or exceed the time limit, Colab will restart in Python mode. Just re-run the first code cell to return to Swift mode.

Type the following code into the second code cell:

```swift
Int.bitWidth
```

After running it, the following output appears:

```
64
```

For further guidance on how to use Swift on Google Colab, check out the [usage instructions](https://github.com/google/swift-jupyter#usage-instructions) on [google/swift-jupyter](https://github.com/google/swift-jupyter). You must use Swift on Google Colab in a slightly different way than described on google/swift-jupyter. The differences are explained in the rest of this document.

## Installing packages

To use Python interop or automatic differentiation, you must explicitly import their packages in first cell executed in Swift mode. Also, you cannot include `EnableJupyterDisplay.swift` (include `EnableIPythonDisplay.swift` instead).

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit.git", .branch("master"))' PythonKit
%install '.package(url: "https://github.com/philipturner/differentiation", .branch("main"))' _Differentiation
%include "EnableIPythonDisplay.swift"
import PythonKit
import Differentiation
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
| [swiftplot tests](https://colab.research.google.com/drive/1Rxs7OfuKIJ_hAm2gUQT2gWSuIcyaeZfz?usp=sharing) | ✅ | Swift 5.6 (April 2022) |
