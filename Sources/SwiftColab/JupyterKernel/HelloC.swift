import PythonKit
import SwiftPythonBridge
import Foundation
fileprivate let swiftModule = Python.import("swift")

@_cdecl("helloC")
public func helloC(_ meaningOfLife: Int32) -> Int32 {
    print("meaning of life: \(meaningOfLife)")

    let interopTest = swiftModule.SwiftInteropTest()

    // Direct the logic of SwiftInteropTest's methods from Python to Swift

    interopTest.registerFunction(name: "example_func") { param -> Void in
        print("example_func called from Python with param \(param)")
    }

    interopTest.registerFunction(name: "example_func_2") { param -> PythonConvertible in
        print("example_func_2 called from Python with param \(param)")
        return String("return value")
    }

    interopTest.registerFunction(name: "example_func_3") { param -> PythonObject in
        print("example_func_3 called from Python with param \(param)")
        return PythonObject("return value")
    }

    print(interopTest.example_func("Input string for example_func"))
    print(interopTest.example_func_2("Input string for example_func_2"))
    print(interopTest.example_func_3("Input string for example_func_3"))

    return meaningOfLife + 100
}
