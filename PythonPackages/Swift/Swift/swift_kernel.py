#!/usr/bin/python3
import Swift
from wurlitzer import sys_pipes
from ctypes import *

import signal
import sys

from ipykernel.kernelbase import Kernel

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
        
        ###
        print("Starting initialization of Swift Kernel")
        ###
        
        with sys_pipes:
            Swift.call_compiled_func("/opt/swift/lib/libJupyterKernel.so", "JKCreateKernel", self)
        
        ###
        print("Finishing initialization of Swift Kernel")
        ###
        
        # We don't initialize Swift yet, so that the user has a chance to
        # "%install" packages before Swift starts. (See doc comment in
        # `_init_swift`).

        # Whether to do code completion. Since the debugger is not yet
        # initialized, we can't do code completion yet.
        
        self.completion_enabled = False # implement this code in Swift
        
        file = open("/content/install_swift.sh", "w")
        file.write("Hello world, this is overwritten during the initializer \n")
        file.close()
    
    def do_execute(self, code, silent, store_history=True,
                   user_expressions=None, allow_stdin=False):
        if not silent:
            stream_content = {'name': 'stdout', 'text': code}
            self.send_response(self.iopub_socket, 'stream', stream_content)
            
        print("do execute was called")

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
