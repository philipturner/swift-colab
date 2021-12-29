from ctypes import *
from wurlitzer import sys_pipes
import IPython
import os

def precondition(ignored_argument):
    os.remove("/content/install_swift.sh")
    IPython.Application.instance().kernel.do_shutdown(True)

def run(swift_string):
    with sys_pipes():
        call_compiled_func("/opt/swift/lib/libSwiftPythonBridge.so", "runSwiftAsString", swift_string)

# the compiled Swift function must import the modified PythonKit
def call_compiled_func(executable_name, func_name, params):
    func = getattr(PyDLL(executable_name), func_name)
    func.restype, func.argtypes = c_void_p, [c_void_p]
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
        func_return_ptr = self.__call_swift(func_ptr_wrapper_ptr, c_void_p(id(params)))
        return cast(func_return_ptr, py_object).value.unwrap() # `func_return` is a `SwiftReturnValue`
    
    def __del__(self):
        call_compiled_func("/opt/swift/lib/libSwiftPythonBridge.so", "releaseFunctionTable", self.function_table)

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

# Interrupts currently-executing code whenever the process receives a SIGINT.
class SIGINTHandler(threading.Thread):
    def __init__(self, kernel):
        self.daemon = True
        super().__init__()
        self.kernel = kernel

    def run(self):
        try:
            while True:
                signal.sigwait([signal.SIGINT])
                self.kernel.process.SendAsyncInterrupt()
        except Exception as e:
            self.kernel.log.error(f"Exception in SIGINTHandler: {str(e)}")

# Collects stdout from the Swift process and sends it to the client.
class StdoutHandler(threading.Thread):
    def __init__(self, kernel):
        self.daemon = True
        super().__init__()
        Swift.call_compiled_func("/opt/swift/lib/libJupyterKernel.so", "JKCreateStdoutHandler", [self, kernel])
    
    def run(self):
        self.swift_delegate.call("run", self)
