import AppKit
import CoreGraphics

@MainActor
final class WallpaperWindowController {
  let display: DisplayDescriptor
  let renderer: WallpaperRenderer
  let wallpaperID: UUID
  let grantedPermissions: Set<WallpaperPermission>
  private let window: NSWindow

  init(
    display: DisplayDescriptor,
    wallpaperID: UUID,
    grantedPermissions: Set<WallpaperPermission>,
    renderer: WallpaperRenderer
  ) {
    self.display = display
    self.wallpaperID = wallpaperID
    self.grantedPermissions = grantedPermissions
    self.renderer = renderer

    let desktopIconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
    let window = NSWindow(
      contentRect: display.screen.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false,
      screen: display.screen
    )
    window.level = NSWindow.Level(rawValue: desktopIconLevel - 1)
    window.collectionBehavior = [
      .canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary,
    ]
    window.ignoresMouseEvents = true
    window.isOpaque = true
    window.hasShadow = false
    window.backgroundColor = .black
    window.contentView = renderer.view
    window.setFrame(display.screen.frame, display: true)
    self.window = window
  }

  func show() { window.orderFrontRegardless() }
  func updateFrame() { window.setFrame(display.screen.frame, display: true) }
  func close() {
    renderer.stop()
    window.orderOut(nil)
    window.close()
  }
}
