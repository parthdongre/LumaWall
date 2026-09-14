import AVFoundation
import Foundation

enum WallpaperFitMode: String, Codable, CaseIterable, Identifiable, Sendable {
  case fill
  case fit
  case stretch
  case center

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .fill: return "Fill"
    case .fit: return "Fit"
    case .stretch: return "Stretch"
    case .center: return "Center"
    }
  }

  var videoGravity: AVLayerVideoGravity {
    switch self {
    case .fill: return .resizeAspectFill
    case .fit, .center: return .resizeAspect
    case .stretch: return .resize
    }
  }
}

enum WallpaperTransitionStyle: String, Codable, CaseIterable, Identifiable, Sendable {
  case instant
  case crossfade
  case fadeThroughBlack
  case zoom

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .instant: return "Instant"
    case .crossfade: return "Crossfade"
    case .fadeThroughBlack: return "Fade Through Black"
    case .zoom: return "Soft Zoom"
    }
  }
}

struct WallpaperTransitionSettings: Codable, Hashable, Sendable {
  var style: WallpaperTransitionStyle = .crossfade
  var duration: TimeInterval = 0.8

  static let smooth = WallpaperTransitionSettings(
    style: .crossfade,
    duration: 0.8
  )
}

struct DisplayPerformanceProfile: Codable, Hashable, Identifiable, Sendable {
  var displayID: UInt32
  var persistentDisplayID: String? = nil
  var targetFPS: Int
  var renderScale: Double
  var maximumResolution: Bool
  var fitMode: WallpaperFitMode

  var id: UInt32 { displayID }
}

struct VideoPlaybackSettings: Codable, Hashable, Sendable {
  var playbackRate: Double = 1.0
  var muted: Bool = true
  var loop: Bool = true
}

struct PowerPerformanceProfile: Codable, Hashable, Sendable {
  var fps: Int
  var renderScale: Double
  var maximumResolution: Bool

  static let pluggedIn = PowerPerformanceProfile(
    fps: 120,
    renderScale: 1.0,
    maximumResolution: true
  )

  static let battery = PowerPerformanceProfile(
    fps: 60,
    renderScale: 1.0,
    maximumResolution: true
  )

  static let lowPower = PowerPerformanceProfile(
    fps: 30,
    renderScale: 0.75,
    maximumResolution: false
  )
}
