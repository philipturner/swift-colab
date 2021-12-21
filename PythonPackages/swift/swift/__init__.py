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
class SwiftReturnValue: # need to initialize this given its id
    def __init(self, wrapped_value, error):
        self.wrappedvalue = wrapped_value
        self.error = error
