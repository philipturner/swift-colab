import swift
from ctypes import *
import wurlitzer

# symbols for the Jupyter kernel

# ...

# define a subclass of jupyter's Kernel class
# define any other absolutely necessary subclasses

SwiftError = swift.SwiftError

if __name__ == "__main__":
    # register the kernel in IPKernelApp
    # may need to use wurlitzer.sys_pipes - must validate that the called Swift code can log to output
    print("called main")
    print(swift.SwiftDelegate)
    print(__main__.SwiftError)
else:
    # should never be called
    print("did not call main")
