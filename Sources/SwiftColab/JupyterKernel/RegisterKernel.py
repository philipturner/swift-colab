from ctypes import *
from wurlitzer import sys_pipes

with sys_pipes():
    print("checkpoint 1")
    func = PyDLL("/opt/swift/lib/libJupyterKernel.so").JKRegisterKernel
    print("checkpoint 2")
    func()
    print("checkpoint 3")
  
