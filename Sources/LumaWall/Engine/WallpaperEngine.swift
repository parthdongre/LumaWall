import AppKit
import CoreGraphics

struct ActiveRendererSnapshot:
  Identifiable,
  Hashable,
  Sendable
{
  var displayID:
    CGDirectDisplayID

  var wallpaperID:
    UUID

  var displayName:
    String

  var diagnostics:
    RendererDiagnostics

  var id:
    CGDirectDisplayID
  {
    displayID
  }
}

@MainActor
final class WallpaperEngine {
  private var controllers:
    [CGDirectDisplayID:
      WallpaperWindowController] = [:]

  private var interactionTimer:
    Timer?

  private var latestAudio =
    AudioFrame.zero

  private var userPaused =
    false

  private var policyPaused =
    false

  private var systemSuspended =
    false

  private var fullscreenPausedDisplays =
    Set<CGDirectDisplayID>()

  private var effectiveFPS =
    60

  private var effectiveScale =
    1.0

  private var transitionSettings =
    WallpaperTransitionSettings.smooth

  private var displayProfiles:
    [CGDirectDisplayID:
      DisplayPerformanceProfile] = [:]

  private var fitModes:
    [UUID:
      WallpaperFitMode] = [:]

  private var videoSettings:
    [UUID:
      VideoPlaybackSettings] = [:]

  private var timeDateSettings:
    [UUID:
      TimeDateOverlaySettings] = [:]

  private var previousInteraction:
    [CGDirectDisplayID:
      InteractionState] = [:]

  var assignmentSnapshot:
    [CGDirectDisplayID:
      UUID]
  {
    controllers
      .mapValues(
        \.wallpaperID
      )
  }

  var fullscreenPausedDisplayIDs:
    Set<CGDirectDisplayID>
  {
    fullscreenPausedDisplays
  }

  var rendererSnapshots:
    [ActiveRendererSnapshot]
  {
    controllers
      .values
      .map {
        ActiveRendererSnapshot(
          displayID:
            $0.display.id,
          wallpaperID:
            $0.wallpaperID,
          displayName:
            $0.display.name,
          diagnostics:
            $0.renderer
              .diagnostics
        )
      }
      .sorted {
        $0.displayID
          < $1.displayID
      }
  }

  func setTransitionSettings(
    _ settings:
      WallpaperTransitionSettings
  ) {
    transitionSettings =
      WallpaperTransitionSettings(
        style:
          settings.style,
        duration:
          min(
            max(
              settings.duration,
              0
            ),
            4
          )
      )
  }

  func setDisplayProfiles(
    _ profiles:
      [CGDirectDisplayID:
        DisplayPerformanceProfile]
  ) {
    displayProfiles =
      profiles

    for controller
      in controllers.values
    {
      configurePerformance(
        for: controller
      )
    }
  }

  func setFitMode(
    _ mode:
      WallpaperFitMode,
    for wallpaperID:
      UUID
  ) {
    fitModes[
      wallpaperID
    ] = mode

    controllers
      .values
      .filter {
        $0.wallpaperID
          == wallpaperID
      }
      .forEach {
        $0.renderer
          .setFitMode(
            mode
          )
      }
  }

  func setTimeDateOverlay(
    _ settings:
      TimeDateOverlaySettings,
    for wallpaperID:
      UUID
  ) {
    timeDateSettings[
      wallpaperID
    ] = settings

    controllers
      .values
      .filter {
        $0.wallpaperID
          == wallpaperID
      }
      .forEach {
        $0.setTimeDateOverlay(
          settings
        )
      }
  }

  func setVideoPlaybackSettings(
    _ settings:
      VideoPlaybackSettings,
    for wallpaperID:
      UUID
  ) {
    videoSettings[
      wallpaperID
    ] = settings

    controllers
      .values
      .filter {
        $0.wallpaperID
          == wallpaperID
      }
      .forEach {
        $0.renderer
          .setVideoPlaybackSettings(
            settings
          )
      }
  }

