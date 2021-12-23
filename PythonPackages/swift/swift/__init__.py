import subprocess as sp
from ctypes import *

# calling run_swift using thorugh a pre-compiled function instead should let stdout and stderr be synchronized with the Jupyter kernel.
def run(swift_string):
    p = sp.run(["bash", "/opt/swift/run_swift.sh", swift_string], stdout=sp.PIPE, stderr=sp.PIPE, text=True)
    print(p.stdout + p.stderr)

def run_new(swift_string):
    print("runSwift checkpoint 0")
    call_compiled_func("/opt/swift/lib/libSwiftPythonBridge.so", "runSwiftAsString", swift_string)
    print("runSwift checkpoint 6")

# the compiled Swift function must import the modified PythonKit
def call_compiled_func(executable_name, func_name, params):
    lib = CDLL(executable_name)
    func = getattr(lib, func_name)
    func.restype, func.argtypes = c_void_p, [c_void_p]
    func_return_ptr = func(c_void_p(id(params)))
    print("runSwift checkpoint 4")
    output = cast(func_return_ptr, py_object).value.unwrap() # `func_return` is a `SwiftReturnValue`
    print("runSwift checkpoint 5")
    return output

class SwiftDelegate:
    def __init__(self):
        self.function_table = {} # a `[String: Int]` dictionary of memory addresses of function wrappers, to be initialized in Swift
        self.__call_swift = CDLL("/opt/swift/lib/libSwiftPythonBridge.so").callSwiftFromPython
        self.__call_swift.restype, self.__call_swift.argtypes = c_void_p, [c_void_p, c_void_p] # args accessed as `[PythonObject]` in Swift
    
    # params should have a `subscript(Int) -> PythonObject` method, will be copied into a `[PythonObject]`
    def call_func(self, function_name, params): 
        func_ptr_wrapper_ptr = c_void_p(self.function_table[function_name]) # cast an integer to an `OpaquePointer`
        func_return_ptr = self.__call_swift(func_ptr_wrapper_ptr, c_void_p(id(params)))
        return cast(func_return_ptr, py_object).value.unwrap() # `func_return` is a `SwiftReturnValue`
    
class SwiftError(Exception):
    def __init__(self, localized_description): # created from the Swift Error's `localizedDescription`
        super().__init__(localized_description)
        
class SwiftReturnValue:
    def __init__(self, wrapped, error):
        self.__wrapped, self.__error = wrapped, error
        
    def unwrap(self):
        if self.__error is not None:
            assert isinstance(self.__error, SwiftError), "A SwiftReturnValue's error was not a SwiftError object."
            raise self.__error
        return self.__wrapped

class SwiftInteropTest(): 
    def __init__(self):
        self.swift_delegate = SwiftDelegate()
        
    def example_func(self, string_param):
        self.swift_delegate.call_func("example_func", [self, string_param])
