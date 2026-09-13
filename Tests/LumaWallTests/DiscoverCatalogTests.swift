import Foundation
import Testing
@testable import LumaWall

@Test
func discoverCatalogDecodesCuratedListing() throws {
  let id = UUID()
  let json = """
  {
    "formatVersion": 1,
    "generatedAt": "2026-09-13T18:30:00Z",
    "items": [
      {
        "id": "\(id.uuidString)",
        "name": "Midnight Grid",
        "author": "LumaWall Studio",
        "description": "A dark geometric wallpaper.",
        "category": "Minimal",
        "tags": ["dark", "grid"],
        "type": "image",
        "previewURL": "https://example.com/preview.jpg",
        "packageURL": "https://example.com/midnight.wall",
        "sha256": "0123456789abcdef",
        "featured": true,
        "version": "1.0"
      }
    ]
  }
  """

  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  let catalog = try decoder.decode(
    DiscoverCatalog.self,
    from: Data(json.utf8)
  )

  #expect(catalog.formatVersion == 1)
  #expect(catalog.items.count == 1)
  #expect(catalog.items[0].id == id)
  #expect(catalog.items[0].featured)
  #expect(catalog.items[0].type == .image)
  #expect(catalog.items[0].category == "Minimal")
}

@Test
func discoverSearchTextIncludesMetadata() {
  let item = DiscoverWallpaperListing(
    id: UUID(),
    name: "Midnight Grid",
    author: "LumaWall Studio",
    description: "A calm geometric design",
    category: "Minimal",
    tags: ["dark", "canva"],
    type: .image,
    previewURL: nil,
    packageURL: URL(string: "https://example.com/a.wall")!,
    sha256: nil
  )

  #expect(item.searchableText.contains("midnight"))
  #expect(item.searchableText.contains("lumawall studio"))
  #expect(item.searchableText.contains("minimal"))
  #expect(item.searchableText.contains("canva"))
  #expect(item.searchableText.contains("geometric"))
}

@Test @MainActor
func discoverLocalCatalogLoadsWithoutNetwork() throws {
  let id = UUID()
  let json = """
  {
    "formatVersion": 1,
    "items": [
      {
        "id": "\(id.uuidString)",
        "name": "Local Test",
        "author": "Creator",
        "category": "Test",
        "tags": [],
        "type": "video",
        "packageURL": "https://example.com/local.wall"
      }
    ]
  }
  """

  let file = FileManager.default.temporaryDirectory
    .appendingPathComponent("discover-\(UUID().uuidString).json")
  defer { try? FileManager.default.removeItem(at: file) }

  try Data(json.utf8).write(to: file)

  let service = DiscoverCatalogService()
  try service.loadLocalCatalog(from: file)

  #expect(service.items.count == 1)
  #expect(service.items[0].id == id)
  #expect(service.items[0].type == .video)
}
