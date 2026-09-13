import Foundation

struct Wallpaper: Identifiable, Codable, Hashable {
  var id: UUID
  var name: String
  var author: String
  var type: WallpaperType
  var entryURL: URL
  var thumbnailURL: URL?
  var manifestURL: URL?
  var packageRootURL: URL?
  var properties: [WallpaperProperty]
  var requestedPermissions: Set<WallpaperPermission>
  var grantedPermissions: Set<WallpaperPermission>

  init(
    id: UUID = UUID(),
    name: String,
    author: String,
    type: WallpaperType,
    entryURL: URL,
    thumbnailURL: URL? = nil,
    manifestURL: URL? = nil,
    packageRootURL: URL? = nil,
    properties: [WallpaperProperty] = [],
    requestedPermissions: Set<WallpaperPermission> = [],
    grantedPermissions: Set<WallpaperPermission> = []
  ) {
    self.id = id
    self.name = name
    self.author = author
    self.type = type
    self.entryURL = entryURL
    self.thumbnailURL = thumbnailURL
    self.manifestURL = manifestURL
    self.packageRootURL = packageRootURL
    self.properties = properties
    self.requestedPermissions = requestedPermissions
    self.grantedPermissions = grantedPermissions
  }
}

enum WallpaperType: String, Codable, CaseIterable, Sendable {
  case image
  case video
  case web
  case metal
}

enum WallpaperPermission: String, Codable, CaseIterable, Hashable, Sendable {
  case mouse
  case network
  case microphone
  case systemAudio

  var displayName: String {
    switch self {
    case .mouse: return "Mouse position"
    case .network: return "Network access"
    case .microphone: return "Microphone"
    case .systemAudio: return "System audio"
    }
  }

  var isSensitive: Bool { self != .mouse }
}

enum WallpaperPropertyValue: Codable, Hashable, Sendable {
  case number(Double)
  case bool(Bool)
  case string(String)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let value = try? container.decode(Bool.self) {
      self = .bool(value)
      return
    }
    if let value = try? container.decode(Double.self) {
      self = .number(value)
      return
    }
    if let value = try? container.decode(String.self) {
      self = .string(value)
      return
    }
    throw DecodingError.typeMismatch(
      WallpaperPropertyValue.self,
      .init(codingPath: decoder.codingPath, debugDescription: "Expected number, boolean, or string")
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .number(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    }
  }

  var numberValue: Double? {
    if case .number(let value) = self { return value }
    return nil
  }

  var boolValue: Bool? {
    if case .bool(let value) = self { return value }
    return nil
  }

  var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }
}

struct WallpaperProperty: Codable, Hashable, Identifiable, Sendable {
  var id: String
  var name: String
  var kind: PropertyKind
  var defaultValue: WallpaperPropertyValue
  var minValue: Double?
  var maxValue: Double?
  var step: Double?
  var options: [String]?

  enum PropertyKind: String, Codable, Sendable {
    case slider
    case toggle
    case color
    case dropdown
  }
}
