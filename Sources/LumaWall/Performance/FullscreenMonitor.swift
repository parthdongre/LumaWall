import AppKit
import CoreGraphics

struct ForegroundActivity: Equatable {
  var isFullscreen: Bool
  var isGame: Bool
  var ownerName: String?
}

@MainActor
final class FullscreenMonitor {
  var onChanged: ((ForegroundActivity) -> Void)?
  private var timer: Timer?
  private var last = ForegroundActivity(isFullscreen: false, isGame: false, ownerName: nil)

  func start() {
    timer?.invalidate()
    timer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.evaluate()
    }
    evaluate()
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  private func evaluate() {
    let front = NSWorkspace.shared.frontmostApplication
    let pid = front?.processIdentifier ?? -1
    let owner = front?.localizedName
    var fullscreen = false

    if let info = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]] {
      for window in info {
        guard
          (window[kCGWindowOwnerPID as String] as? Int32) == pid,
          (window[kCGWindowLayer as String] as? Int) == 0,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
        else { continue }

        if NSScreen.screens.contains(where: {
          abs(rect.width - $0.frame.width) < 3 && abs(rect.height - $0.frame.height) < 3
        }) {
          fullscreen = true
          break
        }
      }
    }

    let category =
      front?.bundleURL.flatMap {
        Bundle(url: $0)?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
      } ?? ""
    let activity = ForegroundActivity(
      isFullscreen: fullscreen,
      isGame: category.localizedCaseInsensitiveContains("games"),
      ownerName: owner
    )
    if activity != last {
      last = activity
      onChanged?(activity)
    }
  }
}
