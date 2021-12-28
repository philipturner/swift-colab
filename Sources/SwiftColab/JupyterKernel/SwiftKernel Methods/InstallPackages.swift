import Foundation
import PythonKit

func install_packages(_ selfRef: PythonObject,
                      packages: [PythonObject],
                      swiftpm_flags: [PythonObject],
                      extra_include_commands: [PythonObject],
                      user_install_location: PythonObject?) throws {
    if packages.count == 0 && swiftpm_flags.count == 0 {
        return
    }
    
    if selfRef.checking.debugger != nil
}
