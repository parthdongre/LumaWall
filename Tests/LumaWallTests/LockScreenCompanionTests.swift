import CoreGraphics
import Foundation
import Testing
@testable import LumaWall

@Test
func lockScreenFillCoversTargetWithoutDistortion() {
  let rect = LockScreenCompositionGeometry.destinationRect(
    sourceSize: CGSize(width: 1920, height: 1080),
    targetSize: CGSize(width: 3024, height: 1964),
    fitMode: .fill
  )

  #expect(rect.width >= 3024)
  #expect(rect.height >= 1964)
  #expect(abs((rect.width / rect.height) - (1920.0 / 1080.0)) < 0.0001)
}

@Test
func lockScreenFitStaysInsideTarget() {
  let rect = LockScreenCompositionGeometry.destinationRect(
    sourceSize: CGSize(width: 1920, height: 1080),
    targetSize: CGSize(width: 3024, height: 1964),
    fitMode: .fit
  )

  #expect(rect.width <= 3024)
  #expect(rect.height <= 1964)
  #expect(abs((rect.width / rect.height) - (1920.0 / 1080.0)) < 0.0001)
}

@Test
func lockScreenStretchMatchesTargetExactly() {
  let rect = LockScreenCompositionGeometry.destinationRect(
    sourceSize: CGSize(width: 1000, height: 1000),
    targetSize: CGSize(width: 3840, height: 2160),
    fitMode: .stretch
  )

  #expect(rect == CGRect(x: 0, y: 0, width: 3840, height: 2160))
}

@Test
func lockScreenCenterKeepsSourceDimensions() {
  let rect = LockScreenCompositionGeometry.destinationRect(
    sourceSize: CGSize(width: 1000, height: 600),
    targetSize: CGSize(width: 2000, height: 1200),
    fitMode: .center
  )

  #expect(rect.width == 1000)
  #expect(rect.height == 600)
  #expect(rect.midX == 1000)
  #expect(rect.midY == 600)
}

@Test
func lockScreenSettingsRoundTrip() throws {
  let wallpaperID = UUID()
  let original = LockScreenCompanionSettings(
    useActiveWallpaperPerDisplay: false,
    fallbackWallpaperID: wallpaperID,
    fitMode: .fit,
    blurRadius: 14,
    dimAmount: 0.25,
    saturation: 0.8,
    vignetteIntensity: 0.7,
    includeWallpaperTimeDate: true,
    autoRefresh: true
  )

  let data = try JSONEncoder().encode(original)
  let decoded = try JSONDecoder().decode(
    LockScreenCompanionSettings.self,
    from: data
  )

  #expect(decoded == original)
}

@Test
func lockScreenDefaultsAreConservative() {
  let settings = LockScreenCompanionSettings.defaultComposition

  #expect(settings.useActiveWallpaperPerDisplay)
  #expect(settings.fitMode == .fill)
  #expect(settings.blurRadius >= 0)
  #expect(settings.dimAmount >= 0 && settings.dimAmount < 0.5)
  #expect(!settings.autoRefresh)
}
