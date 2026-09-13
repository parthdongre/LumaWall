import AppKit
import Combine
import Foundation

struct PerformancePolicy: Equatable {
  var targetFPS: Int
  var renderScale: Double
  var shouldPause: Bool
}

@MainActor
final class PerformanceGovernor: ObservableObject {
  @Published private(set) var foregroundActivity = ForegroundActivity(
    isFullscreen: false,
    isGame: false,
    ownerName: nil
  )

  var onPolicyChanged: ((PerformancePolicy) -> Void)?
  @Published var pauseForFullscreen = true
  @Published var pauseForGames = true

  private var timer: Timer?
  private var lastPolicy: PerformancePolicy?
  private let monitor = FullscreenMonitor()

  func start() {
    monitor.onChanged = { [weak self] activity in
      self?.foregroundActivity = activity
      self?.evaluate()
    }
    monitor.start()
    timer?.invalidate()
    timer = .scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.evaluate()
      }
    }
    evaluate()
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    monitor.stop()
  }

  private func evaluate() {
    let process = ProcessInfo.processInfo
    let activityPause =
      (pauseForFullscreen && foregroundActivity.isFullscreen)
      || (pauseForGames && foregroundActivity.isGame)

    let policy: PerformancePolicy
    if NSScreen.screens.isEmpty || process.thermalState == .critical || activityPause {
      policy = .init(targetFPS: 15, renderScale: 0.5, shouldPause: true)
    } else if process.isLowPowerModeEnabled || process.thermalState == .serious {
      policy = .init(targetFPS: 24, renderScale: 0.6, shouldPause: false)
    } else if process.thermalState == .fair {
      policy = .init(targetFPS: 30, renderScale: 0.75, shouldPause: false)
    } else {
      policy = .init(targetFPS: 60, renderScale: 1, shouldPause: false)
    }

    if policy != lastPolicy {
      lastPolicy = policy
      onPolicyChanged?(policy)
    }
  }
}
