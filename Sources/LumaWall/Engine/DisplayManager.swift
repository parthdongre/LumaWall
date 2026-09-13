import AppKit
import CoreGraphics

struct DisplayDescriptor: Identifiable, Hashable {
  let id: CGDirectDisplayID
  let screen: NSScreen
  let name: String

  static func == (lhs: DisplayDescriptor, rhs: DisplayDescriptor) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DisplayManager {
  static func connectedDisplays() -> [DisplayDescriptor] {
    NSScreen.screens.compactMap { screen in
      guard
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
      else {
        return nil
      }
      let id = CGDirectDisplayID(number.uint32Value)
      return DisplayDescriptor(id: id, screen: screen, name: screen.localizedName)
    }
  }
}
