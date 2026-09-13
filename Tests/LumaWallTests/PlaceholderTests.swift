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
