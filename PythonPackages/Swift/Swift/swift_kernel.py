#!/usr/bin/python3
import Swift
from wurlitzer import sys_pipes
from ctypes import *

import signal
import sys

from ipykernel.kernelbase import Kernel

def log(message, mode="a"):
    with open("/content/install_swift.sh", mode) as f:
        f.write(message + "\n")

class SwiftKernel(Kernel):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        Swift.call_compiled_func("/opt/swift/lib/libJupyterKernel.so", "JKCreateKernel", self)
    
    def do_execute(self, code, silent, store_history=True,
                   user_expressions=None, allow_stdin=False):
        log("Do execute was called")
        self.swift_delegate.call("do_execute", {
            "self": self,
            "code": code,
            "silent": silent,
            "store_history": store_history,
            "user_expressions": user_expressions,
            "allow_stdin": allow_stdin
        })
        log("Do execute completed")
        
        if not silent:
            stream_content = {'name': 'stdout', 'text': code}
            self.send_response(self.iopub_socket, 'stream', stream_content)
        
        return {'status': 'ok',
                # The base class increments the execution count
                'execution_count': self.execution_count,
                'payload': [],
                'user_expressions': {},
               }
    
# define any other absolutely necessary subclasses - some may be declared in `Swift` module so that Swift code can import them

if __name__ == "__main__":
    # Jupyter sends us SIGINT when the user requests execution interruption.
    # Here, we block all threads from receiving the SIGINT, so that we can
    # handle it in a specific handler thread.
    signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
    
    from ipykernel.kernelapp import IPKernelApp
    # We pass the kernel name as a command-line arg, since Jupyter gives those
    # highest priority (in particular overriding any system-wide config).
    IPKernelApp.launch_instance(
        argv=sys.argv + ["--IPKernelApp.kernel_class=__main__.SwiftKernel"])
