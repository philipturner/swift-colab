#!/usr/bin/python3
import os
import signal
import Swift
import sys

from ctypes import *
from ipykernel.kernelbase import Kernel

class SwiftKernel(Kernel):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        Swift.call_compiled_func("/opt/swift/lib/libJupyterKernel.so", "JKCreateKernel", self)
    
    def do_execute(self, code, silent, store_history=True,
                   user_expressions=None, allow_stdin=False):
        return self.swift_delegate.call("do_execute", {
            "self": self,
            "code": code,
            "silent": silent,
            "store_history": store_history,
            "user_expressions": user_expressions,
            "allow_stdin": allow_stdin,
        })
    
    def do_complete(self, code, cursor_pos):
        return self.swift_delegate.call("do_complete", {
            "self": self,
            "code": code,
            "cursor_pos": cursor_pos,
        })
    
    def lambda1(src_folder):
        def extract(input):
            return input
        return extract(lambda m: 'header "%s"' %
            (m.group(1) if os.path.isabs(m.group(1)) else os.path.abspath(os.path.join(src_folder, m.group(1))))
        )
                        

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
