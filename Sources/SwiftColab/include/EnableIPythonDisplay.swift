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

/// Hooks IPython to the KernelCommunicator, so that it can send display
/// messages to Jupyter.

#if canImport(PythonKit)
import PythonKit

enum IPythonDisplay {
  static var socket: PythonObject = Python.None
  static var shell: PythonObject = Python.None

  // Tracks whether the Python version that we are interoperating with has a
  // "real" bytes type that is an array of bytes, rather than Python2's "fake"
  // bytes type that is just an alias of str.
  private static var hasRealBytesType: Bool = false
}

extension IPythonDisplay {
  private static func bytes(_ py: PythonObject) -> KernelCommunicator.BytesReference {
    // TODO: Replace with a faster implementation that reads bytes directly
    // from the python object's memory.
    if hasRealBytesType {
      let bytes = py.lazy.map { CChar(bitPattern: UInt8($0)!) }
      return KernelCommunicator.BytesReference(bytes)
    }
    let bytes = py.lazy.map { CChar(bitPattern: UInt8(Python.ord($0))!) }
    return KernelCommunicator.BytesReference(bytes)
  }

  private static func updateParentMessage(to parentMessage: KernelCommunicator.ParentMessage) {
    let json = Python.import("json")
    IPythonDisplay.shell.set_parent(json.loads(parentMessage.json))
  }

  private static func consumeDisplayMessages() -> [KernelCommunicator.JupyterDisplayMessage] {
    let displayMessages = IPythonDisplay.socket.messages.map {
      KernelCommunicator.JupyterDisplayMessage(parts: $0.map { bytes($0) })
    }
    IPythonDisplay.socket.messages = []
    return displayMessages
  }

  static func enable() {
    if IPythonDisplay.shell != Python.None {
      print("Warning: IPython display already enabled.")
      return
    }

    hasRealBytesType = Bool(Python.isinstance(PythonObject("t").encode("utf8")[0], Python.int))!
    
    let socketAndShell = Python.import("Swift").create_shell(
      username: JupyterKernel.communicator.jupyterSession.username,
      session_id: JupyterKernel.communicator.jupyterSession.id,
      key: PythonObject(JupyterKernel.communicator.jupyterSession.key).encode("utf8"))
    IPythonDisplay.socket = socketAndShell[0]
    IPythonDisplay.shell = socketAndShell[1]

    JupyterKernel.communicator.handleParentMessage(updateParentMessage)
    JupyterKernel.communicator.afterSuccessfulExecution(run: consumeDisplayMessages)
  }
}

func display(base64EncodedPNG: String) {
  let display = Python.import("IPython.display")
  let codecs = Python.import("codecs")
  let Image = display.Image
  
  let imageData = codecs.decode(Python.bytes(base64EncodedPNG, encoding: "utf8"), encoding: "base64")
  display.display(Image(data: imageData, format: "png"))
}

#if canImport(SwiftPlot) && canImport(AGGRenderer)
import SwiftPlot
import AGGRenderer

extension Plot {
  func display(size: Size = Size(width: 1000, height: 660)) {
    let renderer = AGGRenderer()
    drawGraph(size: size, renderer: renderer)
    
    func display_bypassSymbolDuplication(base64EncodedPNG: String) {
      let display = Python.import("IPython.display")
      let codecs = Python.import("codecs")
      let Image = display.Image

      let imageData = codecs.decode(Python.bytes(base64EncodedPNG, encoding: "utf8"), encoding: "base64")
      display.display(Image(data: imageData, format: "png"))
    }
    
    display_bypassSymbolDuplication(base64EncodedPNG: renderer.base64Png())
  }
}
#endif

IPythonDisplay.enable()
#endif
