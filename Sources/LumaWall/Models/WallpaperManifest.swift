import Foundation

struct WallpaperManifest: Codable, Sendable {
  var formatVersion: Int
  var id: String?
  var name: String
  var author: String
  var type: WallpaperType
  var entry: String
  var thumbnail: String?
  var preview: String?
  var renderer: RendererSettings?
  var properties: [WallpaperProperty]?
  var permissions: Set<WallpaperPermission>?

  struct RendererSettings: Codable, Sendable {
    var fps: Int?
    var scale: Double?
    var audio: Bool?
    var interactiveMouse: Bool?
  }
}
