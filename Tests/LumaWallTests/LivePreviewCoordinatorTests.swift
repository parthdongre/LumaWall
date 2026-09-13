import Foundation
import Testing
@testable import LumaWall

@Test @MainActor
func livePreviewActivatesOnlyOneWallpaper() async throws {
  let coordinator = LivePreviewCoordinator(
    hoverDelayNanoseconds: 1
  )

  let first = UUID()
  let second = UUID()

  coordinator.hover(first)
  try await Task.sleep(nanoseconds: 1_000_000)
  #expect(coordinator.activeWallpaperID == first)

  coordinator.hover(second)
  try await Task.sleep(nanoseconds: 1_000_000)
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

  coordinator.hover(wallpaper)
  coordinator.leave(wallpaper)

  try await Task.sleep(
    nanoseconds: 70_000_000
  )

  #expect(coordinator.activeWallpaperID == nil)
}
