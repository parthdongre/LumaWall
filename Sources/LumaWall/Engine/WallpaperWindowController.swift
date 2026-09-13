import AppKit
import CoreGraphics

@MainActor
final class WallpaperWindowController {
  let display: DisplayDescriptor
  let renderer: WallpaperRenderer
  let wallpaperID: UUID
  let grantedPermissions: Set<WallpaperPermission>

  private let window: NSPanel
  private var isClosed = false

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
    let window = NSPanel(
      contentRect: display.screen.frame,
      styleMask: [.borderless, .nonactivatingPanel],
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
    window.hidesOnDeactivate = false
    window.becomesKeyOnlyIfNeeded = true
    window.isFloatingPanel = false
    window.isExcludedFromWindowsMenu = true
    window.contentView = renderer.view
    window.setFrame(display.screen.frame, display: true)
    self.window = window
  }

  func show() {
    guard !isClosed else { return }
    window.orderFrontRegardless()
  }

  func updateFrame() {
    guard !isClosed else { return }
    window.setFrame(display.screen.frame, display: true)
  }

  func close() {
    guard !isClosed else { return }
    isClosed = true

    renderer.pause()
    renderer.stop()

    window.orderOut(nil)
    window.contentView = nil

    // Give Core Animation one run-loop turn after the renderer has drained before
    // releasing the window/CAMetalLayer/WebKit backing hierarchy.
    let retiredWindow = window
    DispatchQueue.main.async {
      retiredWindow.close()
    }
  }
}
