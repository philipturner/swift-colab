import Foundation
import PythonKit

fileprivate func getStdout(_ selfRef: PythonObject) throws -> [PythonObject] {
    var output: [PythonObject] = []
    
    while true {
        let bufferSize: PythonObject = 1000
        let stdout_buffer = try selfRef.kernel.process.GetSTDOUT
            .throwing.dynamicallyCall(withArguments: bufferSize)
        
        if Python.len(stdout_buffer) == 0 {
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
    
    if clear_sequence_index != -1 {
        try sendStdout(kernel: kernel, stdout:
                       stdout[PythonObject(...clear_sequence_index)])
        
        try kernel.send_response.throwing.dynamicallyCall(withArguments:
            kernel.iopub_socket, "clear_output", ["wait": false])
       
        try sendStdout(kernel: kernel, stdout:
                       stdout[PythonObject(clear_sequence_index + Python.len(clear_sequence)...)])
    } else {
        try kernel.send_response.throwing.dynamicallyCall(withArguments:
            kernel.iopub_socket, "stream", ["name": "stdout", "text": stdout])
    }
}

fileprivate func getAndSendStdout(_ selfRef: PythonObject) throws {
    let stdout = PythonObject("").join(try getStdout(selfRef))
    
    if Python.len(stdout) > 0 {
        selfRef.had_stdout = true
        try sendStdout(kernel: selfRef.kernel, stdout: stdout)
    }
}

func runStdoutHandler(_ selfRef: PythonObject) -> PythonObject {
    do {
        while true {
            if Bool(selfRef.stop_event.wait(0.1))! {
                break
            }
            
            try getAndSendStdout(selfRef)
        }
        
        try getAndSendStdout(selfRef)
    } catch(let e) {
        selfRef.kernel.log.error("Exception in StdoutHandler: \(Python.str(e.localizedDescription))")
    }
}
