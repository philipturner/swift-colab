import Foundation
import PythonKit
import SwiftPythonBridge

internal func doExecute(_ kwargs: PythonObject) throws -> PythonObject {
    struct Exception: LocalizedError {
        let errorDescription: String? = "Intentionally causing a crash from Swift"
    }
    
    throw Exception()
    
    return Python.None
}
