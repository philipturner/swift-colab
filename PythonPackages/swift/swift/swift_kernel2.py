#!/usr/bin/python3
import swift
import wurlitzer
import signal

from ctypes import *

print("hello world 2")

SwiftError = swift.SwiftError

if __name__ == "__main__":
    print("called main 0")
else:
    print("did not call main 0")
