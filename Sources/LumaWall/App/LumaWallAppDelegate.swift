import AppKit

extension Notification.Name {
  static let lumaWallOpenFiles = Notification.Name("LumaWallOpenFiles")
}

@MainActor
final class LumaWallAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    Self.bringControlWindowForward()
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    Self.bringControlWindowForward()
    return true
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    NotificationCenter.default.post(name: .lumaWallOpenFiles, object: urls)
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.async {
      Self.bringControlWindowForward()
    }
  }

  static func bringControlWindowForward() {
    let windows = NSApp.windows.filter {
      $0.level == .normal && $0.styleMask.contains(.titled)
    }
    guard let window =
      windows.first(where: { $0.title == "LumaWall" })
        ?? windows.first(where: { $0.isVisible })
        ?? windows.first
    else { return }

    if window.isMiniaturized {
      window.deminiaturize(nil)
    }
    window.makeKeyAndOrderFront(nil)
  }
}
