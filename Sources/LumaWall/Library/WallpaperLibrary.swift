import AppKit
import Foundation

@MainActor
final class WallpaperLibrary {
  private let fileManager = FileManager.default
  private let packageService = WallpaperPackageService()
  private let previewGenerator = PreviewGenerator()
  private let creatorBuilder = CreatorPackageBuilder()

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

    let bundled = bundledWallpapers()
    let existingIDs = Set(result.map(\.id))
    result.insert(contentsOf: bundled.filter { !existingIDs.contains($0.id) }, at: 0)
    return result
  }

  func inspectCreatorAsset(_ source: URL) throws -> CreatorAssetSummary {
    try creatorBuilder.summary(for: source)
  }

  func createWallpaper(from draft: CreatorWallpaperDraft) async throws -> Wallpaper {
    let id = UUID()
    let root = libraryRoot

    let packageRoot = try await Task.detached(priority: .userInitiated) {
      let builder = CreatorPackageBuilder()

      do {
        return try builder.build(
          draft: draft,
          id: id,
          at: root
        )
      } catch {
        let partial = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: partial)
        throw error
      }
    }.value

    let wallpaper = try packageService.loadPackage(at: packageRoot, id: id)
    try persist(wallpaper)
    return wallpaper
  }

  func importWallpaperEngineProject(
    from source: URL
  ) async throws -> Wallpaper {
    let id = UUID()
    let root = libraryRoot

    let packageRoot = try await Task.detached(priority: .userInitiated) {
      let importer = WallpaperEngineImporter()

      do {
        return try importer.importProject(
          at: source,
          destinationRoot: root,
          id: id
        )
      } catch {
        let partial = root.appendingPathComponent(
          id.uuidString,
          isDirectory: true
        )
        try? FileManager.default.removeItem(at: partial)
        throw error
      }
    }.value

    let wallpaper = try packageService.loadPackage(
      at: packageRoot,
      id: id
    )
    try persist(wallpaper)
    return wallpaper
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

  private func bundledWallpapers() -> [Wallpaper] {
    var wallpapers: [Wallpaper] = []
    if let aurora = bundledAurora() {
      wallpapers.append(aurora)
    }

    for root in builtInWallpaperRoots() {
      guard
        let packages = try? fileManager.contentsOfDirectory(
          at: root,
          includingPropertiesForKeys: [.isDirectoryKey],
          options: [.skipsHiddenFiles]
        )
      else { continue }

      for packageRoot in packages.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        guard packageRoot.hasDirectoryPath else { continue }
        let manifestURL = packageRoot.appendingPathComponent("wallpaper.json")
        guard
          let data = try? Data(contentsOf: manifestURL),
          let manifest = try? JSONDecoder().decode(WallpaperManifest.self, from: data)
        else { continue }

        let id =
          manifest.id.flatMap(UUID.init(uuidString:))
          ?? UUID()
        if let wallpaper = try? packageService.loadPackage(at: packageRoot, id: id) {
          wallpapers.append(wallpaper)
        }
      }
    }

    var seen = Set<UUID>()
    return wallpapers.filter { seen.insert($0.id).inserted }
  }

  private func resourceRoots() -> [URL] {
    var roots: [URL] = []

    if Bundle.main.bundlePath.hasSuffix(".app"), let resources = Bundle.main.resourceURL {
      let nestedBundleURL = resources.appendingPathComponent(
        "LumaWall_LumaWall.bundle",
        isDirectory: true
      )
      if let nestedBundle = Bundle(url: nestedBundleURL),
        let nestedResources = nestedBundle.resourceURL
      {
        roots.append(nestedResources)
      }
      roots.append(resources)
    } else if let swiftPMResources = Bundle.module.resourceURL {
      roots.append(swiftPMResources)
    }

    var seen = Set<String>()
    return roots.filter { seen.insert($0.standardizedFileURL.path).inserted }
  }

  private func builtInWallpaperRoots() -> [URL] {
    let candidates = resourceRoots().flatMap { root in
      [
        root.appendingPathComponent("BuiltInWallpapers", isDirectory: true),
        root.appendingPathComponent("Resources", isDirectory: true)
          .appendingPathComponent("BuiltInWallpapers", isDirectory: true),
      ]
    }

    return candidates.filter {
      var isDirectory: ObjCBool = false
      return fileManager.fileExists(atPath: $0.path, isDirectory: &isDirectory)
        && isDirectory.boolValue
    }
  }

  private func bundledAurora() -> Wallpaper? {
    let candidates = resourceRoots().flatMap { root in
      [
        root.appendingPathComponent("Shaders/Aurora.metal"),
        root.appendingPathComponent("Resources/Shaders/Aurora.metal"),
      ]
    }

    guard
      let shaderURL = candidates.first(where: {
        fileManager.fileExists(atPath: $0.path)
      })
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
