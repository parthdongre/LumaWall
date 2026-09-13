import Foundation
import Testing
@testable import LumaWall

@Test @MainActor
func livePreviewActivatesOnlyOneWallpaper() async throws {
  let coordinator = LivePreviewCoordinator(
    hoverDelayNanoseconds: 5_000_000
  )

  let first = UUID()
  let second = UUID()

  let firstActivation = coordinator.hover(first)
  await firstActivation?.value
  #expect(coordinator.activeWallpaperID == first)

  let secondActivation = coordinator.hover(second)
  await secondActivation?.value
  #expect(coordinator.activeWallpaperID == second)

  coordinator.leave(second)
  #expect(coordinator.activeWallpaperID == nil)
}

@Test @MainActor
func livePreviewCancelledHoverNeverStartsRenderer() async throws {
  let coordinator = LivePreviewCoordinator(
    hoverDelayNanoseconds: 50_000_000
  )

  let wallpaper = UUID()

  let pendingActivation = coordinator.hover(wallpaper)
  coordinator.leave(wallpaper)

  await pendingActivation?.value

  #expect(coordinator.activeWallpaperID == nil)
}
