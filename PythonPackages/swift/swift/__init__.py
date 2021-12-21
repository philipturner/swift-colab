import subprocess as sp; import ctypes
def run(swift_string): # will change to directly call a Swift dynamic library via C interop. This should let stdout and stderr be synchronized with the Jupyter kernel.
    p = sp.run(["bash", "/opt/swift/run_swift.sh", swift_string], stdout=sp.PIPE, stderr=sp.PIPE, text=True); print(p.stdout + p.stderr)
class SwiftDelegate:
    def __init__(self):
        self.function_table = {} # a `[String: Int]` dictionary of memory addresses of function wrappers, to be initialized in Swift
        self.__bridge_lib = ctypes.CDLL("/opt/swift/lib/libSwiftPythonBridge.so")
        self.__bridge_lib.restype, self.__bridge_lib.argtypes = c_void_p, [c_void_p] # args accessed as `[PythonObject]` in Swift
    def call_swift_func(self, function_name, params): # params should have a `subscript(Int) -> PythonObject` method, will be copied into a `[PythonObject]`
        func_ptr_wrapper_ptr = c_void_p(self.function_table[function_name]) # cast an integer to an `OpaquePointer`
        func_return_ptr = self.__bridge_lib.callSwiftFromPython(c_void_p(id(params)))
        func_return = ctypes.cast(func_return_ptr, ctypes.py_object).value # `func_return` is a `SwiftReturnValue`
        if func_return.error is not None: # bridged from `nil` to `Python.None` in PythonKit
            raise func_return.error
        return func_return.wrapped_object # `None` if the Swift function doesn't return anything
class SwiftReturnValue:
    def __init__(self, wrapped_object, error): # `error` is created from a Swift `Error` (may need to make Python classes to help with bridging)
        self.wrapped_object, self.error = wrapped_object, error # `error` conforms to `BaseException`
class SwiftInteropTest(): # eventually, will try implementing this in a separate Python package - keeping in here rn for simplicity
    def __init__(self):
        self.swift_delegate = SwiftDelegate()
    def example_func(self, string_param):
        swift_delegate.call_swift_func("example_func", [self, string_param])
