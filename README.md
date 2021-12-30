# Swift-Colab

## How to run Swift on Google Colaboratory

Copy [this template](https://colab.research.google.com/drive/1EACIWrk9IWloUckRm3wu973bKUBXQDKR?usp=sharing) of a Swift Colab notebook. Do not create one directly from Google Drive, as notebooks are configured for Python by default. Copy the following command into the first code cell and run it:

```swift
!curl "https://raw.githubusercontent.com/philipturner/swift-colab/pre-release/0.3/install_swift.sh" --output "install_swift.sh" && bash "install_swift.sh" "5.5.2" #// Replace 5.5.2 with newest Swift version
#// After this command finishes, go to Runtime > Restart runtime.
```

> Warning: The main branch frequently changes and may break Colab support. The above command pulls from the [`pre-release/0.3`](https://github.com/philipturner/swift-colab/tree/pre-release/0.3) branch.

In the output stream, you will see:

```
=== Downloading Swift ===
...
=== Swift successfully downloaded ===
...
=== Swift successfully installed ===
```

You will be instructed to restart the runtime. This is necessary because it shuts down the Python kernel and starts up the Swift kernel.

> Tip: If you factory reset the runtime or exceed the time limit, Colab will restart in Python mode. Just re-run the first code cell to return to Swift mode.

## Example of usage

Type the following code into the second code cell:

```swift
Int.bitWidth
```

After running it, the following output appears:

```
64
```

For more guidance on how to use Swift on Google Colab, check out [Usage Instructions](https://github.com/google/swift-jupyter#usage-instructions) on [google/swift-jupyter](https://github.com/google/swift-jupyter). There are some modifications you must make to how you use Swift on Google Colab, which are explained in the next section:

## Installing packages

To use Python interop or automatic differentiation, you must explicitly import their packages in first cell executed in Swift mode. Also, you cannot include `EnableJupyterDisplay.swift` (include `EnableIPythonDisplay.swift` instead). This differs from [google/swift-jupyter](https://github.com/google/swift-jupyter):

```swift
%install '.package(url: "https://github.com/pvieito/PythonKit.git", .branch("master"))' PythonKit
%install '.package(url: "https://github.com/philipturner/differentiation", .branch("main"))' _Differentiation
%include "EnableIPythonDisplay.swift"
import PythonKit
import Differentiation
```
