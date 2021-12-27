import Foundation
import PythonKit

func execute(_ selfRef: PythonObject, code: PythonObject) -> ExecutionResult {
    
}

fileprivate func file_name_for_source_location(_ selfRef: PythonObject) -> String {
    "<Cell \(selfRef.execution_count)>"
}