  func apply(
    wallpaper:
      Wallpaper,
    to displays:
      [DisplayDescriptor],
    properties:
      [String:
        WallpaperPropertyValue] = [:]
  ) throws {
    for display
      in displays
    {
      let outgoing =
        controllers[
          display.id
        ]

      let renderer =
        RendererFactory
          .makeRenderer(
            for:
              wallpaper.type
          )

      renderer.configure(
        for: display
      )

      try renderer.load(
        wallpaper
      )

      renderer.setProperties(
        properties
      )

      renderer.setFitMode(
        fitModes[
          wallpaper.id
        ]
        ?? displayProfiles[
          display.id
        ]?.fitMode
        ?? .fill
      )

      renderer
        .setVideoPlaybackSettings(
          videoSettings[
            wallpaper.id
          ]
          ?? .init()
        )

      renderer.updateAudio(
        wallpaper
          .grantedPermissions
          .contains(
            .systemAudio
          )
        ? latestAudio
        : .zero
      )

      let incoming =
        WallpaperWindowController(
          display:
            display,
          wallpaperID:
            wallpaper.id,
          grantedPermissions:
            wallpaper
              .grantedPermissions,
          renderer:
            renderer
        )

      controllers[
        display.id
      ] = incoming

      incoming.setTimeDateOverlay(
        timeDateSettings[
          wallpaper.id
        ]
        ?? .init()
      )

      configurePerformance(
        for: incoming
      )

      incoming
        .setFullscreenSuppressed(
          fullscreenPausedDisplays
            .contains(
              display.id
            )
        )

      let shouldAnimate =
        outgoing != nil
        && !fullscreenPausedDisplays
          .contains(
            display.id
          )
        && transitionSettings.style
          != .instant
        && transitionSettings.duration
          > 0

      incoming.show(
        alpha:
          shouldAnimate
          ? 0
          : 1
      )

      if let outgoing,
        shouldAnimate
      {
        incoming.orderAbove(
          outgoing
        )
      }

      if shouldPause(
        displayID:
          display.id
      ) {
        renderer.pause()
      } else {
        renderer.play()
      }

      guard
        let outgoing
      else {
        continue
      }

      if shouldAnimate {
        performTransition(
          from:
            outgoing,
          to:
            incoming
        )
      } else {
        outgoing.close()
      }
    }

    startInteractionUpdatesIfNeeded()
    updatePlaybackState()
  }

  func refreshDisplays(
    _ displays:
      [DisplayDescriptor]
  ) {
    let liveIDs =
      Set(
        displays.map(
          \.id
        )
      )

    for display
      in displays
    {
      controllers[
        display.id
      ]?
        .updateDisplay(
          display
        )

      if let controller =
        controllers[
          display.id
        ]
      {
        configurePerformance(
          for:
            controller
        )
      }
    }

    for id
      in controllers.keys
      where !liveIDs
        .contains(id)
    {
      controllers
        .removeValue(
          forKey: id
        )?
        .close()

      previousInteraction
        .removeValue(
          forKey: id
        )
    }

    fullscreenPausedDisplays
      .formIntersection(
        liveIDs
      )

    updatePlaybackState()
    stopInteractionTimerIfIdle()
  }

  func removeWallpaper(
    from displayID:
      CGDirectDisplayID
  ) {
    controllers
      .removeValue(
        forKey:
          displayID
      )?
      .close()

    fullscreenPausedDisplays
      .remove(
        displayID
      )

    previousInteraction
      .removeValue(
        forKey:
          displayID
      )

    stopInteractionTimerIfIdle()
  }

  func stopAll() {
    interactionTimer?
      .invalidate()

    interactionTimer = nil

    controllers
      .values
      .forEach {
        $0.close()
      }

    controllers
      .removeAll()

    previousInteraction
      .removeAll()

    fullscreenPausedDisplays
      .removeAll()
  }

  func setUserPaused(
    _ paused: Bool
  ) {
    userPaused =
      paused

    updatePlaybackState()
  }

  func setSystemSuspended(
    _ suspended: Bool
  ) {
    systemSuspended =
      suspended

    updatePlaybackState()
  }

  func setFullscreenPausedDisplays(
    _ displayIDs:
      Set<
        CGDirectDisplayID
      >
  ) {
    guard
      displayIDs
        != fullscreenPausedDisplays
    else {
      return
    }

    fullscreenPausedDisplays =
      displayIDs

    for (
      displayID,
      controller
    ) in controllers {
      controller
        .setFullscreenSuppressed(
          displayIDs
            .contains(
              displayID
            )
        )
    }

    updatePlaybackState()
  }

  func setFPS(
    _ fps: Int
  ) {
    effectiveFPS =
      max(
        1,
        fps
      )

    controllers
      .values
      .forEach {
        configurePerformance(
          for: $0
        )
      }
  }

  func setRenderScale(
    _ scale: Double
  ) {
    effectiveScale =
      min(
        max(
          scale,
          0.25
        ),
        1
      )

    controllers
      .values
      .forEach {
        configurePerformance(
          for: $0
        )
      }
  }

  func apply(
    policy:
      PerformancePolicy
  ) {
    policyPaused =
      policy.shouldPause

    effectiveFPS =
      max(
        1,
        policy.targetFPS
      )

    effectiveScale =
      min(
        max(
          policy.renderScale,
          0.25
        ),
        1
      )

    controllers
      .values
      .forEach {
        configurePerformance(
          for: $0
        )
      }

    updatePlaybackState()
  }

