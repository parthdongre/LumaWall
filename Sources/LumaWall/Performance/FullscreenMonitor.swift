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
  private var workspaceObservers: [NSObjectProtocol] = []
  private var debouncer = FullscreenPauseDebouncer()

  private var last = ForegroundActivity(
    isFullscreen: false,
    fullscreenDisplayIDs: [],
    isGame: false,
    ownerName: nil
  )

  func start() {
    stop()

    let timer = Timer(
      timeInterval: 0.25,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.evaluate()
      }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)

    let workspace = NSWorkspace.shared.notificationCenter

    workspaceObservers.append(
      workspace.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.evaluate(forceResumeWhenNotFullscreen: true)
        }
      }
    )

    workspaceObservers.append(
      workspace.addObserver(
        forName: NSWorkspace.activeSpaceDidChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.evaluate(forceResumeWhenNotFullscreen: true)
        }
      }
    )

    evaluate(forceResumeWhenNotFullscreen: true)
  }

  func stop() {
    timer?.invalidate()
    timer = nil

    let workspace = NSWorkspace.shared.notificationCenter
    for observer in workspaceObservers {
      workspace.removeObserver(observer)
    }
    workspaceObservers.removeAll()

    debouncer.reset()
  }

  private func evaluate(
    forceResumeWhenNotFullscreen: Bool = false
  ) {
    let front = NSWorkspace.shared.frontmostApplication
    let pid = front?.processIdentifier ?? -1
    let owner = front?.localizedName
    let ownPID = ProcessInfo.processInfo.processIdentifier

    let fullscreenDisplays: Set<CGDirectDisplayID>

    if pid == ownPID || pid <= 0 {
      fullscreenDisplays = []
    } else {
      fullscreenDisplays = detectFullscreenDisplays(
        frontmostPID: pid,
        ownPID: ownPID
      )
    }

    let stableDisplays: Set<CGDirectDisplayID>

    if forceResumeWhenNotFullscreen && fullscreenDisplays.isEmpty {
      _ = debouncer.ingest([])
      stableDisplays = []
    } else if let committed = debouncer.ingest(fullscreenDisplays) {
      stableDisplays = committed
    } else {
      stableDisplays = debouncer.committed
    }

    let category =
      front?.bundleURL.flatMap {
        Bundle(url: $0)?.object(
          forInfoDictionaryKey: "LSApplicationCategoryType"
        ) as? String
      } ?? ""

    let activity = ForegroundActivity(
      isFullscreen: !stableDisplays.isEmpty,
      fullscreenDisplayIDs: stableDisplays,
      isGame: category.localizedCaseInsensitiveContains("games"),
      ownerName: owner
    )

    if activity != last {
      last = activity
      onChanged?(activity)
    }
  }

  private func detectFullscreenDisplays(
    frontmostPID: Int32,
    ownPID: Int32
  ) -> Set<CGDirectDisplayID> {
    guard let rawWindows = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]]
    else {
      return []
    }

    let windows = rawWindows.compactMap { window -> ForegroundWindowGeometry? in
      guard
        let pidNumber = window[kCGWindowOwnerPID as String] as? NSNumber,
        let layerNumber = window[kCGWindowLayer as String] as? NSNumber,
        let bounds = window[kCGWindowBounds as String] as? [String: Any],
        let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
      else {
        return nil
      }

      let alpha =
        (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue
        ?? 1

      return ForegroundWindowGeometry(
        ownerPID: pidNumber.int32Value,
        layer: layerNumber.intValue,
        bounds: rect,
        alpha: alpha
      )
    }

    let displays = DisplayManager.connectedDisplays().map {
      FullscreenDisplayGeometry(
        id: $0.id,
        bounds: CGDisplayBounds($0.id)
      )
    }

    return FullscreenDetection.matchingDisplayIDs(
      windows: windows,
      frontmostPID: frontmostPID,
      ownPID: ownPID,
      displays: displays
    )
  }
}
