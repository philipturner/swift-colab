#!/usr/bin/python3
import swift
from wurlitzer import sys_pipes
from ctypes import *

import signal
import sys

from ipykernel.kernelbase import Kernel

class SwiftKernel(Kernel):
    implementation = 'SwiftKernel'
    implementation_version = '0.1'
    banner = "This is the Swift Jupyter kernel's banner. Once it is verified to appear, it may be removed from the source code."

    language_info = {
        'name': 'swift',
        'mimetype': 'text/x-swift',
        'file_extension': '.swift',
        'version': '5',
        'pygments_lexer': 'pygments.lexers.objective.SwiftLexer'
    }
    
    def __init__(self, **kwargs):
        print("Hello world, creating SwiftKernel")
        super().__init__(**kwargs)
        
        # We don't initialize Swift yet, so that the user has a chance to
        # "%install" packages before Swift starts. (See doc comment in
        # `_init_swift`).

        # Whether to do code completion. Since the debugger is not yet
        # initialized, we can't do code completion yet.
        self.completion_enabled = False # this line can be implemented in the Swift code
        
        file = open("/content/install_swift.sh", "w")
        file.write("Hello world, this is overwritten during the initializer \n")
        file.close()
    
    def do_execute(self, code, silent, store_history=True,
                   user_expressions=None, allow_stdin=False):
        if not silent:
            stream_content = {'name': 'stdout', 'text': code}
            self.send_response(self.iopub_socket, 'stream', stream_content)

        return {'status': 'ok',
                # The base class increments the execution count
                'execution_count': self.execution_count,
                'payload': [],
                'user_expressions': {},
               }
    
# define any other absolutely necessary subclasses - some may be declared in `swift` module so that Swift code can import them

if __name__ == "__main__":
    print("called swift_kernel.py")
    
    signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
    
    from ipykernel.kernelapp import IPKernelApp
    
    IPKernelApp.launch_instance(
        argv=sys.argv + ["--IPKernelApp.kernel_class=__main__.SwiftKernel"])
