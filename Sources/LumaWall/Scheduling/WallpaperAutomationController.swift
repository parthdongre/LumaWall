import Combine
import Foundation

@MainActor
final class WallpaperAutomationController: ObservableObject {
  @Published var playlists: [WallpaperPlaylist] = [] { didSet { save() } }
  @Published var schedules: [WallpaperSchedule] = [] { didSet { save() } }
  @Published var smartRules: [SmartWallpaperRule] = [] { didSet { save() } }
  @Published var solarLocation: SolarLocation? { didSet { save() } }

  var onWallpaperRequested: ((UUID) -> Void)?
  var contextProvider: (() -> AutomationContext?)?

  private var scheduleTimer: Timer?
  private var playlistTimer: Timer?
  private var ruleTimer: Timer?
  private var activePlaylist: WallpaperPlaylist?
  private var activeRuleID: UUID?
  private var lastScheduleFire: [UUID: Date] = [:]
  private let defaults = UserDefaults.standard

  init() {
    load()

    let scheduleTimer = Timer(
      timeInterval: 30,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.evaluateSchedules()
      }
    }
    self.scheduleTimer = scheduleTimer
    RunLoop.main.add(scheduleTimer, forMode: .common)

    let ruleTimer = Timer(
      timeInterval: 15,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.evaluateSmartRules()
      }
    }
    self.ruleTimer = ruleTimer
    RunLoop.main.add(ruleTimer, forMode: .common)
  }

  func play(_ playlist: WallpaperPlaylist) {
    activePlaylist = playlist
    advance()
    playlistTimer?.invalidate()
    let timer = Timer(
      timeInterval: max(10, playlist.intervalSeconds),
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.advance()
      }
    }
    playlistTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func stopPlaylist() {
    playlistTimer?.invalidate()
    playlistTimer = nil
    activePlaylist = nil
  }
  func addSmartRule(_ rule: SmartWallpaperRule) {
    smartRules.append(rule)
    evaluateSmartRules()
  }

  func removeSmartRule(_ id: UUID) {
    smartRules.removeAll { $0.id == id }
    if activeRuleID == id {
      activeRuleID = nil
    }
  }

  func setSmartRuleEnabled(_ id: UUID, enabled: Bool) {
    guard let index = smartRules.firstIndex(where: { $0.id == id }) else {
      return
    }

    smartRules[index].enabled = enabled

    if !enabled, activeRuleID == id {
      activeRuleID = nil
    }

    evaluateSmartRules()
  }

  func evaluateSmartRules() {
    guard let context = contextProvider?() else { return }

    let match = smartRules
      .filter { $0.matches(context) }
      .sorted {
        if $0.priority == $1.priority {
          return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return $0.priority > $1.priority
      }
      .first

    guard let match else {
      activeRuleID = nil
      return
    }

    guard activeRuleID != match.id else { return }

    activeRuleID = match.id
    onWallpaperRequested?(match.wallpaperID)
  }


  private func advance() {
    guard let playlist = activePlaylist, !playlist.wallpaperIDs.isEmpty else { return }
    if playlist.shuffle {
      onWallpaperRequested?(playlist.wallpaperIDs.randomElement()!)
    } else {
      let key = "playlistIndex.\(playlist.id)"
      let current = defaults.integer(forKey: key) % playlist.wallpaperIDs.count
      onWallpaperRequested?(playlist.wallpaperIDs[current])
      defaults.set(current + 1, forKey: key)
    }
  }

  private func evaluateSchedules() {
    let now = Date()
    let calendar = Calendar.current
    for schedule in schedules where schedule.enabled {
      guard shouldFire(schedule, now: now, calendar: calendar) else { continue }
      if let last = lastScheduleFire[schedule.id], now.timeIntervalSince(last) < 60 { continue }
      lastScheduleFire[schedule.id] = now
      onWallpaperRequested?(schedule.wallpaperID)
    }
  }

  private func shouldFire(_ schedule: WallpaperSchedule, now: Date, calendar: Calendar) -> Bool {
    let target: Date?
    switch schedule.trigger {
    case .daily(let hour, let minute):
      target = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)
    case .date(let date):
      target = date
    case .sunrise(let offset):
      target =
        solarLocation
        .flatMap { SolarCalculator.event(on: now, location: $0, sunrise: true) }
        .flatMap { calendar.date(byAdding: .minute, value: offset, to: $0) }
    case .sunset(let offset):
      target =
        solarLocation
        .flatMap { SolarCalculator.event(on: now, location: $0, sunrise: false) }
        .flatMap { calendar.date(byAdding: .minute, value: offset, to: $0) }
    }
    guard let target else { return false }
    return abs(now.timeIntervalSince(target)) < 30
  }

  private func save() {
    if let data = try? JSONEncoder().encode(playlists) {
      defaults.set(data, forKey: "automation.playlists")
    }
    if let data = try? JSONEncoder().encode(schedules) {
      defaults.set(data, forKey: "automation.schedules")
    }
    if let data = try? JSONEncoder().encode(smartRules) {
      defaults.set(data, forKey: "automation.smartRules")
    }
    if let data = try? JSONEncoder().encode(solarLocation) {
      defaults.set(data, forKey: "automation.solar")
    }
  }

  private func load() {
    if let data = defaults.data(forKey: "automation.playlists"),
      let value = try? JSONDecoder().decode([WallpaperPlaylist].self, from: data)
    {
      playlists = value
    }
    if let data = defaults.data(forKey: "automation.schedules"),
      let value = try? JSONDecoder().decode([WallpaperSchedule].self, from: data)
    {
      schedules = value
    }
    if let data = defaults.data(forKey: "automation.smartRules"),
      let value = try? JSONDecoder().decode([SmartWallpaperRule].self, from: data)
    {
      smartRules = value
    }
    if let data = defaults.data(forKey: "automation.solar"),
      let value = try? JSONDecoder().decode(SolarLocation.self, from: data)
    {
      solarLocation = value
    }
  }
}
