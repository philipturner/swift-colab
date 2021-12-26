#!/usr/bin/python3
import Swift
from wurlitzer import sys_pipes
from ctypes import *

import signal
import sys

from ipykernel.kernelbase import Kernel

def log(message, mode="a"):
    file = open("/content/install_swift.sh", mode)
    file.write(message + "\n")
    file.close()

class SwiftKernel(Kernel):
    implementation = 'SwiftKernel' # comment out the default initialization of all of these once I have verified the Swift code doesn't crash
    implementation_version = '0.1'
    banner = ''

    language_info = {
        'name': 'swift',
        'mimetype': 'text/x-swift',
        'file_extension': '.swift',
        'version': ''
    }
    
    # TODO: Move the property initialization (shown above) out of Python and into Swift code
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        Swift.call_compiled_func("/opt/swift/lib/libJupyterKernel.so", "JKCreateKernel", self)
        
        log("Swift Kernel successfully initialized", mode="w")
    
    def do_execute(self, code, silent, store_history=True,
                   user_expressions=None, allow_stdin=False):
        log("Do execute was called")
        
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
