import AppKit
import Foundation

struct AutomationContext: Equatable, Sendable {
  var date: Date
  var batteryPercent: Int?
  var isCharging: Bool
  var isLowPowerMode: Bool
  var displayCount: Int
  var externalDisplayConnected: Bool
  var isDarkMode: Bool
}

enum SmartRuleCondition: Codable, Hashable, Sendable {
  case batteryBelow(Int)
  case batteryAbove(Int)
  case charging(Bool)
  case lowPowerMode(Bool)
  case externalDisplayConnected(Bool)
  case darkMode(Bool)
  case weekday(Set<Int>)
  case timeRange(startMinutes: Int, endMinutes: Int)

  func matches(
    _ context: AutomationContext,
    calendar: Calendar = .current
  ) -> Bool {
    switch self {
    case .batteryBelow(let threshold):
      guard let battery = context.batteryPercent else { return false }
      return battery < threshold

    case .batteryAbove(let threshold):
      guard let battery = context.batteryPercent else { return false }
      return battery > threshold

    case .charging(let expected):
      return context.isCharging == expected

    case .lowPowerMode(let expected):
      return context.isLowPowerMode == expected

    case .externalDisplayConnected(let expected):
      return context.externalDisplayConnected == expected

    case .darkMode(let expected):
      return context.isDarkMode == expected

    case .weekday(let weekdays):
      let weekday = calendar.component(.weekday, from: context.date)
      return weekdays.contains(weekday)

    case .timeRange(let start, let end):
      let hour = calendar.component(.hour, from: context.date)
      let minute = calendar.component(.minute, from: context.date)
      let current = hour * 60 + minute

      if start <= end {
        return current >= start && current <= end
      }

      // Overnight range, e.g. 22:00 → 06:00.
      return current >= start || current <= end
    }
  }

  var displayName: String {
    switch self {
    case .batteryBelow(let value):
      return "Battery below \(value)%"
    case .batteryAbove(let value):
      return "Battery above \(value)%"
    case .charging(let value):
      return value ? "Charging" : "Not charging"
    case .lowPowerMode(let value):
      return value ? "Low Power Mode on" : "Low Power Mode off"
    case .externalDisplayConnected(let value):
      return value ? "External display connected" : "No external display"
    case .darkMode(let value):
      return value ? "Dark Mode" : "Light Mode"
    case .weekday(let values):
      return "Weekdays \(values.sorted().map(String.init).joined(separator: ","))"
    case .timeRange(let start, let end):
      return "\(Self.clock(start))–\(Self.clock(end))"
    }
  }

  private static func clock(_ minutes: Int) -> String {
    String(
      format: "%02d:%02d",
      (minutes / 60) % 24,
      minutes % 60
    )
  }
}

struct SmartWallpaperRule: Identifiable, Codable, Hashable, Sendable {
  var id = UUID()
  var name: String
  var wallpaperID: UUID
  var conditions: [SmartRuleCondition]
  var priority: Int = 0
  var enabled = true

  func matches(_ context: AutomationContext) -> Bool {
    enabled && !conditions.isEmpty
      && conditions.allSatisfy { $0.matches(context) }
  }
}
