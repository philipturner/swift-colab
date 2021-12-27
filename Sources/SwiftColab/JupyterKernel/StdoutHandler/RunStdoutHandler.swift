import Foundation
import PythonKit

func runStdoutHandler(_ selfRef: PythonObject) -> PythonObject {
    Python.None
}

fileprivate func getAndSendStdout(_ selfRef: PythonObject) throws {
    let stdout = PythonObject("").join(try getStdout(selfRef))
}

fileprivate func getStdout(_ selfRef: PythonObject) -> [PythonObject] throws {
    var output: [PythonObject] = []
    
    while true {
        let bufferSize: PythonObject = 1000
        let stdout_buffer = try self.kernel.process.GetSTDOUT.throwing
            .dynamicallyCall(withArguments: bufferSize)
        
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
fileprivate func sendStdout(kernel: PythonObject, stdout: PythonObject) throws {
    let clear_sequence: PythonObject = "\033[2J"
    let clear_sequence_index = stdout.find(clear_sequence)
    
    if Int(clear_sequence_index)! != -1 {
        try sendStdout(kernel: kernel, stdout:
                       stdout[...clear_sequence_index])
        
        try kernel.send_response.throwing.dynamicallyCall(withArguments:
            kernel.iopub_socket, "clear_output", ["wait": false])
       
        try sendStdout(kernel: kernel, stdout:
                       stdout[clear_sequence_index + Python.len(clear_sequence)...])
    } else {
        
    }
}
