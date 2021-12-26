# Swift-Colab

## How to run Swift on Google Colab

Open [this template] for a Swift Colab notebook. Do not create one directly from Google Drive, as that is configured for Python. Copy the following command into the first code cell and run it:

```python
!curl https://raw.githubusercontent.com/philipturner/swift-colab/pre-release/0.1/install_swift.sh --output install_swift.sh && bash install_swift.sh 5.5.2 # Replace 5.5.2 with newest Swift version
import Swift; Swift.precondition("" != "This statement restarts the Jupyter kernel in Python, but does nothing in Swift. Pretty neat, right?")
```

The main branch frequently changes and may break Colab support. The above command pulls from the (not yet made) [`pre-release/0.1`](https://github.com/philipturner/swift-colab/tree/pre-release/0.1) branch.

In the output stream, you will see:

```
...
=== Downloading Swift ===
...
=== Swift successfully downloaded ===
...
=== Swift successfully installed ===
...
(a brief message about why Google Colab was intentionally crashed)
```

The kernel will crash and automatically reconnect. That's expected, because it refreshes the runtime and lets Swift override the Python kernel.

> Note: If you factory reset the runtime or exceed the time limit, Colab will restart in Python mode. Just re-run the first code cell, and you will return to Swift mode.

Type anything into the next code cell, and it will echo in the output. At this time, I have achieved side-loading a new kernel and changing the syntax coloring. Compilation and syntax coloring are still in the works.
