import Foundation
import Testing
@testable import LumaWall

@Test @MainActor
func bundledWallpaperCollectionIsDiscoverable() {
  let library = WallpaperLibrary()
  let wallpapers = library.loadAll()
  let names = Set(wallpapers.map(\.name))

  let expected: Set<String> = [
    "Aurora",
    "Neon Grid",
    "Starfield Warp",
    "Plasma Ribbons",
    "Event Horizon",
    "Liquid Chrome",
    "Particle Bloom",
    "Synth Sunset",
    "Electric Storm",
    "Cosmic Dust",
    "Fractal Tunnel",
    "Nebula Flow",
    "Ocean Glass",
    "Voronoi Pulse",
    "Matrix Cascade",
    "Firefly Garden",
    "Audio Spectrum",
  ]

  #expect(expected.isSubset(of: names))
  #expect(wallpapers.count >= expected.count)
  #expect(Set(wallpapers.map(\.id)).count == wallpapers.count)
  #expect(wallpapers.allSatisfy { FileManager.default.fileExists(atPath: $0.entryURL.path) })
}

@Test
func qualityPresetsHaveStableTargets() {
  #expect(RenderQualityPreset.automatic.targetFPS == nil)
  #expect(RenderQualityPreset.automatic.renderScale == nil)
  #expect(RenderQualityPreset.eco.targetFPS == 30)
  #expect(RenderQualityPreset.eco.renderScale == 0.65)
  #expect(RenderQualityPreset.balanced.targetFPS == 60)
  #expect(RenderQualityPreset.balanced.renderScale == 0.85)
  #expect(RenderQualityPreset.ultra.targetFPS == 120)
  #expect(RenderQualityPreset.ultra.renderScale == 1.0)
  #expect(RenderQualityPreset.custom.targetFPS == nil)
  #expect(RenderQualityPreset.custom.renderScale == nil)
}

@Test
func libraryScopesHaveStableIdentifiers() {
  #expect(LibraryScope.all.rawValue == "all")
  #expect(LibraryScope.favorites.rawValue == "favorites")
  #expect(LibraryScope.recent.rawValue == "recent")
  #expect(Set(LibraryScope.allCases.map(\.rawValue)).count == LibraryScope.allCases.count)
}


@Test @MainActor
func detectedDisplaysExposePixelTargets() {
  for display in DisplayManager.connectedDisplays() {
    #expect(display.nativePixelSize.width > 0)
    #expect(display.nativePixelSize.height > 0)
    #expect(display.backingScaleFactor >= 1)
    #expect(display.maximumFPS >= 1)
  }
}
