import IPython
import os
import signal
import threading

from ctypes import *
from wurlitzer import sys_pipes

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
        super().__init__()
        self.daemon = True
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
        super().__init__()
        call_compiled_func("/opt/swift/lib/libJupyterKernel.so", "JKCreateStdoutHandler", [self, kernel])
    
    def run(self):
        self.swift_delegate.call("run", self)

# From swift_shell

from ipykernel.zmqshell import ZMQInteractiveShell
from jupyter_client.session import Session

class CapturingSocket:
    """Simulates a ZMQ socket, saving messages instead of sending them.
    We use this to capture display messages.
    """

    def __init__(self):
        self.messages = []

    def send_multipart(self, msg, **kwargs):
        self.messages.append(msg)


class SwiftShell(ZMQInteractiveShell):
    """An IPython shell, modified to work within Swift."""

    def enable_gui(self, gui):
        """Disable the superclass's `enable_gui`.
        `enable_matplotlib("inline")` calls this method, and the superclass's
        method fails because it looks for a kernel that doesn't exist. I don't
        know what this method is supposed to do, but everything seems to work
        after I disable it.
        """
        pass

def create_shell(username, session_id, key):
    """Instantiates a CapturingSocket and SwiftShell and hooks them up.
    
    After you call this, the returned CapturingSocket should capture all
    IPython display messages.
    """
    socket = CapturingSocket()
    session = Session(username=username, session=session_id, key=key)
    shell = SwiftShell.instance()
    shell.display_pub.session = session
    shell.display_pub.pub_socket = socket
    return [socket, shell]
