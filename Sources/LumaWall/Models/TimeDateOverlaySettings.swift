import Foundation

enum ClockHourFormat: String, Codable, CaseIterable, Identifiable, Sendable {
  case system
  case twelveHour
  case twentyFourHour

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .system: return "System"
    case .twelveHour: return "12-hour"
    case .twentyFourHour: return "24-hour"
    }
  }
}

enum ClockDateStyle: String, Codable, CaseIterable, Identifiable, Sendable {
  case none
  case short
  case medium
  case long
  case full

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .none: return "None"
    case .short: return "Short"
    case .medium: return "Medium"
    case .long: return "Long"
    case .full: return "Full"
    }
  }
}

enum ClockOverlayPosition: String, Codable, CaseIterable, Identifiable, Sendable {
  case topLeft
  case topCenter
  case topRight
  case centerLeft
  case center
  case centerRight
  case bottomLeft
  case bottomCenter
  case bottomRight

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .topLeft: return "Top Left"
    case .topCenter: return "Top Center"
    case .topRight: return "Top Right"
    case .centerLeft: return "Center Left"
    case .center: return "Center"
    case .centerRight: return "Center Right"
    case .bottomLeft: return "Bottom Left"
    case .bottomCenter: return "Bottom Center"
    case .bottomRight: return "Bottom Right"
    }
  }
}

enum ClockFontWeight: String, Codable, CaseIterable, Identifiable, Sendable {
  case ultraLight
  case light
  case regular
  case medium
  case semibold
  case bold
  case heavy

  var id: String { rawValue }

  var displayName: String {
    rawValue
      .replacingOccurrences(of: "ultraLight", with: "Ultra Light")
      .replacingOccurrences(of: "semibold", with: "Semibold")
      .capitalized
  }
}

struct TimeDateOverlaySettings: Codable, Hashable, Sendable {
  var enabled = false
  var hourFormat: ClockHourFormat = .system
  var showSeconds = false
  var dateStyle: ClockDateStyle = .medium
  var showWeekday = true
  var timezoneIdentifier: String?
  var localeIdentifier: String?
  var additionalTimeZoneIdentifiers: [String] = []
  var position: ClockOverlayPosition = .topRight
  var horizontalInset = 56.0
  var verticalInset = 52.0
  var timeFontSize = 64.0
  var dateFontSize = 18.0
  var fontWeight: ClockFontWeight = .medium
  var colorHex = "#FFFFFF"
  var opacity = 1.0
  var shadow = true
  var glassEnabled = true
  var glassOpacity = 0.45
  var backgroundOpacity = 0.08
  var cornerRadius = 24.0
  var uppercaseDate = false

  static let glass = TimeDateOverlaySettings()

  static let minimal: TimeDateOverlaySettings = {
    var value = TimeDateOverlaySettings()
    value.position = .bottomLeft
    value.timeFontSize = 54
    value.dateFontSize = 16
    value.glassEnabled = false
    value.backgroundOpacity = 0
    value.shadow = true
    return value
  }()

  static let bold: TimeDateOverlaySettings = {
    var value = TimeDateOverlaySettings()
    value.position = .center
    value.timeFontSize = 110
    value.dateFontSize = 22
    value.fontWeight = .bold
    value.glassEnabled = false
    value.backgroundOpacity = 0
    value.shadow = true
    return value
  }()
}
