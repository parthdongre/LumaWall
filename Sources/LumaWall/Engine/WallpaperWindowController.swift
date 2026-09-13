import AppKit
import CoreGraphics
import QuartzCore

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
  private let rootView = NSView()
  private let timeDateOverlay = TimeDateOverlayView()

  private var isClosed = false
  private(set) var fullscreenSuppressed = false

  static var wallpaperWindowLevel: NSWindow.Level {
    let desktopLevel = Int(CGWindowLevelForKey(.desktopWindow))
    let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))

    // The safest desktop surface is immediately below Finder's icon level.
    // Window levels are absolute: ordering this window to the front at this
    // level can never put it above normal application windows or Finder icons.
    let raw =
      iconLevel > desktopLevel
      ? iconLevel - 1
      : desktopLevel + 1

    return NSWindow.Level(rawValue: raw)
  }

  static let wallpaperCollectionBehavior: NSWindow.CollectionBehavior = [
    .canJoinAllSpaces,
    .stationary,
    .ignoresCycle,
  ]

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

    let window = WallpaperPanel(
      contentRect: display.screen.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false,
      screen: display.screen
    )

    window.level = Self.wallpaperWindowLevel
    window.collectionBehavior = Self.wallpaperCollectionBehavior
    window.ignoresMouseEvents = true
    window.isOpaque = true
    window.hasShadow = false
    window.backgroundColor = .black
    window.hidesOnDeactivate = false
    window.becomesKeyOnlyIfNeeded = false
    window.isFloatingPanel = false
    window.isExcludedFromWindowsMenu = true

    rootView.wantsLayer = true
    rootView.layer?.backgroundColor = NSColor.black.cgColor

    renderer.view.translatesAutoresizingMaskIntoConstraints = false
    timeDateOverlay.translatesAutoresizingMaskIntoConstraints = false

    rootView.addSubview(renderer.view)
    rootView.addSubview(timeDateOverlay)

    NSLayoutConstraint.activate([
      renderer.view.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      renderer.view.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      renderer.view.topAnchor.constraint(equalTo: rootView.topAnchor),
      renderer.view.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

      timeDateOverlay.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      timeDateOverlay.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      timeDateOverlay.topAnchor.constraint(equalTo: rootView.topAnchor),
      timeDateOverlay.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
    ])

    window.contentView = rootView
    window.setFrame(display.screen.frame, display: true)

    self.window = window
  }

  var windowNumber: Int { window.windowNumber }

  func setTimeDateOverlay(_ settings: TimeDateOverlaySettings) {
    timeDateOverlay.apply(settings)
  }

  func show(alpha: CGFloat = 1) {
    guard !isClosed else { return }

    window.alphaValue = alpha

    // Keep the wallpaper at a deterministic desktop level. We deliberately do
    // not use orderBack: Finder may then place its static desktop surface above
    // us after app/Space changes, producing an apparent wallpaper off/on flash.
    window.orderFrontRegardless()
  }

  func orderAbove(_ other: WallpaperWindowController) {
    guard !isClosed else { return }
    window.order(.above, relativeTo: other.windowNumber)
  }

  func transitionIn(
    settings: WallpaperTransitionSettings,
    completion: @escaping @MainActor () -> Void
  ) {
    guard !isClosed else {
      completion()
      return
    }

    guard settings.style != .instant, settings.duration > 0 else {
      window.alphaValue = 1
      completion()
      return
    }

    if settings.style == .zoom {
      rootView.layer?.transform = CATransform3DMakeScale(1.035, 1.035, 1)
    }

    NSAnimationContext.runAnimationGroup { context in
      context.duration = settings.duration
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

      window.animator().alphaValue = 1

      if settings.style == .zoom {
        rootView.layer?.transform = CATransform3DIdentity
      }
    } completionHandler: {
      Task { @MainActor in
        completion()
      }
    }
  }

  func transitionOut(
    settings: WallpaperTransitionSettings,
    completion: @escaping @MainActor () -> Void
  ) {
    guard !isClosed else {
      completion()
      return
    }

    guard settings.style != .instant, settings.duration > 0 else {
      window.alphaValue = 0
      completion()
      return
    }

    let duration =
      settings.style == .fadeThroughBlack
      ? settings.duration * 0.55
      : settings.duration

    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      window.animator().alphaValue = 0
    } completionHandler: {
      Task { @MainActor in
        completion()
      }
    }
  }

  func setFullscreenSuppressed(_ suppressed: Bool) {
    guard !isClosed else { return }

    // Fullscreen suppression is a renderer-performance state, not a window
    // visibility state. The panel already lives below app windows and is not
    // allowed into fullscreen Spaces. Ordering it out/in caused the desktop to
    // flash back to the static macOS wallpaper during false positives and app
    // switches.
    fullscreenSuppressed = suppressed
  }

  func updateDisplay(_ updatedDisplay: DisplayDescriptor) {
    guard !isClosed else { return }

    display = updatedDisplay
    renderer.configure(for: updatedDisplay)
    window.setFrame(updatedDisplay.screen.frame, display: true)
    window.orderFrontRegardless()
  }

  func updateFrame() {
    guard !isClosed else { return }

    renderer.configure(for: display)
    window.setFrame(display.screen.frame, display: true)
    window.orderFrontRegardless()
  }

  func close() {
    guard !isClosed else { return }
    isClosed = true

    timeDateOverlay.stop()
    renderer.pause()
    renderer.stop()

    window.orderOut(nil)
    window.contentView = nil

    let retiredWindow = window
    DispatchQueue.main.async {
      retiredWindow.close()
    }
  }
}
