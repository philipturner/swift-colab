import Foundation
import PythonKit

func runStdoutHandler(_ selfRef: PythonObject) -> PythonObject {
    do {
        while true {
            if Bool(selfRef.stop_event.wait(0.1))! {
                break
            }
            
            try get_and_send_stdout(selfRef)
        }
        
        try get_and_send_stdout(selfRef)
    } catch(let e) {
        selfRef.kernel.log.error("Exception in StdoutHandler: \(Python.str(e.localizedDescription))")
    }
    
    return Python.None
}

fileprivate func get_stdout(_ selfRef: PythonObject) throws -> [PythonObject] {
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
fileprivate func send_stdout(kernel: PythonObject, stdout: PythonObject) throws {
    let clear_sequence: PythonObject = "\033[2J"
    let clear_sequence_index = stdout.find(clear_sequence)
    let clear_sequence_length = Python.len(clear_sequence)
    
    if clear_sequence_index != -1 {
        try send_stdout(kernel: kernel, stdout:
                        stdout[(..<clear_sequence_index).pythonObject])
        
        try kernel.send_response.throwing.dynamicallyCall(withArguments:
            kernel.iopub_socket, "clear_output", ["wait": false])
            

        try send_stdout(kernel: kernel, stdout:
                        stdout[((clear_sequence_index + clear_sequence_length)...).pythonObject])
    } else {
        try kernel.send_response.throwing.dynamicallyCall(withArguments:
            kernel.iopub_socket, "stream", ["name": "stdout", "text": stdout])
    }
}

fileprivate func get_and_send_stdout(_ selfRef: PythonObject) throws {
    let stdout = PythonObject("").join(try get_stdout(selfRef))
    
    if Python.len(stdout) > 0 {
        selfRef.had_stdout = true
        try send_stdout(kernel: selfRef.kernel, stdout: stdout)
    }
}
