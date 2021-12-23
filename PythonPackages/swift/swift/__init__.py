import subprocess as sp
import ctypes

# calling run_swift using thorugh a pre-compiled function instead should let stdout and stderr be synchronized with the Jupyter kernel.
def run(swift_string):
    p = sp.run(["bash", "/opt/swift/run_swift.sh", swift_string], stdout=sp.PIPE, stderr=sp.PIPE, text=True)
    print(p.stdout + p.stderr)

def run_new(swift_string):
    call_compiled_func("/opt/swift/lib/libSwiftPythonBridge.so", "runSwiftAsString", swift_string)

# the compiled Swift function must import the modified PythonKit
def call_compiled_func(executable_name, func_name, params):
    lib = ctypes.CDLL(executable_name)
    func = getattr(lib, func_name)
    func.restype, func.argtypes = ctypes.c_void_p, [ctypes.c_void_p]
    func_return_ptr = func(ctypes.c_void_p(id(params)))
    return ctypes.cast(func_return_ptr, ctypes.py_object).value.unwrap() # `func_return` is a `SwiftReturnValue`
