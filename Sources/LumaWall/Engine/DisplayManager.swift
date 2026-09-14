import AppKit
import ColorSync
import CoreGraphics

struct DisplayDescriptor: Identifiable, Hashable {
  let id: CGDirectDisplayID
  let persistentID: String
  let screen: NSScreen
  let name: String
  let nativePixelSize: CGSize
  let logicalPointSize: CGSize
  let backingScaleFactor: CGFloat
  let maximumFPS: Int
  let refreshRate: Double
  let isBuiltIn: Bool
  let maximumEDR: CGFloat

  init(
    id: CGDirectDisplayID,
    persistentID: String = "",
    screen: NSScreen,
    name: String,
    nativePixelSize: CGSize,
    logicalPointSize: CGSize,
    backingScaleFactor: CGFloat,
    maximumFPS: Int,
    refreshRate: Double,
    isBuiltIn: Bool,
    maximumEDR: CGFloat
  ) {
    self.id = id
    self.persistentID = persistentID
    self.screen = screen
    self.name = name
    self.nativePixelSize = nativePixelSize
    self.logicalPointSize = logicalPointSize
    self.backingScaleFactor = backingScaleFactor
    self.maximumFPS = maximumFPS
    self.refreshRate = refreshRate
    self.isBuiltIn = isBuiltIn
    self.maximumEDR = maximumEDR
  }

  static func == (
    lhs: DisplayDescriptor,
    rhs: DisplayDescriptor
  ) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  var supportsEDR: Bool {
    maximumEDR > 1.0
  }

  var nativeResolutionLabel: String {
    "\(Int(nativePixelSize.width)) × \(Int(nativePixelSize.height))"
  }

  var logicalResolutionLabel: String {
    "\(Int(logicalPointSize.width)) × \(Int(logicalPointSize.height)) pt"
  }

  var refreshLabel: String {
    if refreshRate > 1 {
      return String(
        format: "%.0f Hz",
        refreshRate
      )
    }
    return "\(maximumFPS) FPS max"
  }

  var edrLabel: String {
    supportsEDR
      ? String(
        format: "EDR %.1f×",
        maximumEDR
      )
      : "SDR"
  }
}

enum DisplayManager {
  @MainActor
  static func connectedDisplays() -> [DisplayDescriptor] {
    NSScreen.screens.compactMap { screen in
      guard
        let number =
          screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
          ] as? NSNumber
      else {
        return nil
      }

      let id =
        CGDirectDisplayID(number.uint32Value)

      let persistentID: String
      if let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(id) {
        let uuid = unmanagedUUID.takeRetainedValue()
        persistentID = CFUUIDCreateString(nil, uuid) as String
      } else {
        persistentID = "cg-display-\(id)"
      }

      let mode =
        CGDisplayCopyDisplayMode(id)

      let fallbackPixels = CGSize(
        width:
          screen.frame.width
          * screen.backingScaleFactor,
        height:
          screen.frame.height
          * screen.backingScaleFactor
      )

      let nativePixels = CGSize(
        width:
          mode.map {
            CGFloat($0.pixelWidth)
          }
          ?? fallbackPixels.width,
        height:
          mode.map {
            CGFloat($0.pixelHeight)
          }
          ?? fallbackPixels.height
      )

      return DisplayDescriptor(
        id: id,
        persistentID: persistentID,
        screen: screen,
        name: screen.localizedName,
        nativePixelSize: nativePixels,
        logicalPointSize: screen.frame.size,
        backingScaleFactor:
          screen.backingScaleFactor,
        maximumFPS:
          max(
            1,
            screen.maximumFramesPerSecond
          ),
        refreshRate:
          mode?.refreshRate ?? 0,
        isBuiltIn:
          CGDisplayIsBuiltin(id) != 0,
        maximumEDR:
          screen
            .maximumExtendedDynamicRangeColorComponentValue
      )
    }
  }
}
