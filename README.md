# Swift-Colab

> Warning: Some of this documentation may be outdated. Swift-Colab is in the middle of a major overhaul. For a 100% trustworthy guide, check out the README snapshot in [swift-colab-dev](https://github.com/philipturner/swift-colab-dev).

In March 2021, Google ended built-in Swift support on Colaboratory as part of their *attempt* to end [S4TF](https://github.com/tensorflow/swift). Less than a year later, the open-source community is resurrecting S4TF, and Colab support is a vital component of that effort. It allows testing on TPUs and ensuring new modifications don't break existing hardware acceleration.

Furthermore, Colab is a very accessible way to do programming with Swift. It runs instantly without downloading an IDE, and it can even run on a Chromebook or mobile device.

## How to run Swift on Google Colaboratory

Copy [this template](https://colab.research.google.com/drive/1EACIWrk9IWloUckRm3wu973bKUBXQDKR?usp=sharing) of a Swift Colab notebook. Do not create one directly from Google Drive, as notebooks are configured for Python by default. Copy the following commands into the first code cell and run it:

```swift
!curl "https://raw.githubusercontent.com/philipturner/swift-colab/release/latest/install_swift.sh" -o "install_swift.sh"
!bash "install_swift.sh" "5.6" #// Replace 5.6 with newest Swift version
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
| [swiftplot tests](https://colab.research.google.com/drive/1Rxs7OfuKIJ_hAm2gUQT2gWSuIcyaeZfz?usp=sharing) | ✅ | Swift 5.5.3 (March 2022) |
