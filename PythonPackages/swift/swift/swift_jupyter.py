#!/usr/bin/python
# this file must have chmod set to a+x
import ctypes

# define a subclass of jupyter's Kernel class
# define any other absolutely necessary subclasses

# see if I can import stuff declared in __init__.py

if __name__ == "__main__":
    # register the kernel in IPKernelApp
    print("called main")
    print(SwiftDelegate)
else:
    # should never be called
    print("did not call main")
