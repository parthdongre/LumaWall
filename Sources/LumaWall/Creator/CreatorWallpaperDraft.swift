import Foundation

enum CreatorClockPreset: String, CaseIterable, Identifiable, Sendable {
  case none
  case glass
  case minimal
  case bold

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .none: return "None"
    case .glass: return "Glass"
    case .minimal: return "Minimal"
    case .bold: return "Bold Center"
    }
  }

  var overlaySettings: TimeDateOverlaySettings? {
    switch self {
    case .none:
      return nil
    case .glass:
      var value = TimeDateOverlaySettings.glass
      value.enabled = true
      return value
    case .minimal:
      var value = TimeDateOverlaySettings.minimal
      value.enabled = true
      return value
    case .bold:
      var value = TimeDateOverlaySettings.bold
      value.enabled = true
      return value
    }
  }
}

struct CreatorWallpaperDraft: Sendable {
  var sourceURL: URL?
  var thumbnailURL: URL?

  var name = ""
  var author = ""
  var description = ""
  var category = "Featured"
  var tagsText = ""

  var fitMode: WallpaperFitMode = .fill

  var videoLoop = true
  var videoMuted = true
  var videoPlaybackRate = 1.0

  var clockPreset: CreatorClockPreset = .none

  var tags: [String] {
    tagsText
      .split(separator: ",")
      .map {
        $0
          .trimmingCharacters(in: .whitespacesAndNewlines)
      }
      .filter { !$0.isEmpty }
  }

  var isReadyToCreate: Bool {
    sourceURL != nil
      && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  mutating func reset(keepingAuthor: Bool = true) {
    let rememberedAuthor = keepingAuthor ? author : ""
    self = CreatorWallpaperDraft()
    author = rememberedAuthor
  }
}

struct CreatorAssetSummary: Sendable {
  var type: WallpaperType
  var filename: String
  var fileSizeBytes: Int64

  var fileSizeLabel: String {
    ByteCountFormatter.string(
      fromByteCount: fileSizeBytes,
      countStyle: .file
    )
  }
}

enum CreatorPackageError: LocalizedError {
  case missingSource
  case unsupportedSource(String)
  case unreadableSource
  case invalidMetadata(String)

  var errorDescription: String? {
    switch self {
    case .missingSource:
      return "Choose a Canva image or video first."
    case .unsupportedSource(let ext):
      return "Creator Studio does not support .\(ext) files yet."
    case .unreadableSource:
      return "The selected source file could not be read."
    case .invalidMetadata(let message):
      return message
    }
  }
}
