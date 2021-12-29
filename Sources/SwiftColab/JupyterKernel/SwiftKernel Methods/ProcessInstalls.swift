import Foundation
import PythonKit

fileprivate let os = Python.import("os")
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")
fileprivate let stat = Python.import("stat")
fileprivate let string = Python.import("string")
fileprivate let subprocess = Python.import("subprocess")

/// Handles all "%install" directives, and returns `code` with all
/// "%install" directives removed.
func process_installs(_ selfRef: PythonObject, code: PythonObject) throws -> PythonObject {
    var processed_lines: [PythonObject] = []
    var all_packages: [PythonObject] = []
    var all_swiftpm_flags: [PythonObject] = []
    var extra_include_commands: [PythonObject] = []
    var user_install_location: PythonObject?
    
    let lines = code[dynamicMember: "split"]("\n")
    
    for index in (0..<lines.count).map(PythonObject.init) {
        var line = lines[index]
        try process_system_command_line(selfRef, &line)
        
        if let install_location = try process_install_location_line(selfRef, index, &line) {
            user_install_location = install_location
        }
        
        all_swiftpm_flags += process_install_swiftpm_flags_line(selfRef, &line)
        all_packages += try process_install_line(selfRef, index, &line)
        
        if let extra_include_command = process_extra_include_command_line(selfRef, &line) {
            extra_include_commands.append(extra_include_command)
        }
        
        processed_lines.append(line)
    }
    
    try install_packages(selfRef, 
                         packages: all_packages,
                         swiftpm_flags: all_swiftpm_flags,
                         extra_include_commands: extra_include_commands,
                         user_install_location: user_install_location)
    
    return PythonObject("\n").join(processed_lines)
}

func link_extra_includes(_ selfRef: PythonObject, _ swift_module_search_path: PythonObject, _ include_dir: PythonObject) throws {
    for include_file in os.listdir(include_dir) {
        let link_name = os.path.join(swift_module_search_path, include_file)
        let target = os.path.join(include_dir, include_dir)
        
        try call_unlink(link_name: link_name)
        os.symlink(target, link_name)
    }
}

func call_unlink(link_name: PythonObject) throws {
    do {
        @discardableResult
        func call(_ function: PythonObject, _ param: PythonObject) throws -> PythonObject {
            try function.throwing.dynamicallyCall(withArguments: param)
        }

        let st_mode = try call(os.lstat, link_name)
        if Bool(try call(stat.S_ISLNK, st_mode))! {
            try call(os.unlink, link_name)
        }
    } catch PythonError.exception(let error, let traceback) {
        let e = PythonError.exception(error, traceback: traceback)

        if error.__class__ == Python.FileNotFoundError {
            // pass
        } else if error.__class__ == Python.Error {
            throw PackageInstallException(
                "Failed to stat scratchwork base path: \(e)")
        }
    }
}

fileprivate func process_install_location_line(_ selfRef: PythonObject, _ line_index: PythonObject, _ line: inout PythonObject) throws -> PythonObject? {
    let install_location_match = re.match(###"""
    ^\s*%install-location (.*)$
    """###, line)
    guard install_location_match != Python.None else { return nil }
    
    var install_location = install_location_match.group(1)
    try process_install_substitute(template: &install_location, line_index: line_index)
    
    line = ""
    return install_location
}

fileprivate func process_extra_include_command_line(_ selfRef: PythonObject, _ line: inout PythonObject) -> PythonObject? {
    let extra_include_command_match = re.match(###"""
    ^\s*%install-extra-include-command (.*)$
    """###, line)
    guard extra_include_command_match != Python.None else { return nil }
    
    line = ""
    return extra_include_command_match.group(1)
}

fileprivate func process_install_swiftpm_flags_line(_ selfRef: PythonObject, _ line: inout PythonObject) -> [PythonObject] {
    let flags_match = re.match(###"""
    ^\s*%install-swiftpm-flags (.*)$
    """###, line)
    guard flags_match != Python.None else { return [] }
    
    line = ""
    return Array(flags_match.group(1))
}

fileprivate func process_install_line(_ selfRef: PythonObject, _ line_index: PythonObject, _ line: inout PythonObject) throws -> [PythonObject] {
    let install_match = re.match(###"""
    ^\s*%install (.*)$
    """###, line)
    guard install_match != Python.None else { return [] }
    
    let parsed = shlex[dynamicMember: "split"](install_match.group(1))
    guard Python.len(parsed) >= 2 else {
        throw PackageInstallException(
            "Line: \(line_index + 1): %install usage: SPEC PRODUCT [PRODUCT ...]")
    }
    
    try process_install_substitute(template: &parsed[0], line_index: line_index)
    
    line = ""
    return [[
        "spec": parsed[0],
        "products": parsed[1...]
    ]]
}

fileprivate func process_system_command_line(_ selfRef: PythonObject, _ line: inout PythonObject) throws {
    let system_match = re.match(###"""
    ^\s*%system (.*)$
    """###, line)
    guard system_match != Python.None else { return }
    
//     if selfRef.checking.debugger != nil {
//         throw PackageInstallException(
//             "System commands can only run in the first cell.")
//     }
    
    let rest_of_line = system_match.group(1) 
    let process = subprocess.Popen(rest_of_line,
                                   stdout: subprocess.PIPE,
                                   stderr: subprocess.STDOUT,
                                   shell: true)
    process.wait()
    
    let command_result = process.stdout.read().decode("utf-8")
    try selfRef.send_response.throwing
        .dynamicallyCall(withArguments: selfRef.ioput_socket, "stream", [
        "name": "stdout",
        "text": "\(command_result)"
    ])
    
    line = ""
}

fileprivate func process_install_substitute(template: inout PythonObject, line_index: PythonObject) throws {
    do {
        let function = string.Template(template).substitute.throwing
        template = try function.dynamicallyCall(withArguments: ["cwd": os.getcwd()])
    } catch PythonError.exception(let error, let traceback) {
        let e = PythonError.exception(error, traceback: traceback)
        
        if error.__class__ == Python.KeyError {
            throw PackageInstallException(
                "Line \(line_index + 1): Invalid template argument \(e)")
        } else if error.__class__ == Python.ValueError {
            throw PackageInstallException(
                "Line \(line_index + 1): \(e)")
        } else {
            throw e
        }
    }
}
