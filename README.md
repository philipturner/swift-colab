# Swift-Colab

> Note: This is only public to let me download its files on Google Colab. Do not rely on this for guidance on using Swift on Colab yet.

## How to run Swift on Google Colab

Open an empty Python notebook. Copy this command into the first code cell and run it:

```bash
!curl https://raw.githubusercontent.com/philipturner/swift-colab/main/install_swift.sh --output install_swift.sh && bash install_swift.sh 5.5.2
```

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
