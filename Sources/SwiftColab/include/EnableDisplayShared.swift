import PythonKit

#if canImport(SwiftPlot)
import SwiftPlot
import AGGRenderer
var __agg_renderer = AGGRenderer()
extension Plot {
  func display(size: Size = Size(width: 1000, height: 660)) {
    drawGraph(size: size, renderer: __agg_renderer)
    let image_b64 = __agg_renderer.base64Png()
    
    let displayImage = Python.import("IPython.display")
    let codecs = Python.import("codecs")
    let imageData = codecs.decode(Python.bytes(image_b64, encoding: "utf8"),
                                  encoding: "base64")
    displayImage.Image(data: imageData, format: "png").display()
  }
}
#endif
