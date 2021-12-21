import subprocess as sp; import ctypes
def run(swift_string): # will change to directly call a Swift dynamic library via C interop. This should let stdout and stderr be synchronized with the Jupyter kernel.
    p = sp.run(["bash", "/opt/swift/run_swift.sh", swift_string], stdout=sp.PIPE, stderr=sp.PIPE, text=True); print(p.stdout + p.stderr)
class SwiftObject:
    def __init__(self, function_table):
        self.function_table = function_table # a table of memory addresses of function pointer wrappers
        self.__bridge_lib = ctypes.CDLL("/opt/swift/libSwiftPythonBridge.so")
        self.__bridge_lib.restype, self.__bridge_lib.argtypes = c_void_p, [c_void_p]
    def call_swift_function(self, function_name, parameter):
        func_ptr_wrapper_ptr = c_void_p(self.function_table[function_name]) # cast an integer to an `OpaquePointer`
        func_return_ptr = self.__bridge_lib.callSwiftFromPython(c_void_p(id(parameter)))
        func_return = ctypes.cast(func_return_ptr, ctypes.py_object).value # `func_return` is a `SwiftReturnValue`
        if func_return.error is not None: # bridged from `nil` to `Python.None` in PythonKit
            raise func_return.error
        return func_return.wrapped_object # `None` if the Swift function doesn't return anything
        pass
class SwiftReturnValue:
    def __init__(self, wrapped_object, error): # inside the Swift code, `error` is created from a Swift PythonConvertibleError type
        self.wrapped_object, self.error = wrapped_object, error # `error` conforms to `BaseException`
