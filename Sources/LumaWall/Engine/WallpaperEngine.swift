import AppKit
import CoreGraphics

@MainActor
final class WallpaperEngine {
  private var controllers: [CGDirectDisplayID: WallpaperWindowController] = [:]
  private var interactionTimer: Timer?
  private var latestAudio = AudioFrame.zero
  private var userPaused = false
  private var policyPaused = false
  private var fullscreenPausedDisplays = Set<CGDirectDisplayID>()
  private var effectiveFPS = 60
  private var effectiveScale = 1.0

  var assignmentSnapshot: [CGDirectDisplayID: UUID] {
    controllers.mapValues(\.wallpaperID)
  }

  var fullscreenPausedDisplayIDs: Set<CGDirectDisplayID> {
    fullscreenPausedDisplays
  }

  func apply(
    wallpaper: Wallpaper,
    to displays: [DisplayDescriptor],
    properties: [String: WallpaperPropertyValue] = [:]
  ) throws {
    for display in displays {
      controllers[display.id]?.close()

      let renderer = RendererFactory.makeRenderer(for: wallpaper.type)
      renderer.configure(for: display)
      try renderer.load(wallpaper)
      renderer.setProperties(properties)
      renderer.updateAudio(
        wallpaper.grantedPermissions.contains(.systemAudio) ? latestAudio : .zero
      )
      renderer.setFPS(effectiveFPS)
      renderer.setRenderScale(effectiveScale)

      let controller = WallpaperWindowController(
        display: display,
        wallpaperID: wallpaper.id,
        grantedPermissions: wallpaper.grantedPermissions,
        renderer: renderer
      )

      controllers[display.id] = controller
      controller.setFullscreenSuppressed(
        fullscreenPausedDisplays.contains(display.id)
      )
      controller.show()
    }

    startInteractionUpdatesIfNeeded()
    updatePlaybackState()
  }

  func refreshDisplays(_ displays: [DisplayDescriptor]) {
    let connectedIDs = Set(displays.map(\.id))

    for display in displays {
      controllers[display.id]?.updateDisplay(display)
    }

    for id in controllers.keys where !connectedIDs.contains(id) {
      controllers.removeValue(forKey: id)?.close()
    }

    fullscreenPausedDisplays.formIntersection(connectedIDs)
    updatePlaybackState()
    stopInteractionTimerIfIdle()
  }

  func removeWallpaper(from displayID: CGDirectDisplayID) {
    controllers.removeValue(forKey: displayID)?.close()
    fullscreenPausedDisplays.remove(displayID)
    stopInteractionTimerIfIdle()
  }

  func stopAll() {
    interactionTimer?.invalidate()
    interactionTimer = nil
    controllers.values.forEach { $0.close() }
    controllers.removeAll()
    fullscreenPausedDisplays.removeAll()
  }

  func setUserPaused(_ paused: Bool) {
    userPaused = paused
    updatePlaybackState()
  }

  func setFullscreenPausedDisplays(_ displayIDs: Set<CGDirectDisplayID>) {
    guard displayIDs != fullscreenPausedDisplays else { return }
    fullscreenPausedDisplays = displayIDs

    for (displayID, controller) in controllers {
      controller.setFullscreenSuppressed(displayIDs.contains(displayID))
    }

    updatePlaybackState()
  }

  func setFPS(_ fps: Int) {
    effectiveFPS = max(1, fps)
    controllers.values.forEach { $0.renderer.setFPS(effectiveFPS) }
  }

  func setRenderScale(_ scale: Double) {
    effectiveScale = min(max(scale, 0.25), 1.0)
    controllers.values.forEach {
      $0.renderer.setRenderScale(effectiveScale)
    }
  }

  func apply(policy: PerformancePolicy) {
    policyPaused = policy.shouldPause
    setFPS(policy.targetFPS)
    setRenderScale(policy.renderScale)
    updatePlaybackState()
  }

  func setProperties(
    _ properties: [String: WallpaperPropertyValue],
    for wallpaperID: UUID
  ) {
    controllers.values
      .filter { $0.wallpaperID == wallpaperID }
      .forEach { $0.renderer.setProperties(properties) }
  }

  func updateAudio(_ frame: AudioFrame) {
    latestAudio = frame

    for (displayID, controller) in controllers {
      guard !fullscreenPausedDisplays.contains(displayID) else { continue }

      controller.renderer.updateAudio(
        controller.grantedPermissions.contains(.systemAudio) ? frame : .zero
      )
    }
  }

  private func updatePlaybackState() {
    for (displayID, controller) in controllers {
      let shouldPause =
        userPaused
        || policyPaused
        || fullscreenPausedDisplays.contains(displayID)

      if shouldPause {
        controller.renderer.pause()
      } else {
        controller.renderer.play()
      }
    }
  }

  private func startInteractionUpdatesIfNeeded() {
    guard interactionTimer == nil else { return }

    interactionTimer = .scheduledTimer(
      withTimeInterval: 1.0 / 60.0,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }

        for (displayID, controller) in self.controllers {
          guard !self.fullscreenPausedDisplays.contains(displayID) else {
            continue
          }

          if controller.grantedPermissions.contains(.mouse) {
            let state = InteractionState.forScreen(controller.display.screen)
            controller.renderer.updateInteraction(state)
          } else {
            controller.renderer.updateInteraction(
              InteractionState(
                normalizedMouse: CGPoint(x: 0.5, y: 0.5)
              )
            )
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