  func setProperties(
    _ properties:
      [String:
        WallpaperPropertyValue],
    for wallpaperID:
      UUID
  ) {
    controllers
      .values
      .filter {
        $0.wallpaperID
          == wallpaperID
      }
      .forEach {
        $0.renderer
          .setProperties(
            properties
          )
      }
  }

  func updateAudio(
    _ frame:
      AudioFrame
  ) {
    latestAudio = frame

    for (
      displayID,
      controller
    ) in controllers {
      guard
        !fullscreenPausedDisplays
          .contains(
            displayID
          ),
        !systemSuspended
      else {
        continue
      }

      controller
        .renderer
        .updateAudio(
          controller
            .grantedPermissions
            .contains(
              .systemAudio
            )
          ? frame
          : .zero
        )
    }
  }

  private func performTransition(
    from outgoing:
      WallpaperWindowController,
    to incoming:
      WallpaperWindowController
  ) {
    switch
      transitionSettings.style
    {
    case .instant:
      outgoing.close()

    case .fadeThroughBlack:
      outgoing
        .transitionOut(
          settings:
            transitionSettings
        ) {
          [weak outgoing,
           weak incoming] in

          guard let incoming
          else {
            outgoing?
              .close()
            return
          }

          outgoing?
            .close()

          incoming
            .transitionIn(
              settings:
                self
                  .transitionSettings
            ) {}
        }

    case .crossfade,
      .zoom:
      incoming
        .transitionIn(
          settings:
            transitionSettings
        ) {}

      outgoing
        .transitionOut(
          settings:
            transitionSettings
        ) {
          [weak outgoing] in

          outgoing?
            .close()
        }
    }
  }

  private func configurePerformance(
    for controller:
      WallpaperWindowController
  ) {
    let display =
      controller.display

    let profile =
      displayProfiles[
        display.id
      ]

    let fps =
      min(
        display.maximumFPS,
        profile.map {
          min(
            $0.targetFPS,
            effectiveFPS
          )
        }
        ?? effectiveFPS
      )

    let scale:
      Double

    if profile?
      .maximumResolution
      == true
    {
      scale = 1
    } else {
      scale =
        min(
          profile?
            .renderScale
          ?? effectiveScale,
          effectiveScale
        )
    }

    controller
      .renderer
      .setFPS(
        max(
          1,
          fps
        )
      )

    controller
      .renderer
      .setRenderScale(
        scale
      )

    controller
      .renderer
      .setFitMode(
        profile?.fitMode
        ?? fitModes[
          controller
            .wallpaperID
        ]
        ?? .fill
      )
  }

  private func shouldPause(
    displayID:
      CGDirectDisplayID
  ) -> Bool {
    userPaused
      || policyPaused
      || systemSuspended
      || fullscreenPausedDisplays
        .contains(
          displayID
        )
  }

  private func updatePlaybackState() {
    for (
      displayID,
      controller
    ) in controllers {
      if shouldPause(
        displayID:
          displayID
      ) {
        controller
          .renderer
          .pause()
      } else {
        controller
          .renderer
          .play()
      }
    }
  }

  private func startInteractionUpdatesIfNeeded() {
    guard
      interactionTimer == nil
    else {
      return
    }

    interactionTimer =
      .scheduledTimer(
        withTimeInterval:
          1.0 / 60.0,
        repeats: true
      ) {
        [weak self] _ in

        Task {
          @MainActor in

          guard let self
          else {
            return
          }

          for (
            displayID,
            controller
          ) in self.controllers {
            guard
              !self
                .shouldPause(
                  displayID:
                    displayID
                )
            else {
              continue
            }

            if controller
              .grantedPermissions
              .contains(
                .mouse
              )
            {
              let state =
                InteractionState
                  .forScreen(
                    controller
                      .display
                      .screen,
                    previous:
                      self
                        .previousInteraction[
                          displayID
                        ]
                  )

              self
                .previousInteraction[
                  displayID
                ] = state

              controller
                .renderer
                .updateInteraction(
                  state
                )
            } else {
              controller
                .renderer
                .updateInteraction(
                  InteractionState(
                    normalizedMouse:
                      CGPoint(
                        x: 0.5,
                        y: 0.5
                      )
                  )
                )
            }
          }
        }
      }
  }

  private func stopInteractionTimerIfIdle() {
    guard
      controllers.isEmpty
    else {
      return
    }

    interactionTimer?
      .invalidate()

    interactionTimer =
      nil
  }
}
