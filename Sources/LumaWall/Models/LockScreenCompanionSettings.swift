import Foundation

struct LockScreenCompanionSettings: Codable, Hashable, Sendable {
  var useActiveWallpaperPerDisplay = true
  var fallbackWallpaperID: UUID?
  var fitMode: WallpaperFitMode = .fill
  var blurRadius = 8.0
  var dimAmount = 0.16
  var saturation = 0.92
  var vignetteIntensity = 0.35
  var includeWallpaperTimeDate = false
  var autoRefresh = false

  static let defaultComposition = LockScreenCompanionSettings()
}

struct LockScreenSnapshot: Identifiable, Hashable, Sendable {
  var displayID: UInt32
  var displayName: String
  var wallpaperID: UUID
  var wallpaperName: String
  var fileURL: URL
  var pixelWidth: Int
  var pixelHeight: Int
  var generatedAt: Date

  var id: UInt32 { displayID }

  var resolutionLabel: String {
    "\(pixelWidth) × \(pixelHeight)"
  }
}

enum LockScreenCompanionError: LocalizedError {
  case noWallpaper
  case couldNotCreateBitmap
  case couldNotEncodePNG

  var errorDescription: String? {
    switch self {
    case .noWallpaper:
      return "No wallpaper is available for this display."
    case .couldNotCreateBitmap:
      return "LumaWall could not create the native-resolution lock image."
    case .couldNotEncodePNG:
      return "LumaWall could not encode the lock image as PNG."
    }
  }
}
