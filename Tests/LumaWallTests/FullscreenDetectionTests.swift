import AppKit
import CoreGraphics
import Testing
@testable import LumaWall

private let builtInDisplayID: CGDirectDisplayID = 100
private let externalDisplayID: CGDirectDisplayID = 200

private let builtInDisplay = FullscreenDisplayGeometry(
  id: builtInDisplayID,
  bounds: CGRect(x: 0, y: 0, width: 2940, height: 1912)
)

private let externalDisplay = FullscreenDisplayGeometry(
  id: externalDisplayID,
  bounds: CGRect(x: 2940, y: 0, width: 3840, height: 2160)
)

private func window(
  _ bounds: CGRect,
  pid: Int32 = 42,
  layer: Int = 0,
  alpha: Double = 1
) -> ForegroundWindowGeometry {
  ForegroundWindowGeometry(
    ownerPID: pid,
    layer: layer,
    bounds: bounds,
    alpha: alpha
  )
}

@Test
func normalMaximizedMacBookWindowIsNotFullscreen() {
  let display = builtInDisplay.bounds

  // This reproduces the user's recording: a normal maximized browser fills the
  // width and everything below the menu bar. Its area exceeds the old 97%
  // threshold, but it is not macOS fullscreen.
  let maximized = CGRect(
    x: display.minX,
    y: display.minY + 50,
    width: display.width,
    height: display.height - 50
  )

  let coverage =
    maximized.width * maximized.height
    / (display.width * display.height)

  #expect(coverage > 0.97)
  #expect(
    !FullscreenDetection.matchesDisplay(
      maximized,
      displayBounds: display
    )
  )

  let ids = FullscreenDetection.matchingDisplayIDs(
    windows: [window(maximized)],
    frontmostPID: 42,
    ownPID: 999,
    displays: [builtInDisplay]
  )

  #expect(ids.isEmpty)
}

@Test
func exactFullscreenWindowMatchesOnlyItsDisplay() {
  let ids = FullscreenDetection.matchingDisplayIDs(
    windows: [window(builtInDisplay.bounds)],
    frontmostPID: 42,
    ownPID: 999,
    displays: [builtInDisplay, externalDisplay]
  )

  #expect(ids == [builtInDisplayID])
}

@Test
func fullscreenExternalDisplayDoesNotPauseBuiltInDisplay() {
  let ids = FullscreenDetection.matchingDisplayIDs(
    windows: [window(externalDisplay.bounds)],
    frontmostPID: 42,
    ownPID: 999,
    displays: [builtInDisplay, externalDisplay]
  )

  #expect(ids == [externalDisplayID])
  #expect(!ids.contains(builtInDisplayID))
}

@Test
func separateFullscreenWindowsCanMatchTwoDisplays() {
  let ids = FullscreenDetection.matchingDisplayIDs(
    windows: [
      window(builtInDisplay.bounds),
      window(externalDisplay.bounds),
    ],
    frontmostPID: 42,
    ownPID: 999,
    displays: [builtInDisplay, externalDisplay]
  )

  #expect(ids == [builtInDisplayID, externalDisplayID])
}

@Test
func tinyFullscreenCoordinateDriftIsAccepted() {
  let drifted = builtInDisplay.bounds.insetBy(dx: -3, dy: -3)

  #expect(
    FullscreenDetection.matchesDisplay(
      drifted,
      displayBounds: builtInDisplay.bounds
    )
  )
}

@Test
func menuBarOrDockGapIsRejected() {
  let menuGap = CGRect(x: 0, y: 32, width: 2940, height: 1880)
  let dockGap = CGRect(x: 0, y: 0, width: 2940, height: 1820)

  #expect(
    !FullscreenDetection.matchesDisplay(
      menuGap,
      displayBounds: builtInDisplay.bounds
    )
  )

  #expect(
    !FullscreenDetection.matchesDisplay(
      dockGap,
      displayBounds: builtInDisplay.bounds
    )
  )
}

