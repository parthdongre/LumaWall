import Foundation

enum LibraryScope: String, CaseIterable, Identifiable, Hashable {
  case all
  case favorites
  case recent
  case metal
  case web
  case video
  case image
  case audioReactive

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .all: return "All"
    case .favorites: return "Favorites"
    case .recent: return "Recent"
    case .metal: return "Metal"
    case .web: return "Web / WebGL"
    case .video: return "Video"
    case .image: return "Images"
    case .audioReactive: return "Audio Reactive"
    }
  }

  var symbolName: String {
    switch self {
    case .all: return "square.grid.2x2"
    case .favorites: return "star"
    case .recent: return "clock"
    case .metal: return "cpu"
    case .web: return "globe"
    case .video: return "film"
    case .image: return "photo"
    case .audioReactive: return "waveform"
    }
  }
}

enum LibrarySortOrder: String, CaseIterable, Identifiable {
  case name
  case type
  case author
  case recent

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .name: return "Name"
    case .type: return "Type"
    case .author: return "Author"
    case .recent: return "Recently Used"
    }
  }
}

enum RenderQualityPreset: String, CaseIterable, Identifiable {
  case eco
  case balanced
  case ultra
  case custom

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .eco: return "Eco"
    case .balanced: return "Balanced"
    case .ultra: return "Ultra"
    case .custom: return "Custom"
    }
  }

  var targetFPS: Int? {
    switch self {
    case .eco: return 30
    case .balanced: return 60
    case .ultra: return 120
    case .custom: return nil
    }
  }

  var renderScale: Double? {
    switch self {
    case .eco: return 0.65
    case .balanced: return 0.85
    case .ultra: return 1.0
    case .custom: return nil
    }
  }
}
