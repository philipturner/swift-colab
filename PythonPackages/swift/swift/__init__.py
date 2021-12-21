import subprocess as sp
import ctypes
def run(swift_string): # will change to directly call a Swift dynamic library via C interop. This should let stdout and stderr be synchronized with the Jupyter kernel.
    p = sp.run(["bash", "/opt/swift/run_swift.sh", swift_string], stdout=sp.PIPE, stderr=sp.PIPE, text=True); print(p.stdout + p.stderr)
class SwiftObject:
    def __init__(self, function_table):
        self.function_table = function_table
        self.__lib = ctypes.CDLL("/opt/swift/libSwiftPythonBridge.so")
