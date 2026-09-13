import Foundation

struct CreatorPackageBuilder {
  private let fileManager = FileManager.default

  private static let imageExtensions: Set<String> = [
    "png", "jpg", "jpeg", "heic", "tiff", "webp"
  ]

  private static let videoExtensions: Set<String> = [
    "mp4", "mov", "m4v"
  ]

  func summary(for source: URL) throws -> CreatorAssetSummary {
    let type = try wallpaperType(for: source)

    guard
      let values = try? source.resourceValues(
        forKeys: [.fileSizeKey, .isRegularFileKey]
      ),
      values.isRegularFile == true
    else {
      throw CreatorPackageError.unreadableSource
    }

    return CreatorAssetSummary(
      type: type,
      filename: source.lastPathComponent,
      fileSizeBytes: Int64(values.fileSize ?? 0)
    )
  }

  func build(
    draft: CreatorWallpaperDraft,
    id: UUID,
    at destinationRoot: URL
  ) throws -> URL {
    guard let source = draft.sourceURL else {
      throw CreatorPackageError.missingSource
    }

    let type = try wallpaperType(for: source)

    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let author = draft.author.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !name.isEmpty else {
      throw CreatorPackageError.invalidMetadata("Give the wallpaper a name.")
    }

    guard !author.isEmpty else {
      throw CreatorPackageError.invalidMetadata("Add a creator name.")
    }

    let root = destinationRoot.appendingPathComponent(
      id.uuidString,
      isDirectory: true
    )

    if fileManager.fileExists(atPath: root.path) {
      try fileManager.removeItem(at: root)
    }

    let assets = root.appendingPathComponent("assets", isDirectory: true)
    try fileManager.createDirectory(
      at: assets,
      withIntermediateDirectories: true
    )

    let sourceExtension = source.pathExtension.lowercased()
    let entryName =
      sourceExtension.isEmpty
      ? "wallpaper"
      : "wallpaper.\(sourceExtension)"

    let entryURL = assets.appendingPathComponent(entryName)
    try fileManager.copyItem(at: source, to: entryURL)

    var thumbnailPath: String?

    if let thumbnail = draft.thumbnailURL {
      let ext = thumbnail.pathExtension.lowercased()
      guard Self.imageExtensions.contains(ext) else {
        throw CreatorPackageError.unsupportedSource(ext)
      }

      let name = ext.isEmpty ? "thumbnail" : "thumbnail.\(ext)"
      let target = root.appendingPathComponent(name)
      try fileManager.copyItem(at: thumbnail, to: target)
      thumbnailPath = name
    } else if type == .image {
      // Reuse the source image as the card preview instead of duplicating it.
      thumbnailPath = "assets/\(entryName)"
    }

    let manifest = WallpaperManifest(
      formatVersion: 1,
      id: id.uuidString,
      name: name,
      author: author,
      type: type,
      entry: "assets/\(entryName)",
      thumbnail: thumbnailPath,
      preview: nil,
      renderer: nil,
      properties: [],
      permissions: [],
      description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      tags: draft.tags.isEmpty ? nil : draft.tags,
      category: draft.category.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      version: "1.0",
      source: "LumaWall Creator Studio"
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    try encoder
      .encode(manifest)
      .write(
        to: root.appendingPathComponent("wallpaper.json"),
        options: .atomic
      )

    return root
  }

  func wallpaperType(for source: URL) throws -> WallpaperType {
    let ext = source.pathExtension.lowercased()

    if Self.imageExtensions.contains(ext) {
      return .image
    }

    if Self.videoExtensions.contains(ext) {
      return .video
    }

    throw CreatorPackageError.unsupportedSource(
      ext.isEmpty ? "unknown" : ext
    )
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
