// Small dynamic library for calling Swift functions from Python.
// Can also be imported by Swift because it declares the PythonObject
// methods for managing the function table of a `SwiftDelegate`.

import PythonKit
let globalSwiftModule = Python.import("swift")
