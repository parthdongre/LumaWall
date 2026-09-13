import AppKit
import CoreGraphics

@MainActor
final class WallpaperEngine {
  private var controllers: [CGDirectDisplayID: WallpaperWindowController] = [:]
  private var interactionTimer: Timer?
  private var latestAudio = AudioFrame.zero
  private var userPaused = false
  private var policyPaused = false
  private var effectiveFPS = 60
  private var effectiveScale = 1.0

  var assignmentSnapshot: [CGDirectDisplayID: UUID] {
    controllers.mapValues(\.wallpaperID)
  }

  func apply(
    wallpaper: Wallpaper, to displays: [DisplayDescriptor],
    properties: [String: WallpaperPropertyValue] = [:]
  ) throws {
    for display in displays {
      controllers[display.id]?.close()

      let renderer = RendererFactory.makeRenderer(for: wallpaper.type)
      renderer.configure(for: display)
      try renderer.load(wallpaper)
      renderer.setProperties(properties)
      renderer.updateAudio(
        wallpaper.grantedPermissions.contains(.systemAudio) ? latestAudio : .zero)
      renderer.setFPS(effectiveFPS)
      renderer.setRenderScale(effectiveScale)

      let controller = WallpaperWindowController(
        display: display,
        wallpaperID: wallpaper.id,
        grantedPermissions: wallpaper.grantedPermissions,
        renderer: renderer
      )
      controller.show()
      controllers[display.id] = controller
    }
    startInteractionUpdatesIfNeeded()
    updatePlaybackState()
  }

  func refreshDisplays(_ displays: [DisplayDescriptor]) {
    for display in displays {
      controllers[display.id]?.updateDisplay(display)
    }
  }

  func removeWallpaper(from displayID: CGDirectDisplayID) {
    controllers.removeValue(forKey: displayID)?.close()
    stopInteractionTimerIfIdle()
  }

  func stopAll() {
    interactionTimer?.invalidate()
    interactionTimer = nil
    controllers.values.forEach { $0.close() }
    controllers.removeAll()
  }

  func setUserPaused(_ paused: Bool) {
    userPaused = paused
    updatePlaybackState()
  }

  func setFPS(_ fps: Int) {
    effectiveFPS = max(1, fps)
    controllers.values.forEach { $0.renderer.setFPS(effectiveFPS) }
  }

  func setRenderScale(_ scale: Double) {
    effectiveScale = min(max(scale, 0.25), 1.0)
    controllers.values.forEach { $0.renderer.setRenderScale(effectiveScale) }
  }

  func apply(policy: PerformancePolicy) {
    policyPaused = policy.shouldPause
    setFPS(policy.targetFPS)
    setRenderScale(policy.renderScale)
    updatePlaybackState()
  }

  func setProperties(_ properties: [String: WallpaperPropertyValue], for wallpaperID: UUID) {
    controllers.values
      .filter { $0.wallpaperID == wallpaperID }
      .forEach { $0.renderer.setProperties(properties) }
  }

  func updateAudio(_ frame: AudioFrame) {
    latestAudio = frame
    for controller in controllers.values {
      controller.renderer.updateAudio(
        controller.grantedPermissions.contains(.systemAudio) ? frame : .zero
      )
    }
  }

  private func updatePlaybackState() {
    if userPaused || policyPaused {
      controllers.values.forEach { $0.renderer.pause() }
    } else {
      controllers.values.forEach { $0.renderer.play() }
    }
  }

  private func startInteractionUpdatesIfNeeded() {
    guard interactionTimer == nil else { return }
    interactionTimer = .scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
      [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        for controller in self.controllers.values {
          if controller.grantedPermissions.contains(.mouse) {
            let state = InteractionState.forScreen(controller.display.screen)
            controller.renderer.updateInteraction(state)
          } else {
            controller.renderer.updateInteraction(
              InteractionState(normalizedMouse: CGPoint(x: 0.5, y: 0.5)))
          }
        }
      }
    }
  }

  private func stopInteractionTimerIfIdle() {
    guard controllers.isEmpty else { return }
    interactionTimer?.invalidate()
    interactionTimer = nil
  }
}
