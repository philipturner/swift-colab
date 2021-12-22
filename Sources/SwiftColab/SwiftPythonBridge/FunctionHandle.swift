import PythonKit

class FunctionHandle {
    let returnsObject: Bool
    let unsafeFunctionPointer: () -> Void
    
    init(wrapping functionPointer: @escaping (PythonObject) throws -> Void) {
        returnsObject = false
        unsafeFunctionPointer = unsafeBitCast(functionPointer, to: (() -> Void).self)
    }
}

public extension PythonObject {
    // register a Swift function handle in its vtable
}
