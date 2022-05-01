## Comment left to remain

It is possible to set up a semi-automated test...

## Purged Comment 1 (Dec 23, '21 10:10 AM) - likes: 3

I got `libSwiftPythonBridge.so` and `libPythonKit.so` to successfully link to a Swift script, then compiled and executed that script. Soon, I should be able to replace the Shell command for compiling a Swift string with a call into SwiftPythonBridge's C-compatible interface from Python. This might make the output from `print(...)` in Swift synchronize with the Jupyter kernel.

## Purged Comment 2 (Dec 23, '21 5:51 PM) - likes: 1

I got around a major bug with the Global Interpreter Lock, which had me really scared for a moment (I need to use `PyDLL` instead of `CDLL` in `ctypes`). I can now execute a Swift script by calling directly into the dynamic library's C interface. However, every call to `print(...)` goes to a hidden system output, instead of the Jupyter notebook's output. Previously, this is what happened, but I manually extracted that output and logged it to Jupyter's output.

Edit: Using [Wurlitzer](https://github.com/minrk/wurlitzer), I can restore output synchronization to how it was before, although you still have to wait until all of the code executes before reading any output.

## Purged Comment 3 (Dec 24, '21 4:06 PM) - likes: 2

I can now subclass Python objects and coordinate the logic of their methods to Swift ([repository save point #3](https://github.com/philipturner/swift-colab/tree/save-3)). The next step will be subclassing the Jupyter kernel and finding what restrictions Google added to it in March.

https://colab.research.google.com/drive/113MmiKUsd2ObeHwBOzA1STmclqazRom0?usp=sharing

Python code temporarily included in the `swift` Python package:
```python
class SwiftInteropTestSuperclass:
    pass
    
class SwiftInteropTest(SwiftInteropTestSuperclass): 
    def __init__(self):
        self.swift_delegate = SwiftDelegate()
        
    def example_func(self, string_param):
        return self.swift_delegate.call("example_func", [self, string_param])
    
    def example_func_2(self, string_param):
        return self.swift_delegate.call("example_func_2", { string_param: self })
```

Swift counterpart:
```swift
import PythonKit
import SwiftPythonBridge // this module is internal to Swift-Colab
let swiftModule = Python.import("swift")

let interopTest = swiftModule.SwiftInteropTest()

interopTest.registerFunction(name: "example_func") { param -> Void in
    print("example_func called from Python with param \(param)")
}
            
interopTest.registerFunction(name: "example_func_2") { param -> PythonConvertible in
    print("example_func_2 called from Python with param \(param)")
    return String("return value")
}

print(interopTest.example_func("Input string for example_func"))
print(interopTest.example_func_2("Input string for example_func_2"))
```

Output:
```
example_func called from Python with param [<swift.SwiftInteropTest object at 0x7f6c20490a90>, 'Input string for example_func']
None
example_func_2 called from Python with param {'Input string for example_func_2': <swift.SwiftInteropTest object at 0x7f6c20490a90>}
return value
```

## Purged Comment 4 (Dec 25, '21 12:40 PM) - likes: 1

I translated the `register.py` file in [google/swift-jupyter](https://github.com/google/swift-jupyter) to Swift and it runs without crashing. I still need to translate `swift_kernel.py`, which is larger and likely what's affected by Google's restrictions.

## Purged Comment 5 (Dec 25, '21 4:50 PM) - likes: 5

I got to the point where I can alter the behavior of Google Colab, making it output whatever the code cell puts as input. I had to manually overwrite some Python code, then restart the Jupyter runtime. Now that I got to this point, I'm very confident I can follow through all the way and bring back Swift support to its state before the death of S4TF. Code completion, syntax coloring, everything.

## Purged Comment 6 (Dec 25, '21 6:37 PM) - likes: 3

Syntax coloring is working. All I had to do was clone an S4TF tutorial, inspect its metadata, and copy that over to a blank notebook.

Open the notebook template in Colab, and the text is syntax-colored like Swift instead of Python. For example, an `import` statement is blue and green (Swift) instead of purple and white (Python).

## Purged Comment 7 (Dec 25, '21 9:14 PM) - likes: 8

Swift on Google Colab has entered the beta stage! Executing code is still in the works, but you can follow the steps of side-loading and prepare for when it's feature-complete. Check out the [README](https://github.com/philipturner/swift-colab) or the Colab notebook:

https://colab.research.google.com/drive/1EACIWrk9IWloUckRm3wu973bKUBXQDKR?usp=sharing

## Purged Comment 8 (Dec 26, '21 9:01 PM) - likes: 0

Translated the `StdoutHandler` from the original Jupyter kernel's `swift_kernel.py` to Swift (won't get around to testing it for quite a while):

https://github.com/philipturner/swift-colab/blob/main/Sources/SwiftColab/JupyterKernel/StdoutHandler/RunStdoutHandler.swift

## Purged Comment 9 (Dec 28, '21 1:45 PM) - likes: 7

Just finished translating the entire Swift kernel from Python to Swift. Now, it's time for heavy testing and experiencing many painful bugs :frowning:.

## Purged Comment 10 (Dec 28, '21 7:12 PM) - likes: 2

The S4TF team was right. There were major restrictions on LLDB, but I just bypassed them!

## Purged Comment 11 (Dec 28, '21 8:59 PM) - likes: 4

Due to some major additions to the Swift Package manager since S4TF died, I need to rework the Jupyter kernel's Swift package loader. I'm aiming to remove the restriction that you can't execute % commands outside of the first cell.

By the way, I got a very basic line of Swift code to execute in Colab.
```swift
Int.bitWidth
```
```swift
64
```

## Comment left to remain

Swift-Colab is complete! Several tutorials...
