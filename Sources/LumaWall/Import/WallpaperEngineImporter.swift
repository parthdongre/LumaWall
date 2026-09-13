import Foundation

struct WallpaperEngineProjectMetadata: Decodable, Sendable {
  var title: String?
  var description: String?
  var type: String?
  var file: String?
  var preview: String?
}

enum WallpaperEngineImportError: LocalizedError {
  case missingProjectJSON
  case missingEntry
  case unsupportedType(String)
  case unsafePath
  case unreadableProject

  var errorDescription: String? {
    switch self {
    case .missingProjectJSON:
      return "The selected folder does not contain a Wallpaper Engine project.json."
    case .missingEntry:
      return "The Wallpaper Engine project does not identify a usable entry file."
    case .unsupportedType(let type):
      return "Wallpaper Engine project type “\(type)” is not supported yet. LumaWall currently imports simple video, web and static projects."
    case .unsafePath:
      return "The project references a file outside its own folder."
    case .unreadableProject:
      return "The Wallpaper Engine project could not be read."
    }
  }
}

struct WallpaperEngineImporter {
  private let fileManager = FileManager.default

  func importProject(
    at projectRoot: URL,
    destinationRoot: URL,
    id: UUID = UUID()
  ) throws -> URL {
    let root = projectRoot
      .standardizedFileURL
      .resolvingSymlinksInPath()

    let projectJSON = root.appendingPathComponent("project.json")

    guard fileManager.fileExists(atPath: projectJSON.path) else {
      throw WallpaperEngineImportError.missingProjectJSON
    }

    let metadata: WallpaperEngineProjectMetadata
    do {
      metadata = try JSONDecoder().decode(
        WallpaperEngineProjectMetadata.self,
        from: Data(contentsOf: projectJSON)
      )
    } catch {
      throw WallpaperEngineImportError.unreadableProject
    }

    guard let entryString = metadata.file, !entryString.isEmpty else {
      throw WallpaperEngineImportError.missingEntry
    }

    let entryURL = try containedURL(
      entryString,
      inside: root
    )

    guard fileManager.fileExists(atPath: entryURL.path) else {
      throw WallpaperEngineImportError.missingEntry
    }

    let wallpaperType = try resolveType(
      declaredType: metadata.type,
      entryURL: entryURL
    )

    let packageRoot = destinationRoot
      .appendingPathComponent(id.uuidString, isDirectory: true)

    if fileManager.fileExists(atPath: packageRoot.path) {
      try fileManager.removeItem(at: packageRoot)
    }

    let assets = packageRoot
      .appendingPathComponent("assets", isDirectory: true)

    try fileManager.createDirectory(
      at: assets,
      withIntermediateDirectories: true
    )

    let entryName = "wallpaper." + entryURL.pathExtension.lowercased()
    let copiedEntry = assets.appendingPathComponent(entryName)
    try fileManager.copyItem(at: entryURL, to: copiedEntry)

    var thumbnailPath: String?

    if let preview = metadata.preview, !preview.isEmpty {
      let previewURL = try containedURL(preview, inside: root)

      if fileManager.fileExists(atPath: previewURL.path) {
        let ext = previewURL.pathExtension.lowercased()
        let name = ext.isEmpty ? "thumbnail" : "thumbnail.\(ext)"
        try fileManager.copyItem(
          at: previewURL,
          to: packageRoot.appendingPathComponent(name)
        )
        thumbnailPath = name
      }
    }

    let manifest = WallpaperManifest(
      formatVersion: 1,
      id: id.uuidString,
      name: metadata.title?.nilIfBlank
        ?? projectRoot.lastPathComponent,
      author: "Wallpaper Engine Import",
      type: wallpaperType,
      entry: "assets/\(entryName)",
      thumbnail: thumbnailPath,
      preview: nil,
      renderer: nil,
      properties: [],
      permissions: [],
      description: metadata.description?.nilIfBlank,
      tags: ["imported", "wallpaper-engine"],
      category: "Imported",
      version: "1.0",
      source: "Wallpaper Engine compatibility importer"
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    try encoder.encode(manifest).write(
      to: packageRoot.appendingPathComponent("wallpaper.json"),
      options: .atomic
    )

    return packageRoot
  }

  private func resolveType(
    declaredType: String?,
    entryURL: URL
  ) throws -> WallpaperType {
    let declared = declaredType?.lowercased() ?? ""
    let ext = entryURL.pathExtension.lowercased()

    if declared == "video" || ["mp4", "mov", "m4v", "webm"].contains(ext) {
      // LumaWall's AVFoundation renderer supports the common MP4/MOV/M4V
      // subset. WebM is rejected below if AVFoundation compatibility is not
      // guaranteed.
      if ext == "webm" {
        throw WallpaperEngineImportError.unsupportedType("video/webm")
      }
      return .video
    }

    if declared == "web" || ["html", "htm"].contains(ext) {
      return .web
    }

    if ["png", "jpg", "jpeg", "heic", "tiff", "webp"].contains(ext) {
      return .image
    }

    if declared == "scene" {
      throw WallpaperEngineImportError.unsupportedType("scene")
    }

    throw WallpaperEngineImportError.unsupportedType(
      declared.isEmpty ? ext : declared
    )
  }

  private func containedURL(
    _ relativePath: String,
    inside root: URL
  ) throws -> URL {
    guard
      !relativePath.hasPrefix("/"),
      !relativePath.contains("\0")
    else {
      throw WallpaperEngineImportError.unsafePath
    }

    let candidate = root
      .appendingPathComponent(relativePath)
      .standardizedFileURL
      .resolvingSymlinksInPath()

    let rootPath = root.path.hasSuffix("/")
      ? root.path
      : root.path + "/"

    guard
      candidate.path == root.path
      || candidate.path.hasPrefix(rootPath)
    else {
      throw WallpaperEngineImportError.unsafePath
    }

    return candidate
  }
}

private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
