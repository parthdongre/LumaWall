import Foundation

struct DiscoverCatalog: Codable, Hashable, Sendable {
  var formatVersion: Int = 1
  var generatedAt: Date?
  var items: [DiscoverWallpaperListing]
}

struct DiscoverWallpaperListing: Identifiable, Codable, Hashable, Sendable {
  var id: UUID
  var name: String
  var author: String
  var description: String?
  var category: String
  var tags: [String]
  var type: WallpaperType
  var previewURL: URL?
  var packageURL: URL
  var sha256: String?
  var featured: Bool = false
  var version: String = "1.0"

  var searchableText: String {
    (
      [name, author, category]
      + tags
      + [description ?? ""]
    )
    .joined(separator: " ")
    .lowercased()
  }
}

enum DiscoverCatalogError: LocalizedError {
  case missingEndpoint
  case insecureURL
  case invalidCatalog
  case checksumMismatch
  case packageTooLarge

  var errorDescription: String? {
    switch self {
    case .missingEndpoint:
      return "Add a LumaWall catalog URL first."
    case .insecureURL:
      return "Discover requires HTTPS for remote catalogs and wallpaper downloads."
    case .invalidCatalog:
      return "The Discover catalog could not be decoded."
    case .checksumMismatch:
      return "The downloaded wallpaper did not match its catalog checksum."
    case .packageTooLarge:
      return "The wallpaper package is larger than LumaWall's 1 GB Discover limit."
    }
  }
}


extension DiscoverWallpaperListing {
  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case author
    case description
    case category
    case tags
    case type
    case previewURL
    case packageURL
    case sha256
    case featured
    case version
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    author = try container.decode(String.self, forKey: .author)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Featured"
    tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    type = try container.decode(WallpaperType.self, forKey: .type)
    previewURL = try container.decodeIfPresent(URL.self, forKey: .previewURL)
    packageURL = try container.decode(URL.self, forKey: .packageURL)
    sha256 = try container.decodeIfPresent(String.self, forKey: .sha256)
    featured = try container.decodeIfPresent(Bool.self, forKey: .featured) ?? false
    version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
  }
}
