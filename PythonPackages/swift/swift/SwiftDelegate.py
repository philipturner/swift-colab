from ctypes import *

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
    def __init__(self, localized_description) # created from the Swift Error's `localizedDescription`
        super().__init__(localized_description)
        
class SwiftReturnValue:
    def __init__(self, wrapped, error):
        self.__wrapped, self.__error = wrapped, error
        
    def unwrap(self):
        if self.__error is not None:
            assert isinstance(self.__error, SwiftError), "A SwiftReturnValue's error was not a SwiftError object."
            raise self.__error
        return self.__wrapped
