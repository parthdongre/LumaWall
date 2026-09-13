import Foundation
import Testing
@testable import LumaWall

private func makeTemporaryDirectory() throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("LumaWallCreatorTests-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

@Test
func creatorBuildsImageWallpaperPackageWithMetadata() throws {
  let temp = try makeTemporaryDirectory()
  defer { try? FileManager.default.removeItem(at: temp) }

  let source = temp.appendingPathComponent("canva-art.png")
  try Data([0x89, 0x50, 0x4E, 0x47]).write(to: source)

  var draft = CreatorWallpaperDraft()
  draft.sourceURL = source
  draft.name = "Midnight Geometry"
  draft.author = "Parth"
  draft.description = "A dark geometric wallpaper."
  draft.category = "Minimal"
  draft.tagsText = "dark, geometric,  minimal "

  let id = UUID()
  let packageRoot = try CreatorPackageBuilder().build(
    draft: draft,
    id: id,
    at: temp.appendingPathComponent("output", isDirectory: true)
  )

  let manifestURL = packageRoot.appendingPathComponent("wallpaper.json")
  let manifest = try JSONDecoder().decode(
    WallpaperManifest.self,
    from: Data(contentsOf: manifestURL)
  )

  #expect(manifest.id == id.uuidString)
  #expect(manifest.name == "Midnight Geometry")
  #expect(manifest.author == "Parth")
  #expect(manifest.type == .image)
  #expect(manifest.entry == "assets/wallpaper.png")
  #expect(manifest.thumbnail == "assets/wallpaper.png")
  #expect(manifest.description == "A dark geometric wallpaper.")
  #expect(manifest.category == "Minimal")
  #expect(manifest.tags == ["dark", "geometric", "minimal"])
  #expect(manifest.version == "1.0")
  #expect(manifest.source == "LumaWall Creator Studio")

  #expect(
    FileManager.default.fileExists(
      atPath: packageRoot
        .appendingPathComponent("assets/wallpaper.png")
        .path
    )
  )
}

@Test
func creatorBuildsVideoWallpaperWithoutFakeThumbnail() throws {
  let temp = try makeTemporaryDirectory()
  defer { try? FileManager.default.removeItem(at: temp) }

  let source = temp.appendingPathComponent("motion.mp4")
  try Data([0, 0, 0, 24, 102, 116, 121, 112]).write(to: source)

  var draft = CreatorWallpaperDraft()
  draft.sourceURL = source
  draft.name = "Motion"
  draft.author = "Creator"

  let packageRoot = try CreatorPackageBuilder().build(
    draft: draft,
    id: UUID(),
    at: temp.appendingPathComponent("output", isDirectory: true)
  )

  let manifest = try JSONDecoder().decode(
    WallpaperManifest.self,
    from: Data(contentsOf: packageRoot.appendingPathComponent("wallpaper.json"))
  )

  #expect(manifest.type == .video)
  #expect(manifest.entry == "assets/wallpaper.mp4")
  #expect(manifest.thumbnail == nil)
}

@Test
func creatorCopiesCustomThumbnail() throws {
  let temp = try makeTemporaryDirectory()
  defer { try? FileManager.default.removeItem(at: temp) }

  let source = temp.appendingPathComponent("motion.mov")
  let thumbnail = temp.appendingPathComponent("cover.jpg")
  try Data([1, 2, 3]).write(to: source)
  try Data([4, 5, 6]).write(to: thumbnail)

  var draft = CreatorWallpaperDraft()
  draft.sourceURL = source
  draft.thumbnailURL = thumbnail
  draft.name = "Motion"
  draft.author = "Creator"

  let packageRoot = try CreatorPackageBuilder().build(
    draft: draft,
    id: UUID(),
    at: temp.appendingPathComponent("output", isDirectory: true)
  )

  let manifest = try JSONDecoder().decode(
    WallpaperManifest.self,
    from: Data(contentsOf: packageRoot.appendingPathComponent("wallpaper.json"))
  )

  #expect(manifest.thumbnail == "thumbnail.jpg")
  #expect(
    FileManager.default.fileExists(
      atPath: packageRoot.appendingPathComponent("thumbnail.jpg").path
    )
  )
}

@Test
func creatorRejectsUnsupportedArtwork() throws {
  let temp = try makeTemporaryDirectory()
  defer { try? FileManager.default.removeItem(at: temp) }

  let source = temp.appendingPathComponent("design.pdf")
  try Data("pdf".utf8).write(to: source)

  do {
    _ = try CreatorPackageBuilder().summary(for: source)
    Issue.record("Expected unsupported source error")
  } catch let error as CreatorPackageError {
    switch error {
    case .unsupportedSource(let ext):
      #expect(ext == "pdf")
    default:
      Issue.record("Unexpected creator error: \(error)")
    }
  }
}

@Test
func creatorRequiresNameAndAuthor() throws {
  let temp = try makeTemporaryDirectory()
  defer { try? FileManager.default.removeItem(at: temp) }

  let source = temp.appendingPathComponent("art.png")
  try Data([1]).write(to: source)

  var draft = CreatorWallpaperDraft()
  draft.sourceURL = source

  #expect(!draft.isReadyToCreate)

  draft.name = "Artwork"
  #expect(!draft.isReadyToCreate)

  draft.author = "Creator"
  #expect(draft.isReadyToCreate)
}

@Test
func creatorClockPresetsProduceEnabledOverlays() {
  #expect(CreatorClockPreset.none.overlaySettings == nil)
  #expect(CreatorClockPreset.glass.overlaySettings?.enabled == true)
  #expect(CreatorClockPreset.minimal.overlaySettings?.enabled == true)
  #expect(CreatorClockPreset.bold.overlaySettings?.enabled == true)
}
