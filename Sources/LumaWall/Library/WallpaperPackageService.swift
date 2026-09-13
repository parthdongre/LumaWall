import Foundation

struct WallpaperPackageService {
  private let fileManager = FileManager.default

  func importPackage(from source: URL, into destination: URL, id: UUID) throws -> Wallpaper {
    let packageRoot: URL
    if isDirectory(source) {
      packageRoot = source
    } else {
      try validateArchivePaths(source)
      let temp = fileManager.temporaryDirectory.appendingPathComponent(
        "LumaWallImport-\(UUID().uuidString)", isDirectory: true)
      try fileManager.createDirectory(at: temp, withIntermediateDirectories: true)
      try runProcess("/usr/bin/ditto", ["-x", "-k", source.path, temp.path])
      packageRoot = try locatePackageRoot(in: temp)
    }

    let ownedRoot = destination.appendingPathComponent(id.uuidString, isDirectory: true)
    if fileManager.fileExists(atPath: ownedRoot.path) {
      try fileManager.removeItem(at: ownedRoot)
    }
    try fileManager.createDirectory(
      at: ownedRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fileManager.copyItem(at: packageRoot, to: ownedRoot)
    return try loadPackage(at: ownedRoot, id: id)
  }

  func loadPackage(at root: URL, id: UUID) throws -> Wallpaper {
    let manifestURL = root.appendingPathComponent("wallpaper.json")
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      throw WallpaperError.invalidManifest("wallpaper.json is missing")
    }
    let manifest = try JSONDecoder().decode(
      WallpaperManifest.self, from: Data(contentsOf: manifestURL))
    guard manifest.formatVersion == 1 else {
      throw WallpaperError.invalidManifest("Unsupported formatVersion \(manifest.formatVersion)")
    }

    let entryURL = try safeChild(manifest.entry, of: root)
    guard fileManager.fileExists(atPath: entryURL.path) else {
      throw WallpaperError.invalidManifest("Entry asset does not exist: \(manifest.entry)")
    }
    let thumbnailURL = try manifest.thumbnail.map { try safeChild($0, of: root) }
    let requested = manifest.permissions ?? []
    let automaticallyGranted = requested.intersection([.mouse])

    return Wallpaper(
      id: id,
      name: manifest.name,
      author: manifest.author,
      type: manifest.type,
      entryURL: entryURL,
      thumbnailURL: thumbnailURL,
      manifestURL: manifestURL,
      packageRootURL: root,
      properties: manifest.properties ?? [],
      requestedPermissions: requested,
      grantedPermissions: automaticallyGranted
    )
  }

  func exportPackage(_ wallpaper: Wallpaper, to destination: URL) throws {
    let temp = fileManager.temporaryDirectory.appendingPathComponent(
      "LumaWallExport-\(UUID().uuidString)", isDirectory: true)
    defer { try? fileManager.removeItem(at: temp) }
    try fileManager.createDirectory(at: temp, withIntermediateDirectories: true)

    if let packageRoot = wallpaper.packageRootURL,
      fileManager.fileExists(atPath: packageRoot.appendingPathComponent("wallpaper.json").path)
    {
      let contents = try fileManager.contentsOfDirectory(
        at: packageRoot, includingPropertiesForKeys: nil)
      for item in contents {
        try fileManager.copyItem(at: item, to: temp.appendingPathComponent(item.lastPathComponent))
      }
    } else {
      let assets = temp.appendingPathComponent("assets", isDirectory: true)
      try fileManager.createDirectory(at: assets, withIntermediateDirectories: true)
      let assetName = wallpaper.entryURL.lastPathComponent
      try fileManager.copyItem(at: wallpaper.entryURL, to: assets.appendingPathComponent(assetName))

      var thumbnailName: String?
      if let thumb = wallpaper.thumbnailURL, fileManager.fileExists(atPath: thumb.path) {
        thumbnailName = "thumbnail.\(thumb.pathExtension.isEmpty ? "png" : thumb.pathExtension)"
        try fileManager.copyItem(at: thumb, to: temp.appendingPathComponent(thumbnailName!))
      }

      let manifest = WallpaperManifest(
        formatVersion: 1,
        id: wallpaper.id.uuidString,
        name: wallpaper.name,
        author: wallpaper.author,
        type: wallpaper.type,
        entry: "assets/\(assetName)",
        thumbnail: thumbnailName,
        preview: nil,
        renderer: nil,
        properties: wallpaper.properties,
        permissions: wallpaper.requestedPermissions
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(manifest).write(to: temp.appendingPathComponent("wallpaper.json"))
    }

    if fileManager.fileExists(atPath: destination.path) {
      try fileManager.removeItem(at: destination)
    }
    try runProcess("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", temp.path, destination.path])
  }

  private func isDirectory(_ url: URL) -> Bool {
    var flag: ObjCBool = false
    return fileManager.fileExists(atPath: url.path, isDirectory: &flag) && flag.boolValue
  }

  private func safeChild(_ relativePath: String, of root: URL) throws -> URL {
    let child = root.appendingPathComponent(relativePath).standardizedFileURL
    let standardizedRoot =
      root.standardizedFileURL.path.hasSuffix("/")
      ? root.standardizedFileURL.path : root.standardizedFileURL.path + "/"
    guard child.path.hasPrefix(standardizedRoot) else {
      throw WallpaperError.unsafeArchivePath(relativePath)
    }
    return child
  }

  private func locatePackageRoot(in extractedRoot: URL) throws -> URL {
    let direct = extractedRoot.appendingPathComponent("wallpaper.json")
    if fileManager.fileExists(atPath: direct.path) { return extractedRoot }
    let children = try fileManager.contentsOfDirectory(
      at: extractedRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
    )
    for child in children where child.hasDirectoryPath {
      if fileManager.fileExists(atPath: child.appendingPathComponent("wallpaper.json").path) {
        return child
      }
    }
    throw WallpaperError.invalidManifest("Could not find wallpaper.json in archive")
  }

  private func validateArchivePaths(_ archive: URL) throws {
    let output = try runProcess("/usr/bin/unzip", ["-Z1", archive.path], captureOutput: true)
    for rawLine in output.split(separator: "\n") {
      let path = String(rawLine)
      let components = NSString(string: path).pathComponents
      if path.hasPrefix("/") || components.contains("..") {
        throw WallpaperError.unsafeArchivePath(path)
      }
    }
  }

  @discardableResult
  private func runProcess(_ executable: String, _ arguments: [String], captureOutput: Bool = false)
    throws -> String
  {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    if captureOutput { process.standardOutput = pipe }
    let errorPipe = Pipe()
    process.standardError = errorPipe
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
      throw WallpaperError.packageOperationFailed(
        String(data: data, encoding: .utf8) ?? "exit \(process.terminationStatus)")
    }
    guard captureOutput else { return "" }
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  }
}
