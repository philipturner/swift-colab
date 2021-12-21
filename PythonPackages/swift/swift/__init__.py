import subprocess as sp
import ctypes
def run(swift_string): # will change to directly call a Swift dynamic library via C interop. This should let stdout and stderr be synchronized with the Jupyter kernel.
    p = sp.run(["bash", "/opt/swift/run_swift.sh", swift_string], stdout=sp.PIPE, stderr=sp.PIPE, text=True); print(p.stdout + p.stderr)
class SwiftObject:
    def __init__(self, function_table):
        self.function_table = function_table # a table of 64-bit pointers to function pointer wrappers
        self.__bridge_lib = ctypes.CDLL("/opt/swift/libSwiftPythonBridge.so")
        self.__bridge_lib.restype = c_void_p; self.__bridge_lib.argtypes = [c_void_p]
        # call a C function on the return value, which optionally returns an error. The return value is a wrapper over the actual returned object
    def call_swift(self, function_name):
        function_wrapper_address = c_void_p(self.function_table[function_name]) # cast an integer to an `OpaquePointer`
#         function_return = self.__bridge_lib(
        
        # call the lib's `callSwiftFromPython` function
        # initialize the `SwiftReturnValue` given the id
        # if the error object isn't `None`, raise an exception/error
        # otherwise, return the wrapped_object (it might be `None`)
        pass
class SwiftReturnValue:
    def __init__(self, wrapped_object, error):
        self.wrapped_object = wrapped_object
        self.error = error # inside the Swift code, this is created from a Swift PythonConvertibleError