@Test
func shiftedFullSizeWindowIsNotFullscreen() {
  let shifted = CGRect(x: 12, y: 0, width: 2940, height: 1912)

  #expect(
    !FullscreenDetection.matchesDisplay(
      shifted,
      displayBounds: builtInDisplay.bounds
    )
  )
}

@Test
func spanningWindowIsNotMistakenForEitherDisplay() {
  let spanning = CGRect(
    x: 0,
    y: 0,
    width: 6780,
    height: 2160
  )

  let ids = FullscreenDetection.matchingDisplayIDs(
    windows: [window(spanning)],
    frontmostPID: 42,
    ownPID: 999,
    displays: [builtInDisplay, externalDisplay]
  )

  #expect(ids.isEmpty)
}

@Test
func transparentAndNonZeroLayerWindowsAreIgnored() {
  let ids = FullscreenDetection.matchingDisplayIDs(
    windows: [
      window(builtInDisplay.bounds, layer: 25),
      window(externalDisplay.bounds, alpha: 0),
    ],
    frontmostPID: 42,
    ownPID: 999,
    displays: [builtInDisplay, externalDisplay]
  )

  #expect(ids.isEmpty)
}

@Test
func nonForegroundWindowsAreIgnored() {
  let ids = FullscreenDetection.matchingDisplayIDs(
    windows: [
      window(builtInDisplay.bounds, pid: 41),
      window(externalDisplay.bounds, pid: 43),
    ],
    frontmostPID: 42,
    ownPID: 999,
    displays: [builtInDisplay, externalDisplay]
  )

  #expect(ids.isEmpty)
}

@Test
func lumawallOwnWindowsCanNeverTriggerFullscreenPause() {
  let ids = FullscreenDetection.matchingDisplayIDs(
    windows: [window(builtInDisplay.bounds, pid: 42)],
    frontmostPID: 42,
    ownPID: 42,
    displays: [builtInDisplay]
  )

  #expect(ids.isEmpty)
}

@Test
func fullscreenPauseRequiresTwoStableSamples() {
  var debouncer = FullscreenPauseDebouncer()
  let fullscreen: Set<CGDirectDisplayID> = [builtInDisplayID]

  #expect(debouncer.ingest(fullscreen) == nil)
  #expect(debouncer.committed.isEmpty)

  #expect(debouncer.ingest(fullscreen) == fullscreen)
  #expect(debouncer.committed == fullscreen)
}

@Test
func fullscreenResumeIsImmediate() {
  var debouncer = FullscreenPauseDebouncer()
  let fullscreen: Set<CGDirectDisplayID> = [builtInDisplayID]

  _ = debouncer.ingest(fullscreen)
  _ = debouncer.ingest(fullscreen)

  #expect(debouncer.committed == fullscreen)
  #expect(debouncer.ingest([]) == [])
  #expect(debouncer.committed.isEmpty)
}

@Test
func alternatingFalsePositiveSamplesNeverPause() {
  var debouncer = FullscreenPauseDebouncer()
  let fullscreen: Set<CGDirectDisplayID> = [builtInDisplayID]

  for _ in 0..<20 {
    #expect(debouncer.ingest(fullscreen) == nil)
    #expect(debouncer.ingest([]) == nil || debouncer.committed.isEmpty)
  }

  #expect(debouncer.committed.isEmpty)
}

@Test @MainActor
func wallpaperWindowLevelStaysBetweenDesktopAndFinderIcons() {
  let desktop = Int(CGWindowLevelForKey(.desktopWindow))
  let icons = Int(CGWindowLevelForKey(.desktopIconWindow))
  let wallpaper = WallpaperWindowController.wallpaperWindowLevel.rawValue

  #expect(wallpaper > desktop)
  #expect(wallpaper < icons)
}

@Test @MainActor
func wallpaperWindowsNeverJoinAnotherAppsFullscreenSpace() {
  let behavior = WallpaperWindowController.wallpaperCollectionBehavior

  #expect(behavior.contains(.canJoinAllSpaces))
  #expect(behavior.contains(.stationary))
  #expect(behavior.contains(.ignoresCycle))
  #expect(!behavior.contains(.fullScreenAuxiliary))
}
