import AppKit
import Foundation

@MainActor
final class WallpaperLibrary {
  private let fileManager = FileManager.default
  private let packageService = WallpaperPackageService()
  private let previewGenerator = PreviewGenerator()

  var libraryRoot: URL {
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("LumaWall/Wallpapers", isDirectory: true)
  }

  private var indexURL: URL {
    libraryRoot.deletingLastPathComponent().appendingPathComponent("library.json")
  }

  init() {
    try? fileManager.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
  }

  func loadAll() -> [Wallpaper] {
    var result = loadRecords()
      .sorted { $0.importedAt < $1.importedAt }
      .compactMap { try? $0.makeWallpaper() }
      .filter { fileManager.fileExists(atPath: $0.entryURL.path) }

    if let bundled = bundledAurora(),
      !result.contains(where: { $0.name == bundled.name && $0.author == bundled.author })
    {
      result.insert(bundled, at: 0)
    }
    return result
  }

  func importWallpaper(from source: URL) throws -> Wallpaper {
    let id = UUID()
    let wallpaper: Wallpaper
    if isDirectory(source) || ["wall", "zip"].contains(source.pathExtension.lowercased()) {
      wallpaper = try packageService.importPackage(from: source, into: libraryRoot, id: id)
    } else {
      wallpaper = try importLooseFile(source, id: id)
    }
    try persist(wallpaper)
    return wallpaper
  }

  func exportWallpaper(_ wallpaper: Wallpaper, to destination: URL) throws {
    try packageService.exportPackage(wallpaper, to: destination)
  }

  func grant(_ permissions: Set<WallpaperPermission>, to wallpaper: Wallpaper) throws -> Wallpaper {
    var updated = wallpaper
    updated.grantedPermissions.formUnion(permissions.intersection(updated.requestedPermissions))
    try persist(updated)
    return updated
  }

  func revoke(_ permissions: Set<WallpaperPermission>, from wallpaper: Wallpaper) throws
    -> Wallpaper
  {
    var updated = wallpaper
    updated.grantedPermissions.subtract(permissions)
    try persist(updated)
    return updated
  }

  func generatePreviewIfNeeded(for wallpaper: Wallpaper) async -> Wallpaper {
    guard
      wallpaper.thumbnailURL == nil
        || !(wallpaper.thumbnailURL.map { fileManager.fileExists(atPath: $0.path) } ?? false)
    else { return wallpaper }

    let directory = libraryRoot.appendingPathComponent(wallpaper.id.uuidString, isDirectory: true)
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let output = directory.appendingPathComponent("generated-preview.jpg")

    do {
      try await previewGenerator.generate(for: wallpaper, destination: output)
      var updated = wallpaper
      updated.thumbnailURL = output
      try persist(updated)
      return updated
    } catch {
      return wallpaper
    }
  }

  func persist(_ wallpaper: Wallpaper) throws {
    guard
      wallpaper.packageRootURL?.path.hasPrefix(libraryRoot.path) == true
        || wallpaper.entryURL.path.hasPrefix(libraryRoot.path)
    else {
      return
    }

    var records = loadRecords()
    if let index = records.firstIndex(where: { $0.id == wallpaper.id }) {
      try records[index].update(from: wallpaper)
    } else {
      records.append(try StoredWallpaper(from: wallpaper))
    }
    try saveRecords(records)
  }

  private func loadRecords() -> [StoredWallpaper] {
    guard fileManager.fileExists(atPath: indexURL.path),
      let data = try? Data(contentsOf: indexURL),
      let records = try? JSONDecoder().decode([StoredWallpaper].self, from: data)
    else {
      return []
    }
    return records
  }

  private func saveRecords(_ records: [StoredWallpaper]) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    // Keep decoding backward-compatible with the default Date encoding used before this point.
    // We therefore write with the default strategy for now.
    let stableEncoder = JSONEncoder()
    stableEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try stableEncoder.encode(records)
    try data.write(to: indexURL, options: .atomic)
  }

  private func importLooseFile(_ source: URL, id: UUID) throws -> Wallpaper {
    let type = try wallpaperType(for: source)
    let ownedRoot = libraryRoot.appendingPathComponent(id.uuidString, isDirectory: true)
    let assets = ownedRoot.appendingPathComponent("assets", isDirectory: true)
    try fileManager.createDirectory(at: assets, withIntermediateDirectories: true)
    let target = assets.appendingPathComponent(source.lastPathComponent)
    try fileManager.copyItem(at: source, to: target)

    let manifest = WallpaperManifest(
      formatVersion: 1,
      id: id.uuidString,
      name: source.deletingPathExtension().lastPathComponent,
      author: "Local",
      type: type,
      entry: "assets/\(target.lastPathComponent)",
      thumbnail: nil,
      preview: nil,
      renderer: nil,
      properties: [],
      permissions: type == .web ? [.mouse] : []
    )
    let manifestURL = ownedRoot.appendingPathComponent("wallpaper.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: manifestURL)

    return Wallpaper(
      id: id,
      name: manifest.name,
      author: manifest.author,
      type: type,
      entryURL: target,
      manifestURL: manifestURL,
      packageRootURL: ownedRoot,
      properties: [],
      requestedPermissions: manifest.permissions ?? [],
      grantedPermissions: manifest.permissions?.intersection([.mouse]) ?? []
    )
  }

  private func isDirectory(_ url: URL) -> Bool {
    var flag: ObjCBool = false
    return fileManager.fileExists(atPath: url.path, isDirectory: &flag) && flag.boolValue
  }

  private func wallpaperType(for url: URL) throws -> WallpaperType {
    switch url.pathExtension.lowercased() {
    case "png", "jpg", "jpeg", "heic", "tiff", "webp": return .image
    case "mp4", "mov", "m4v": return .video
    case "html", "htm": return .web
    case "metal": return .metal
    default: throw WallpaperError.unsupportedFileType(url.pathExtension.lowercased())
    }
  }

  private func bundledAurora() -> Wallpaper? {
    guard
      let shaderURL = Bundle.module.url(
        forResource: "Aurora", withExtension: "metal", subdirectory: "Shaders")
    else { return nil }

    return Wallpaper(
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
      name: "Aurora",
      author: "LumaWall",
      type: .metal,
      entryURL: shaderURL,
      properties: [
        WallpaperProperty(
          id: "speed", name: "Speed", kind: .slider, defaultValue: .number(1.0),
          minValue: 0.1, maxValue: 3.0, step: 0.05, options: nil),
        WallpaperProperty(
          id: "intensity", name: "Intensity", kind: .slider, defaultValue: .number(1.0),
          minValue: 0.2, maxValue: 2.0, step: 0.05, options: nil),
        WallpaperProperty(
          id: "accent", name: "Accent", kind: .color, defaultValue: .string("#26D9A6"),
          minValue: nil, maxValue: nil, step: nil, options: nil),
      ],
      requestedPermissions: [.mouse, .systemAudio],
      grantedPermissions: [.mouse, .systemAudio]
    )
  }
}
