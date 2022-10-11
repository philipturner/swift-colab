// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if canImport(PythonKit)
import PythonKit

// These symbols disappear from the Swift interpreter after the file finishes
// executing.
import func Glibc.dlopen
import func Glibc.dlsym

/// Hooks IPython to the KernelCommunicator, so that it can send display
/// messages to Jupyter.
enum IPythonDisplay {
  static var socket: PythonObject = Python.None
  static var shell: PythonObject = Python.None
}

extension IPythonDisplay {
  private static func bytes(_ py: PythonObject) -> KernelCommunicator.BytesReference {
    guard let bytes = PythonBytes(py) else {
      fatalError("Could not convert object \(py) to `PythonBytes`.")
    }
    let address = bytes.withUnsafeBytes { $0 }.bindMemory(to: CChar.self)
    return KernelCommunicator.BytesReference(address)
  }
  
  private static func updateParentMessage(to parentMessage: KernelCommunicator.ParentMessage) {
    let json = Python.import("json")
    IPythonDisplay.shell.set_parent(json.loads(parentMessage.json))
  }
  
  private static func consumeDisplayMessages() -> [KernelCommunicator.JupyterDisplayMessage] {
    let displayMessages = IPythonDisplay.socket.messages.map {
      KernelCommunicator.JupyterDisplayMessage(parts: $0.map(bytes))
    }
    IPythonDisplay.socket.messages = []
    return displayMessages
  }
  
  static func enable() {
    if IPythonDisplay.shell != Python.None {
      print("Warning: IPython display already enabled.")
      return
    }
    
    let /*Glibc.*/RTLD_LAZY = Int32(1)
    let libAddress = dlopen("/opt/swift/lib/libJupyterKernel.so", RTLD_LAZY)
    let funcAddress = dlsym(libAddress, "create_shell")
    let create_shell = unsafeBitCast(funcAddress, to: (@convention(c) (
      UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int64
    ).self)
    
    let session = JupyterKernel.communicator.jupyterSession
    let socketAndShellID = create_shell(
      session.username, session.id, session.key
    )
    
    let _ctypes = Python.import("_ctypes")
    let socketAndShell = _ctypes.PyObj_FromPtr(socketAndShellID)
    IPythonDisplay.socket = socketAndShell[0]
    IPythonDisplay.shell = socketAndShell[1]
  }
}

// This workaround stops the debugger from duplicating the symbol `display`
// while processing the code inside `Plot.display(size:)`
extension IPythonDisplay {
  static func display(base64EncodedPNG: String) {
    let display = Python.import("IPython.display")
    let codecs = Python.import("codecs")
    let Image = display.Image
    
    let imageData = codecs.decode(
      Python.bytes(base64EncodedPNG, encoding: "utf8"), encoding: "base64")
    display.display(Image(data: imageData, format: "png"))
  }
}

// Global function for displaying base64 images in the notebook.
func display(base64EncodedPNG: String) {
  IPythonDisplay.display(base64EncodedPNG: base64EncodedPNG)
}

#if canImport(SwiftPlot) && canImport(AGGRenderer)
import SwiftPlot
import AGGRenderer

// Extend `Plot` to create an instance member that utilizes `Plot.drawGraph`.
extension Plot {
  func display(size: Size = Size(width: 1000, height: 660)) {
    let renderer = AGGRenderer()
    self.drawGraph(size: size, renderer: renderer)
    
    IPythonDisplay.display(base64EncodedPNG: renderer.base64Png())
  }
}
#endif

IPythonDisplay.enable()
#endif
