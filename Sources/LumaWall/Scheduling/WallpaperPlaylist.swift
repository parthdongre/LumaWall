import Foundation

enum ScheduleTrigger: Codable, Hashable {
  case daily(hour: Int, minute: Int)
  case date(Date)
  case sunrise(offsetMinutes: Int)
  case sunset(offsetMinutes: Int)
}

struct WallpaperPlaylist: Identifiable, Codable, Hashable {
  var id = UUID()
  var name: String
  var wallpaperIDs: [UUID]
  var intervalSeconds: TimeInterval
  var shuffle: Bool
}
struct WallpaperSchedule: Identifiable, Codable, Hashable {
  var id = UUID()
  var wallpaperID: UUID
  var trigger: ScheduleTrigger
  var enabled = true
}
struct SolarLocation: Codable, Hashable {
  var latitude: Double
  var longitude: Double
}
