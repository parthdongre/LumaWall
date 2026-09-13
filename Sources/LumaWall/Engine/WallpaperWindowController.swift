import AppKit
import CoreGraphics

private final class WallpaperPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class WallpaperWindowController {
  private(set) var display: DisplayDescriptor
  let renderer: WallpaperRenderer
  let wallpaperID: UUID
  let grantedPermissions: Set<WallpaperPermission>

  private let window: WallpaperPanel
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

    let desktopLevel = Int(CGWindowLevelForKey(.desktopWindow))
    let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
    let wallpaperLevel = min(desktopLevel + 1, iconLevel - 1)

    let window = WallpaperPanel(
      contentRect: display.screen.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false,
      screen: display.screen
    )

    window.level = NSWindow.Level(rawValue: wallpaperLevel)
    window.collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .ignoresCycle,
      .fullScreenAuxiliary,
    ]
    window.ignoresMouseEvents = true
    window.isOpaque = true
    window.hasShadow = false
    window.backgroundColor = .black
    window.hidesOnDeactivate = false
    window.becomesKeyOnlyIfNeeded = false
    window.isFloatingPanel = false
    window.isExcludedFromWindowsMenu = true
    window.contentView = renderer.view
    window.setFrame(display.screen.frame, display: true)
    self.window = window
  }

  func show() {
    guard !isClosed else { return }

    // A wallpaper belongs above macOS's static desktop picture but below Finder
    // icons and every normal application window. Never force it to the front.
    window.orderBack(nil)
  }

  func updateDisplay(_ updatedDisplay: DisplayDescriptor) {
    guard !isClosed else { return }
    display = updatedDisplay
    renderer.configure(for: updatedDisplay)
    window.setFrame(updatedDisplay.screen.frame, display: true)
    window.orderBack(nil)
  }

  func updateFrame() {
    guard !isClosed else { return }
    renderer.configure(for: display)
    window.setFrame(display.screen.frame, display: true)
    window.orderBack(nil)
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
