from ctypes import *
from wurlitzer import sys_pipes

def run(swift_string):
    call_compiled_func("/opt/swift/lib/libSwiftPythonBridge.so", "runSwiftAsString", swift_string)

# the compiled Swift function must import the modified PythonKit
def call_compiled_func(executable_name, func_name, params):
    lib = PyDLL(executable_name)
    func = getattr(lib, func_name)
    func.restype, func.argtypes = c_void_p, [c_void_p]
    with sys_pipes():
        func_return_ptr = func(c_void_p(id(params)))
    output = cast(func_return_ptr, py_object).value.unwrap() # `func_return` is a `SwiftReturnValue`
    return output

class SwiftDelegate:
    def __init__(self):
        self.function_table = {} # a `[String: Int]` dictionary of memory addresses of function wrappers, to be initialized in Swift
        self.__call_swift = PyDLL("/opt/swift/lib/libSwiftPythonBridge.so").callSwiftFromPython
        self.__call_swift.restype, self.__call_swift.argtypes = c_void_p, [c_void_p, c_void_p]
    
    def call(self, function_name, params): 
        func_ptr_wrapper_ptr = c_void_p(self.function_table[function_name]) # cast an integer to an `OpaquePointer`
        with sys_pipes():
            func_return_ptr = self.__call_swift(func_ptr_wrapper_ptr, c_void_p(id(params)))
        return cast(func_return_ptr, py_object).value.unwrap() # `func_return` is a `SwiftReturnValue`
    
    def call_2(self, function_name, params):
        self.call(function_name, params)
        
    def call_3(self, function_name, params):
        print("call_3 intro")
        self.call(function_name, params)
        print("call_3 outtro")
        
    def call_alt(self, function_name, params): 
        func_ptr_wrapper_ptr = c_void_p(self.function_table[function_name]) # cast an integer to an `OpaquePointer`
        func_return_ptr = self.__call_swift(func_ptr_wrapper_ptr, c_void_p(id(params)))
        return cast(func_return_ptr, py_object).value.unwrap() # `func_return` is a `SwiftReturnValue`
    
    def call_2_alt(self, function_name, params):
        with sys_pipes():
            self.call_alt(function_name, params)
        
    def call_3_alt(self, function_name, params):
        print("call_3_alt intro")
        with sys_pipes():
            self.call_alt(function_name, params)
        print("call_3_alt outtro")
    
class SwiftError(Exception):
    def __init__(self, localized_description):
        super().__init__(localized_description)
        
class SwiftReturnValue:
    def __init__(self, wrapped, error):
        self.__wrapped, self.__error = wrapped, error
        
    def unwrap(self):
        if self.__error is not None:
            assert(isinstance(self.__error, SwiftError), "A SwiftReturnValue's error was not a SwiftError object.")
            raise self.__error
        return self.__wrapped

class SwiftInteropTest(): 
    def __init__(self):
        self.swift_delegate = SwiftDelegate()
        
    def example_func(self, string_param):
        return self.swift_delegate.call("example_func", [self, string_param])
