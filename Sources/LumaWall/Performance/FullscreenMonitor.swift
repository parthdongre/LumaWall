import AppKit
import CoreGraphics

struct ForegroundActivity: Equatable {
  var isFullscreen: Bool
  var fullscreenDisplayIDs: Set<CGDirectDisplayID>
  var isGame: Bool
  var ownerName: String?
}

@MainActor
final class FullscreenMonitor {
  var onChanged: ((ForegroundActivity) -> Void)?

  private var timer: Timer?
  private var last = ForegroundActivity(
    isFullscreen: false,
    fullscreenDisplayIDs: [],
    isGame: false,
    ownerName: nil
  )

  func start() {
    timer?.invalidate()
    timer = .scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.evaluate()
      }
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
    var fullscreenDisplays = Set<CGDirectDisplayID>()

    if let windows = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]] {
      let displays = DisplayManager.connectedDisplays()

      for window in windows {
        guard
          (window[kCGWindowOwnerPID as String] as? Int32) == pid,
          (window[kCGWindowLayer as String] as? Int) == 0,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
          rect.width > 0,
          rect.height > 0
        else {
          continue
        }

        for display in displays {
          let displayBounds = CGDisplayBounds(display.id)
          let intersection = rect.intersection(displayBounds)

          guard !intersection.isNull, !intersection.isEmpty else { continue }

          let displayArea = max(displayBounds.width * displayBounds.height, 1)
          let coveredArea = intersection.width * intersection.height
          let coverage = coveredArea / displayArea

          let dimensionsMatch =
            abs(rect.width - displayBounds.width) <= 4
            && abs(rect.height - displayBounds.height) <= 4

          if coverage >= 0.97 || dimensionsMatch {
            fullscreenDisplays.insert(display.id)
          }
        }
      }
    }

    let category =
      front?.bundleURL.flatMap {
        Bundle(url: $0)?.object(
          forInfoDictionaryKey: "LSApplicationCategoryType"
        ) as? String
      } ?? ""

    let activity = ForegroundActivity(
      isFullscreen: !fullscreenDisplays.isEmpty,
      fullscreenDisplayIDs: fullscreenDisplays,
      isGame: category.localizedCaseInsensitiveContains("games"),
      ownerName: owner
    )

    if activity != last {
      last = activity
      onChanged?(activity)
    }
  }
}
