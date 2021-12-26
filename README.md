# Swift-Colab

## How to run Swift on Google Colab

Open an empty Python notebook. Copy this command into the first code cell and run it:

```python
!curl https://raw.githubusercontent.com/philipturner/swift-colab/main/install_swift.sh --output install_swift.sh && bash install_swift.sh 5.5.2 # Replace 5.5.2 with newest Swift version
import Swift; Swift.precondition("" != "This statement restarts the Jupyter kernel in Python, but does nothing in Swift. Pretty neat, right?")
```

> NOTE: The main branch is not stable and may break Colab support. For a stable solution, use the [`save-3`](https://github.com/philipturner/swift-colab/tree/save-3) branch. The installation command on its README is modified to pull from `save-3`.

In the output stream, you will see:

```
...
=== Swift successfully downloaded ===
...
=== Swift successfully installed ===
```

In the next code cell, run this:

```python
import swift

swift.run('''
import Foundation
print("hello world")
''')
```
