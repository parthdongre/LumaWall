import AppKit
import SwiftUI

extension Color {
  init(hex: String) {
    var value = hex
    if value.hasPrefix("#") {
      value.removeFirst()
    }

    let number = UInt64(value, radix: 16) ?? 0xFFFFFF

    self.init(
      red: Double((number >> 16) & 255) / 255,
      green: Double((number >> 8) & 255) / 255,
      blue: Double(number & 255) / 255
    )
  }

  var hexString: String {
    let color = NSColor(self).usingColorSpace(.sRGB) ?? .white

    return String(
      format: "#%02X%02X%02X",
      Int(color.redComponent * 255),
      Int(color.greenComponent * 255),
      Int(color.blueComponent * 255)
    )
  }
}
