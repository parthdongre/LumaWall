import AppKit
import Foundation
import Testing
@testable import LumaWall

private func automationContext(
  date: Date = Date(),
  battery: Int? = 50,
  charging: Bool = false,
  lowPower: Bool = false,
  external: Bool = false,
  dark: Bool = false
) -> AutomationContext {
  AutomationContext(
    date: date,
    batteryPercent: battery,
    isCharging: charging,
    isLowPowerMode: lowPower,
    displayCount: external ? 2 : 1,
    externalDisplayConnected: external,
    isDarkMode: dark
  )
}

@Test
func smartBatteryAndDisplayConditionsMatch() {
  #expect(
    SmartRuleCondition.batteryBelow(30)
      .matches(automationContext(battery: 20))
  )
  #expect(
    !SmartRuleCondition.batteryBelow(30)
      .matches(automationContext(battery: 80))
  )
  #expect(
    SmartRuleCondition.externalDisplayConnected(true)
      .matches(automationContext(external: true))
  )
}

@Test
func smartOvernightRangeMatchesAcrossMidnight() throws {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0)!

  let formatter = ISO8601DateFormatter()
  let late = try #require(formatter.date(from: "2026-09-13T23:30:00Z"))
  let noon = try #require(formatter.date(from: "2026-09-13T12:00:00Z"))

  let condition = SmartRuleCondition.timeRange(
    startMinutes: 22 * 60,
    endMinutes: 6 * 60
  )

  #expect(
    condition.matches(
      automationContext(date: late),
      calendar: calendar
    )
  )
  #expect(
    !condition.matches(
      automationContext(date: noon),
      calendar: calendar
    )
  )
}

@Test
func smartRuleRequiresAllConditions() {
  let rule = SmartWallpaperRule(
    name: "Night Charging",
    wallpaperID: UUID(),
    conditions: [
      .charging(true),
      .darkMode(true),
    ]
  )

  #expect(
    rule.matches(
      automationContext(
        charging: true,
        dark: true
      )
    )
  )

  #expect(
    !rule.matches(
      automationContext(
        charging: true,
        dark: false
      )
    )
  )
}

@Test @MainActor
func automationFiresHighestPriorityRuleOnlyOncePerMatch() {
  let controller = WallpaperAutomationController()
  let lowPriority = UUID()
  let highPriority = UUID()
  var requested: [UUID] = []

  controller.smartRules = [
    SmartWallpaperRule(
      name: "Low",
      wallpaperID: lowPriority,
      conditions: [.lowPowerMode(true)],
      priority: 10
    ),
    SmartWallpaperRule(
      name: "High",
      wallpaperID: highPriority,
      conditions: [.lowPowerMode(true)],
      priority: 100
    ),
  ]

  controller.contextProvider = {
    automationContext(lowPower: true)
  }
  controller.onWallpaperRequested = {
    requested.append($0)
  }

  controller.evaluateSmartRules()
  controller.evaluateSmartRules()

  #expect(requested == [highPriority])
}
