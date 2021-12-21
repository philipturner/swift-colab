import subprocess as sp
import ctypes

# calling run_swift using thorugh a pre-compiled function should let stdout and stderr be synchronized with the Jupyter kernel.
def run(swift_string):
    p = sp.run(["bash", "/opt/swift/run_swift.sh", swift_string], stdout=sp.PIPE, stderr=sp.PIPE, text=True)
    print(p.stdout + p.stderr)

# the compiled Swift function must import the modified PythonKit
def call_compiled_func(executable_name, func_name, params):
    lib = ctypes.CDLL(executable_name)
    func = getattr(lib, func_name)
    func.restype, func.argtypes = c_void_p, [c_void_p]
    func_return_ptr = func(c_void_p(id(params)))
    return ctypes.cast(func_return_ptr, ctypes.py_object).value.unwrap() # `func_return` is a `SwiftReturnValue`

class SwiftDelegate:
    def __init__(self):
        self.function_table = {} # a `[String: Int]` dictionary of memory addresses of function wrappers, to be initialized in Swift
        self.__call_swift = ctypes.CDLL("/opt/swift/lib/libSwiftPythonBridge.so").callSwiftFromPython
        self.__call_swift.restype, self.__call_swift.argtypes = c_void_p, [c_void_p, c_void_p] # args accessed as `[PythonObject]` in Swift
    
    # params should have a `subscript(Int) -> PythonObject` method, will be copied into a `[PythonObject]`
    def call_swift_func(self, function_name, params): 
        func_ptr_wrapper_ptr = c_void_p(self.function_table[function_name]) # cast an integer to an `OpaquePointer`
        func_return_ptr = self.__call_swift(func_ptr_wrapper_ptr, c_void_p(id(params)))
        return ctypes.cast(func_return_ptr, ctypes.py_object).value.unwrap() # `func_return` is a `SwiftReturnValue`
    
class SwiftError(Exception):
    def __init__(self, localized_description)
        super().__init__(localized_description)
        
class SwiftReturnValue:
    def __init__(self, wrapped_object, error):
        self.__wrapped_object, self.__error = wrapped_object, error
        
    def unwrap(self):
        if self.__error is not None:
            assert isinstance(self.__error, SwiftError), "A SwiftReturnValue's error was not a SwiftError object."
            raise self.__error
        return self.__wrapped_object

class SwiftInteropTest(): 
    def __init__(self):
        self.swift_delegate = SwiftDelegate()
        
    def example_func(self, string_param):
        swift_delegate.call_swift_func("example_func", [self, string_param])
