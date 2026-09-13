import Foundation
import Testing
@testable import LumaWall

private func makeWallpaperEngineTestRoot() throws -> URL {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent(
      "LumaWall-WE-\(UUID().uuidString)",
      isDirectory: true
    )
  try FileManager.default.createDirectory(
    at: root,
    withIntermediateDirectories: true
  )
  return root
}

@Test
func wallpaperEngineVideoProjectConvertsToWallPackage() throws {
  let temp = try makeWallpaperEngineTestRoot()
  defer { try? FileManager.default.removeItem(at: temp) }

  let project = temp.appendingPathComponent("project", isDirectory: true)
  let output = temp.appendingPathComponent("output", isDirectory: true)
  try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

  try Data([0, 0, 0, 24]).write(
    to: project.appendingPathComponent("wallpaper.mp4")
  )
  try Data([1, 2, 3]).write(
    to: project.appendingPathComponent("preview.jpg")
  )

  let json = """
  {
    "title": "Imported Motion",
    "description": "Simple video project",
    "type": "video",
    "file": "wallpaper.mp4",
    "preview": "preview.jpg"
  }
  """
  try Data(json.utf8).write(
    to: project.appendingPathComponent("project.json")
  )

  let package = try WallpaperEngineImporter().importProject(
    at: project,
    destinationRoot: output
  )

  let manifest = try JSONDecoder().decode(
    WallpaperManifest.self,
    from: Data(contentsOf: package.appendingPathComponent("wallpaper.json"))
  )

  #expect(manifest.name == "Imported Motion")
  #expect(manifest.type == .video)
  #expect(manifest.entry == "assets/wallpaper.mp4")
  #expect(manifest.thumbnail == "thumbnail.jpg")
  #expect(manifest.category == "Imported")
  #expect(manifest.tags?.contains("wallpaper-engine") == true)
}

@Test
func wallpaperEngineWebProjectConvertsToWebWallpaper() throws {
  let temp = try makeWallpaperEngineTestRoot()
  defer { try? FileManager.default.removeItem(at: temp) }

  let project = temp.appendingPathComponent("project", isDirectory: true)
  let output = temp.appendingPathComponent("output", isDirectory: true)
  try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

  try Data("<html></html>".utf8).write(
    to: project.appendingPathComponent("index.html")
  )

  let json = """
  {
    "title": "Imported Web",
    "type": "web",
    "file": "index.html"
  }
  """
  try Data(json.utf8).write(
    to: project.appendingPathComponent("project.json")
  )

  let package = try WallpaperEngineImporter().importProject(
    at: project,
    destinationRoot: output
  )

  let manifest = try JSONDecoder().decode(
    WallpaperManifest.self,
    from: Data(contentsOf: package.appendingPathComponent("wallpaper.json"))
  )

  #expect(manifest.type == .web)
  #expect(manifest.entry == "assets/wallpaper.html")
}

@Test
func wallpaperEngineSceneProjectIsExplicitlyRejected() throws {
  let temp = try makeWallpaperEngineTestRoot()
  defer { try? FileManager.default.removeItem(at: temp) }

  let project = temp.appendingPathComponent("project", isDirectory: true)
  let output = temp.appendingPathComponent("output", isDirectory: true)
  try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

  try Data("{}".utf8).write(
    to: project.appendingPathComponent("scene.json")
  )

  let json = """
  {
    "title": "Unsupported Scene",
    "type": "scene",
    "file": "scene.json"
  }
  """
  try Data(json.utf8).write(
    to: project.appendingPathComponent("project.json")
  )

  do {
    _ = try WallpaperEngineImporter().importProject(
      at: project,
      destinationRoot: output
    )
    Issue.record("Expected scene project to be rejected")
  } catch let error as WallpaperEngineImportError {
    switch error {
    case .unsupportedType(let type):
      #expect(type == "scene")
    default:
      Issue.record("Unexpected error: \(error)")
    }
  }
}

@Test
func wallpaperEngineImporterBlocksPathTraversal() throws {
  let temp = try makeWallpaperEngineTestRoot()
  defer { try? FileManager.default.removeItem(at: temp) }

  let project = temp.appendingPathComponent("project", isDirectory: true)
  let output = temp.appendingPathComponent("output", isDirectory: true)
  try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

  try Data([1]).write(to: temp.appendingPathComponent("outside.mp4"))

  let json = """
  {
    "title": "Unsafe",
    "type": "video",
    "file": "../outside.mp4"
  }
  """
  try Data(json.utf8).write(
    to: project.appendingPathComponent("project.json")
  )

  do {
    _ = try WallpaperEngineImporter().importProject(
      at: project,
      destinationRoot: output
    )
    Issue.record("Expected traversal to be rejected")
  } catch let error as WallpaperEngineImportError {
    switch error {
    case .unsafePath:
      break
    default:
      Issue.record("Unexpected error: \(error)")
    }
  }
}
