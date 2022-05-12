import Foundation
fileprivate let ipykernel_launcher = Python.import("ipykernel_launcher")
fileprivate let KernelSpecManager = Python.import("jupyter_client").kernelspec.KernelSpecManager

@_cdecl("JupyterKernel_registerSwiftKernel")
public func JupyterKernel_registerSwiftKernel() {
  print("Registering Swift Jupyter kernel")
  
  let fm = FileManager.default
  let jupyterKernelFolder = "/opt/swift/internal-modules/JupyterKernel"
  
  // About sys.path[0]:
  // Remove the CWD from sys.path while we load stuff.
  // This is added back by InteractiveShellApp.init_path()
  let pythonScript = """
  import sys; from ctypes import PyDLL
  if __name__ == "__main__":
      if sys.path[0] == '':
          del sys.path[0]
      
      PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_createSwiftKernel()
  """
  
  let swiftKernelPath = "\(jupyterKernelFolder)/swift_kernel.py"
  try? fm.removeItem(atPath: swiftKernelPath)
  fm.createFile(atPath: swiftKernelPath, contents: pythonScript.data(using: .utf8)!)
  
  // Create kernel spec
  // Python.import("sys").executable != Bundle.main.executablePath! ???
  let kernelSpec = """
  {
    "argv": [
      "\(Python.import("sys").executable)",
      "\(swiftKernelPath)",
      "-f",
      "{connection_file}"
    ],
    "display_name": "Swift",
    "language": "swift",
    "env": {}
  }
  """
  
  let kernelSpecPath = "\(jupyterKernelFolder)/kernel.json"
  try? fm.removeItem(atPath: kernelSpecPath)
  
  fm.createFile(atPath: kernelSpecPath, contents: kernelSpec.data(using: .utf8)!)
  KernelSpecManager().install_kernel_spec(jupyterKernelFolder, "swift")
  
  // Overwrite Python kernel script
  
  let activeKernelPath = String(ipykernel_launcher.__file__)!
  
  if !fm.contentsEqual(atPath: swiftKernelPath, andPath: activeKernelPath) {
      try! fm.copyItem(atPath: swiftKernelPath, toPath: activeKernelPath)
  } else {
      print("Swift Jupyter kernel was already registered")
  }
}
