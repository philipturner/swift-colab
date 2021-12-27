import Foundation
import PythonKit

func runStdoutHandler(_ selfRef: PythonObject) -> PythonObject {
    Python.None
}

fileprivate func getAndSendStdout(_ selfRef: PythonObject) throws {
    
}

fileprivate func getStdout(_ selfRef: PythonObject) -> [PythonObject] throws {
    var output: [PythonObject] = []
    
    while true {
        let BUFFER_SIZE: PythonObject = 1000
        let stdout_buffer = try self.kernel.process.GetSTDOUT.throwing
            .dynamicallyCall(withArguments: BUFFER_SIZE)
        
        if Int(Python.len(stdout_buffer))! == 0 {
            break
        }
        
        output.append(stdout_buffer)
    }
    
    return output
}

// Sends stdout to the jupyter client, replacing the ANSI sequence for
// clearing the whole display with a 'clear_output' message to the jupyter
// client.
fileprivate func sendStdout(_ selfRef: PythonObject, stdout: PythonObject) throws {
    
}
