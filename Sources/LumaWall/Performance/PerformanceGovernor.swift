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
  @Published private(set) var adaptiveQualityEnabled = true
  @Published private(set) var preferredFPS = 60
  @Published private(set) var preferredRenderScale = 1.0

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

  func setAdaptiveQualityEnabled(_ enabled: Bool) {
    adaptiveQualityEnabled = enabled
    evaluate()
  }

  func setUserTargets(fps: Int, renderScale: Double) {
    preferredFPS = max(15, min(120, fps))
    preferredRenderScale = min(max(renderScale, 0.25), 1.0)
    evaluate()
  }

  func refresh() {
    evaluate()
  }

  private func evaluate() {
    let process = ProcessInfo.processInfo
    let activityPause =
      (pauseForFullscreen && foregroundActivity.isFullscreen)
      || (pauseForGames && foregroundActivity.isGame)

    let policy: PerformancePolicy
    if NSScreen.screens.isEmpty || process.thermalState == .critical || activityPause {
      policy = .init(targetFPS: 15, renderScale: 0.5, shouldPause: true)
    } else if adaptiveQualityEnabled
      && (process.isLowPowerModeEnabled || process.thermalState == .serious)
    {
      policy = .init(
        targetFPS: min(preferredFPS, 24),
        renderScale: min(preferredRenderScale, 0.6),
        shouldPause: false
      )
    } else if adaptiveQualityEnabled && process.thermalState == .fair {
      policy = .init(
        targetFPS: min(preferredFPS, 30),
        renderScale: min(preferredRenderScale, 0.75),
        shouldPause: false
      )
    } else {
      policy = .init(
        targetFPS: preferredFPS,
        renderScale: preferredRenderScale,
        shouldPause: false
      )
    }

    if policy != lastPolicy {
      lastPolicy = policy
      onPolicyChanged?(policy)
    }
  }
}
