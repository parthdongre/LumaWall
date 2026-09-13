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
    fullscreenDisplayIDs: [],
    isGame: false,
    ownerName: nil
  )

  var onPolicyChanged: ((PerformancePolicy) -> Void)?
  var onFullscreenDisplaysChanged: ((Set<CGDirectDisplayID>) -> Void)?

  @Published var pauseForFullscreen = true
  @Published var pauseForGames = true
  @Published private(set) var adaptiveQualityEnabled = true
  @Published private(set) var preferredFPS = 60
  @Published private(set) var preferredRenderScale = 1.0
  @Published private(set) var maximumResolutionEnabled = true
  @Published private(set) var experimentalLoadAdaptationEnabled = false
  @Published private(set) var loadPressure: AdaptiveLoadPressure = .normal

  private var timer: Timer?
  private var lastPolicy: PerformancePolicy?
  private var lastFullscreenPauseSet = Set<CGDirectDisplayID>()
  private var loadController = AdaptiveLoadController()
  private let monitor = FullscreenMonitor()

  func start() {
    monitor.onChanged = { [weak self] activity in
      guard let self else { return }
      self.foregroundActivity = activity
      self.evaluateFullscreenPauses()
      self.evaluate()
    }

    monitor.start()

    timer?.invalidate()

    let policyTimer = Timer(
      timeInterval: 2,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.evaluate()
      }
    }

    timer = policyTimer
    RunLoop.main.add(policyTimer, forMode: .common)

    evaluateFullscreenPauses()
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
  func setExperimentalLoadAdaptationEnabled(_ enabled: Bool) {
    experimentalLoadAdaptationEnabled = enabled

    if !enabled {
      loadController.reset()
      loadPressure = .normal
    }

    evaluate()
  }

  func reportRendererDiagnostics(
    _ diagnostics: [RendererDiagnostics]
  ) {
    guard experimentalLoadAdaptationEnabled else { return }

    let measured = diagnostics.compactMap { diagnostic -> (Double, Int)? in
      guard
        let actual = diagnostic.actualFPS,
        diagnostic.preferredFPS > 0
      else {
        return nil
      }

      return (actual, diagnostic.preferredFPS)
    }

    guard
      let worst = measured.min(by: {
        ($0.0 / Double($0.1))
          < ($1.0 / Double($1.1))
      })
    else {
      return
    }

    if let changed = loadController.ingest(
      actualFPS: worst.0,
      targetFPS: worst.1
    ) {
      loadPressure = changed
      evaluate()
    }
  }


  func setUserTargets(fps: Int, renderScale: Double) {
    preferredFPS = max(15, min(120, fps))
    preferredRenderScale = min(max(renderScale, 0.25), 1.0)
    evaluate()
  }

  func setMaximumResolutionEnabled(_ enabled: Bool) {
    maximumResolutionEnabled = enabled
    evaluate()
  }

  func refresh() {
    evaluateFullscreenPauses()
    evaluate()
  }

  private func evaluateFullscreenPauses() {
    let paused =
      pauseForFullscreen
      ? foregroundActivity.fullscreenDisplayIDs
      : []

    guard paused != lastFullscreenPauseSet else { return }
    lastFullscreenPauseSet = paused
    onFullscreenDisplaysChanged?(paused)
  }

  private func evaluate() {
    let process = ProcessInfo.processInfo

    // Fullscreen pausing is handled per display. Do not globally stop every
    // wallpaper just because one monitor contains a fullscreen app.
    let globalActivityPause = pauseForGames && foregroundActivity.isGame

    let policy: PerformancePolicy
    if NSScreen.screens.isEmpty || process.thermalState == .critical || globalActivityPause {
      policy = .init(targetFPS: 15, renderScale: 0.5, shouldPause: true)
    } else if adaptiveQualityEnabled
      && (process.isLowPowerModeEnabled || process.thermalState == .serious)
    {
      policy = .init(
        targetFPS: min(preferredFPS, 24),
        renderScale: maximumResolutionEnabled ? 1.0 : min(preferredRenderScale, 0.6),
        shouldPause: false
      )
    } else if adaptiveQualityEnabled && process.thermalState == .fair {
      policy = .init(
        targetFPS: min(preferredFPS, 30),
        renderScale: maximumResolutionEnabled ? 1.0 : min(preferredRenderScale, 0.75),
        shouldPause: false
      )
    } else {
      let loadFPS: Int
      let loadScale: Double

      if experimentalLoadAdaptationEnabled {
        switch loadPressure {
        case .normal:
          loadFPS = preferredFPS
          loadScale = preferredRenderScale
        case .constrained:
          loadFPS = min(preferredFPS, 60)
          loadScale = min(preferredRenderScale, 0.85)
        case .overloaded:
          loadFPS = min(preferredFPS, 30)
          loadScale = min(preferredRenderScale, 0.65)
        }
      } else {
        loadFPS = preferredFPS
        loadScale = preferredRenderScale
      }

      policy = .init(
        targetFPS: loadFPS,
        renderScale: maximumResolutionEnabled ? 1.0 : loadScale,
        shouldPause: false
      )
    }

    if policy != lastPolicy {
      lastPolicy = policy
      onPolicyChanged?(policy)
    }
  }
}
