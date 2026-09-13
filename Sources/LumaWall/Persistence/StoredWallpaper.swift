import Foundation
import SwiftData

@Model
final class StoredWallpaper {
  @Attribute(.unique) var id: UUID
  var name: String
  var author: String
  var typeRaw: String
  var entryPath: String
  var thumbnailPath: String?
  var manifestPath: String?
  var packageRootPath: String?
  var propertiesData: Data
  var requestedPermissionsData: Data
  var grantedPermissionsData: Data
  var importedAt: Date

  init(from wallpaper: Wallpaper, importedAt: Date = .now) throws {
    id = wallpaper.id
    name = wallpaper.name
    author = wallpaper.author
    typeRaw = wallpaper.type.rawValue
    entryPath = wallpaper.entryURL.path
    thumbnailPath = wallpaper.thumbnailURL?.path
    manifestPath = wallpaper.manifestURL?.path
    packageRootPath = wallpaper.packageRootURL?.path
    propertiesData = try JSONEncoder().encode(wallpaper.properties)
    requestedPermissionsData = try JSONEncoder().encode(wallpaper.requestedPermissions)
    grantedPermissionsData = try JSONEncoder().encode(wallpaper.grantedPermissions)
    self.importedAt = importedAt
  }

  func update(from wallpaper: Wallpaper) throws {
    name = wallpaper.name
    author = wallpaper.author
    typeRaw = wallpaper.type.rawValue
    entryPath = wallpaper.entryURL.path
    thumbnailPath = wallpaper.thumbnailURL?.path
    manifestPath = wallpaper.manifestURL?.path
    packageRootPath = wallpaper.packageRootURL?.path
    propertiesData = try JSONEncoder().encode(wallpaper.properties)
    requestedPermissionsData = try JSONEncoder().encode(wallpaper.requestedPermissions)
    grantedPermissionsData = try JSONEncoder().encode(wallpaper.grantedPermissions)
  }

  func makeWallpaper() throws -> Wallpaper {
    guard let type = WallpaperType(rawValue: typeRaw) else {
      throw WallpaperError.invalidManifest("Unknown wallpaper type: \(typeRaw)")
    }
    return Wallpaper(
      id: id,
      name: name,
      author: author,
      type: type,
      entryURL: URL(fileURLWithPath: entryPath),
      thumbnailURL: thumbnailPath.map(URL.init(fileURLWithPath:)),
      manifestURL: manifestPath.map(URL.init(fileURLWithPath:)),
      packageRootURL: packageRootPath.map(URL.init(fileURLWithPath:)),
      properties: try JSONDecoder().decode([WallpaperProperty].self, from: propertiesData),
      requestedPermissions: try JSONDecoder().decode(
        Set<WallpaperPermission>.self, from: requestedPermissionsData),
      grantedPermissions: try JSONDecoder().decode(
        Set<WallpaperPermission>.self, from: grantedPermissionsData)
    )
  }
}
