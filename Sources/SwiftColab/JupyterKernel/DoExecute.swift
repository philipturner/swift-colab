import Foundation
import PythonKit
import SwiftPythonBridge

internal func doExecute(_ kwargs: PythonObject) throws -> PythonObject {
    struct Exception: Error {
        let localizedDescription = "Intentionally causing a crash from Swift"
    }
    
    throw Exception()
    
    return Python.None
}
