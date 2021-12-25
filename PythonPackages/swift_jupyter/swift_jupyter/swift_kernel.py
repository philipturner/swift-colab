#!/usr/bin/python
# this file must have chmod set to a+x

# define a subclass of jupyter's Kernel class
# define any other absolutely necessary subclasses

if __name__ == "__main__":
    # register the kernel in IPKernelApp
    print("called main")
else:
    # should never be called
    print("did not call main")
""")
