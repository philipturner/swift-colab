class SwiftInteropTest(): 
    def __init__(self):
        self.swift_delegate = SwiftDelegate()
        
    def example_func(self, string_param):
        swift_delegate.call_swift_func("example_func", [self, string_param])
