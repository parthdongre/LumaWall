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
  private var isClosed = false
  private var fullscreenSuppressed = false

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

    let desktopLevel =
      Int(
        CGWindowLevelForKey(
          .desktopWindow
        )
      )

    let iconLevel =
      Int(
        CGWindowLevelForKey(
          .desktopIconWindow
        )
      )

    let wallpaperLevel =
      min(
        desktopLevel + 1,
        iconLevel - 1
      )

    let window = WallpaperPanel(
      contentRect: display.screen.frame,
      styleMask: [
        .borderless,
        .nonactivatingPanel,
      ],
      backing: .buffered,
      defer: false,
      screen: display.screen
    )

    window.level =
      NSWindow.Level(
        rawValue: wallpaperLevel
      )

    window.collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .ignoresCycle,
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
    window.setFrame(
      display.screen.frame,
      display: true
    )
    window.contentView?.wantsLayer = true

    self.window = window
  }

  var windowNumber: Int {
    window.windowNumber
  }

  func show(
    alpha: CGFloat = 1
  ) {
    guard
      !isClosed,
      !fullscreenSuppressed
    else {
      return
    }

    window.alphaValue = alpha
    window.orderBack(nil)
  }

  func orderAbove(
    _ other:
      WallpaperWindowController
  ) {
    guard
      !isClosed,
      !fullscreenSuppressed
    else {
      return
    }

    window.order(
      .above,
      relativeTo: other.windowNumber
    )
  }

  func transitionIn(
    settings:
      WallpaperTransitionSettings,
    completion:
      @escaping @MainActor () -> Void
  ) {
    guard !isClosed else {
      completion()
      return
    }

    guard
      !fullscreenSuppressed,
      settings.style != .instant,
      settings.duration > 0
    else {
      window.alphaValue = 1
      completion()
      return
    }

    if settings.style == .zoom {
      window.contentView?
        .layer?
        .transform =
        CATransform3DMakeScale(
          1.035,
          1.035,
          1
        )
    }

    NSAnimationContext
      .runAnimationGroup {
        context in
        context.duration =
          settings.duration
        context.timingFunction =
          CAMediaTimingFunction(
            name:
              .easeInEaseOut
          )

        window.animator()
          .alphaValue = 1

        if settings.style
          == .zoom
        {
          window.contentView?
            .layer?
            .transform =
            CATransform3DIdentity
        }
      } completionHandler: {
        Task {
          @MainActor in
          completion()
        }
      }
  }

  func transitionOut(
    settings:
      WallpaperTransitionSettings,
    completion:
      @escaping @MainActor () -> Void
  ) {
    guard !isClosed else {
      completion()
      return
    }

    guard
      settings.style != .instant,
      settings.duration > 0
    else {
      window.alphaValue = 0
      completion()
      return
    }

    let duration =
      settings.style
        == .fadeThroughBlack
      ? settings.duration * 0.55
      : settings.duration

    NSAnimationContext
      .runAnimationGroup {
        context in
        context.duration = duration
        context.timingFunction =
          CAMediaTimingFunction(
            name:
              .easeInEaseOut
          )
        window.animator()
          .alphaValue = 0
      } completionHandler: {
        Task {
          @MainActor in
          completion()
        }
      }
  }

  func setFullscreenSuppressed(
    _ suppressed: Bool
  ) {
    guard
      !isClosed,
      fullscreenSuppressed
        != suppressed
    else {
      return
    }

    fullscreenSuppressed =
      suppressed

    if suppressed {
      window.orderOut(nil)
    } else {
      window.setFrame(
        display.screen.frame,
        display: true
      )
      window.alphaValue = 1
      window.orderBack(nil)
    }
  }

  func updateDisplay(
    _ updatedDisplay:
      DisplayDescriptor
  ) {
    guard !isClosed else {
      return
    }

    display = updatedDisplay
    renderer.configure(
      for: updatedDisplay
    )

    window.setFrame(
      updatedDisplay.screen.frame,
      display: true
    )

    if !fullscreenSuppressed {
      window.orderBack(nil)
    }
  }

  func updateFrame() {
    guard !isClosed else {
      return
    }

    renderer.configure(
      for: display
    )

    window.setFrame(
      display.screen.frame,
      display: true
    )

    if !fullscreenSuppressed {
      window.orderBack(nil)
    }
  }

  func close() {
    guard !isClosed else {
      return
    }

    isClosed = true
    renderer.pause()
    renderer.stop()

    window.orderOut(nil)
    window.contentView = nil

    let retiredWindow =
      window

    DispatchQueue.main.async {
      retiredWindow.close()
    }
  }
}
