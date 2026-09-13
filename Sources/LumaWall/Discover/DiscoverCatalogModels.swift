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
