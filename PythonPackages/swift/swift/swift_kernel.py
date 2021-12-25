#!/usr/bin/python3
import swift
from wurlitzer import sys_pipes
import signal

from ctypes import *

# symbols for the Jupyter kernel

# ...
print("hello world 2")

f = open("install_swift.sh", "w")
f.write("message from swift_kernel.py")
f.close()

# define a subclass of jupyter's Kernel class
# define any other absolutely necessary subclasses - some may be declared in `swift` module so that Swift code can import them

SwiftError = swift.SwiftError

if __name__ == "__main__":
    print("called main 0")
    
    signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
    
    print(swift.SwiftDelegate)
    print(SwiftError)
    
#     with sys_pipes():
#         print("called main")
#    
    
    # register the kernel in IPKernelApp
    # may need to use wurlitzer.sys_pipes - must validate that the called Swift code can log to output
#     with sys_pipes(): # if logging doesn't work, try writing to a file
#         print("called main")
#         print(swift.SwiftDelegate)
#         print(SwiftError)

