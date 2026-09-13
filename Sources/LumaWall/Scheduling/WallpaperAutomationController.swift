import Combine
import Foundation

@MainActor
final class WallpaperAutomationController: ObservableObject {
  @Published var playlists: [WallpaperPlaylist] = [] { didSet { save() } }
  @Published var schedules: [WallpaperSchedule] = [] { didSet { save() } }
  @Published var solarLocation: SolarLocation? { didSet { save() } }

  var onWallpaperRequested: ((UUID) -> Void)?

  private var scheduleTimer: Timer?
  private var playlistTimer: Timer?
  private var activePlaylist: WallpaperPlaylist?
  private var lastScheduleFire: [UUID: Date] = [:]
  private let defaults = UserDefaults.standard

  init() {
    load()
    scheduleTimer = .scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      self?.evaluateSchedules()
    }
  }

  func play(_ playlist: WallpaperPlaylist) {
    activePlaylist = playlist
    advance()
    playlistTimer?.invalidate()
    playlistTimer = .scheduledTimer(
      withTimeInterval: max(10, playlist.intervalSeconds),
      repeats: true
    ) { [weak self] _ in
      self?.advance()
    }
  }

  func stopPlaylist() {
    playlistTimer?.invalidate()
    playlistTimer = nil
    activePlaylist = nil
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
    if let data = defaults.data(forKey: "automation.solar"),
      let value = try? JSONDecoder().decode(SolarLocation.self, from: data)
    {
      solarLocation = value
    }
  }
}
