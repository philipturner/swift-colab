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

// These symbols disappear from the Swift interpreter after the file finishes
// executing.
import func Glibc.dlopen
import func Glibc.dlsym

/// A struct with functions that the kernel and the code running inside the
/// kernel use to talk to each other.
///
/// Note that it would be more Jupyter-y for the communication to happen over
/// ZeroMQ. This is not currently possible, because ZeroMQ sends messages
/// asynchronously using IO threads, and LLDB pauses those IO threads, which
/// prevents them from sending the messages.
struct KernelCommunicator {
  let jupyterSession: JupyterSession
  
  private var previousDisplayMessages: [JupyterDisplayMessage]?
  
  private let libJupyterKernel = dlopen(
    "/opt/swift/lib/libJupyterKernel.so", /*RTLD_LAZY*/Int32(1))!
  
  init(jupyterSession: JupyterSession) {
    self.jupyterSession = jupyterSession
    
    // See "Sources/JupyterKernel/SwiftShell.swift" for an explanation of this 
    // workaround.
    callSymbol("prevent_numpy_import_hang")
    
    // Fetch pipes before executing any other Swift code for safe measure. This
    // may not be needed.
    callSymbol("fetch_pipes")
    
    // Overwrite implementation of `google.colab._message.blocking_request`.
    callSymbol("redirect_stdin")
  }
  
  private func callSymbol(_ name: String) {
    let address = dlsym(libJupyterKernel, name)!
    let symbol = unsafeBitCast(address, to: (@convention(c) () -> Void).self)
    symbol()
  }
  
  func fetchPipes() {
    callSymbol("fetch_pipes")
  }

  /// The kernel calls this when the parent message changes.
  mutating func updateParentMessage(to parentMessage: ParentMessage) {
    let address = dlsym(libJupyterKernel, "update_parent_message")!
    let symbol = unsafeBitCast(address, to: (@convention(c) (
      UnsafePointer<CChar>) -> Void
    ).self)
    symbol(parentMessage.json)
  }

  /// A single serialized display message for the Jupyter client.
  /// Corresponds to a ZeroMQ "multipart message".
  struct JupyterDisplayMessage {
    let parts: [BytesReference]
  }

  /// A reference to memory containing bytes.
  ///
  /// As long as there is a strong reference to an instance, that instance's
  /// `unsafeBufferPointer` refers to memory containing the bytes passed to
  /// that instance's constructor.
  ///
  /// We use this so that we can give the kernel a memory location that it can
  /// read bytes from.
  class BytesReference {
    private var bytes: ContiguousArray<CChar>

    init(_ bytes: UnsafeBufferPointer<CChar>) {
      // Construct our own array and copy `bytes` into it, so that no one
      // else aliases the underlying memory.
      self.bytes = []
      self.bytes.append(contentsOf: bytes)
    }
    
    var unsafeBufferPointer: UnsafeBufferPointer<CChar> {
      // We have tried very hard to make the pointer stay valid outside the
      // closure:
      // - No one else aliases the underlying memory.
      // - The comment on this class reminds users that the memory may become
      //   invalid after all references to the BytesReference instance are
      //   released.
      return bytes.withUnsafeBufferPointer { $0 }
    }
  }
  
  /// ParentMessage identifies the request that causes things to happen.
  /// This lets Jupyter, for example, know which cell to display graphics
  /// messages in.
  struct ParentMessage {
    let json: String
  }
  
  /// The data necessary to identify and sign outgoing jupyter messages.
  struct JupyterSession {
    let id: String
    let key: String
    let username: String
  }
}
