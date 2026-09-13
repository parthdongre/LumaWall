import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class AppModel: ObservableObject {
  @Published var wallpapers: [Wallpaper] = []
  @Published var selectedWallpaperID: UUID?
  @Published var selectedTargetDisplayID: CGDirectDisplayID?
  @Published var isPaused = false
  @Published var targetFPS = 60
  @Published var renderScale = 1.0
  @Published var displays: [DisplayDescriptor] = []
  @Published var propertyValues: [UUID: [String: WallpaperPropertyValue]] = [:]
  @Published var systemAudioEnabled = false
  @Published var lastError: String?
  @Published var sidebarSelection: SidebarDestination? = .library

  let engine = WallpaperEngine()
  let governor = PerformanceGovernor()
  let audio = AudioReactiveController()
  let automation = WallpaperAutomationController()
  let launchAtLogin = LaunchAtLoginController()
  let library: WallpaperLibrary
  private var cancellables = Set<AnyCancellable>()
  private var previewGenerationInFlight = Set<UUID>()

  init() {
    library = WallpaperLibrary()
    wallpapers = library.loadAll()
    displays = DisplayManager.connectedDisplays()
    selectedWallpaperID = wallpapers.first?.id
    for w in wallpapers {
      propertyValues[w.id] = Dictionary(
        uniqueKeysWithValues: w.properties.map { ($0.id, $0.defaultValue) })
    }
    governor.onPolicyChanged = { [weak self] p in self?.engine.apply(policy: p) }
    governor.start()
    audio.onFrame = { [weak self] frame in Task { @MainActor in self?.engine.updateAudio(frame) } }
    automation.onWallpaperRequested = { [weak self] id in self?.applyWallpaper(id: id, to: nil) }
    governor.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(
      in: &cancellables)
    automation.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(
      in: &cancellables)
    launchAtLogin.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(
      in: &cancellables)
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in Task { @MainActor in self?.displays = DisplayManager.connectedDisplays() }
    }
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 500_000_000)
      self?.restoreAssignments()
    }
    NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.shutdown()
      }
    }
  }

  func ensurePreview(for wallpaperID: UUID) async {
    guard !previewGenerationInFlight.contains(wallpaperID),
      let wallpaper = wallpapers.first(where: { $0.id == wallpaperID }),
      wallpaper.thumbnailURL == nil
        || !(wallpaper.thumbnailURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)
    else { return }

    previewGenerationInFlight.insert(wallpaperID)
    defer { previewGenerationInFlight.remove(wallpaperID) }

    let updated = await library.generatePreviewIfNeeded(for: wallpaper)
    if let index = wallpapers.firstIndex(where: { $0.id == wallpaperID }) {
      wallpapers[index] = updated
    }
  }

  func shutdown() {
    engine.stopAll()
    if systemAudioEnabled {
      Task { await audio.stop() }
    }
  }

  func importWallpaper() {
    let p = NSOpenPanel()
    p.canChooseDirectories = true
    p.canChooseFiles = true
    p.allowsMultipleSelection = false
    p.prompt = "Import"
    guard p.runModal() == .OK, let url = p.url else { return }
    do {
      var w = try library.importWallpaper(from: url)
      w = try requestSensitivePermissions(for: w)
      wallpapers.append(w)
      propertyValues[w.id] = Dictionary(
        uniqueKeysWithValues: w.properties.map { ($0.id, $0.defaultValue) })
      selectedWallpaperID = w.id
      Task {
        let updated = await library.generatePreviewIfNeeded(for: w)
        if let i = wallpapers.firstIndex(where: { $0.id == updated.id }) { wallpapers[i] = updated }
      }
    } catch { show(error) }
  }

  func exportSelectedWallpaper() {
    guard let w = selectedWallpaper else { return }
    let p = NSSavePanel()
    p.nameFieldStringValue = "\(w.name).wall"
    guard p.runModal() == .OK, var url = p.url else { return }
    if url.pathExtension.lowercased() != "wall" { url.appendPathExtension("wall") }
    do { try library.exportWallpaper(w, to: url) } catch { show(error) }
  }
  var selectedWallpaper: Wallpaper? {
    guard let id = selectedWallpaperID else { return nil }
    return wallpapers.first { $0.id == id }
  }

  func applySelectedWallpaper() {
    guard let id = selectedWallpaperID else { return }
    applyWallpaper(id: id, to: selectedTargetDisplayID)
  }
  func applyWallpaper(id: UUID, to displayID: CGDirectDisplayID?) {
    guard let idx = wallpapers.firstIndex(where: { $0.id == id }) else { return }
    do {
      let w = try requestSensitivePermissions(for: wallpapers[idx])
      wallpapers[idx] = w
      let targets = displayID.flatMap { wanted in displays.filter { $0.id == wanted } } ?? displays
      try engine.apply(wallpaper: w, to: targets, properties: propertyValues[id] ?? [:])
      saveAssignments()
    } catch { show(error) }
  }
  func togglePause() {
    isPaused.toggle()
    engine.setUserPaused(isPaused)
  }
  func updateFPS(_ fps: Int) {
    targetFPS = fps
    engine.setFPS(fps)
  }
  func updateRenderScale(_ scale: Double) {
    renderScale = scale
    engine.setRenderScale(scale)
  }
  func setProperty(_ value: WallpaperPropertyValue, propertyID: String, wallpaperID: UUID) {
    var v = propertyValues[wallpaperID] ?? [:]
    v[propertyID] = value
    propertyValues[wallpaperID] = v
    engine.setProperties(v, for: wallpaperID)
  }

  func setSystemAudioEnabled(_ enabled: Bool) {
    systemAudioEnabled = enabled
    Task {
      do { if enabled { try await audio.startSystemAudio() } else { await audio.stop() } } catch {
        await MainActor.run {
          self.systemAudioEnabled = false
          self.show(error)
        }
      }
    }
  }
  func createPlaylistFromAll() {
    guard !wallpapers.isEmpty else { return }
    automation.playlists.append(
      .init(
        name: "All Wallpapers", wallpaperIDs: wallpapers.map(\.id), intervalSeconds: 300,
        shuffle: false))
  }
  func addDailySchedule(for id: UUID, hour: Int, minute: Int) {
    automation.schedules.append(.init(wallpaperID: id, trigger: .daily(hour: hour, minute: minute)))
  }
  func addSunriseSchedule(for id: UUID) {
    automation.schedules.append(.init(wallpaperID: id, trigger: .sunrise(offsetMinutes: 0)))
  }

  func assignmentName(for display: DisplayDescriptor) -> String {
    guard let id = engine.assignmentSnapshot[display.id],
      let w = wallpapers.first(where: { $0.id == id })
    else { return "Not assigned" }
    return w.name
  }
  func setPermission(_ permission: WallpaperPermission, granted: Bool, for wallpaperID: UUID) {
    guard let index = wallpapers.firstIndex(where: { $0.id == wallpaperID }) else { return }
    do {
      let current = wallpapers[index]
      let updated =
        granted
        ? try library.grant([permission], to: current)
        : try library.revoke([permission], from: current)
      wallpapers[index] = updated
      let activeDisplays = displays.filter { engine.assignmentSnapshot[$0.id] == wallpaperID }
      if !activeDisplays.isEmpty {
        try engine.apply(
          wallpaper: updated,
          to: activeDisplays,
          properties: propertyValues[wallpaperID] ?? [:]
        )
      }
    } catch { show(error) }
  }

  private func restoreAssignments() {
    guard
      let saved = UserDefaults.standard.dictionary(forKey: "displayAssignments")
        as? [String: String]
    else { return }
    for display in displays {
      guard let raw = saved[String(display.id)], let id = UUID(uuidString: raw),
        let wallpaper = wallpapers.first(where: { $0.id == id })
      else { continue }
      try? engine.apply(
        wallpaper: wallpaper,
        to: [display],
        properties: propertyValues[id] ?? [:]
      )
    }
  }

  private func saveAssignments() {
    let dict = engine.assignmentSnapshot.reduce(into: [String: String]()) {
      $0[String($1.key)] = $1.value.uuidString
    }
    UserDefaults.standard.set(dict, forKey: "displayAssignments")
  }

  private func requestSensitivePermissions(for wallpaper: Wallpaper) throws -> Wallpaper {
    let pending = wallpaper.requestedPermissions.filter {
      $0.isSensitive && !wallpaper.grantedPermissions.contains($0)
    }
    guard !pending.isEmpty else { return wallpaper }
    let alert = NSAlert()
    alert.messageText = "Wallpaper permissions"
    alert.informativeText =
      "\(wallpaper.name) requests: \(pending.map(\.displayName).sorted().joined(separator:", ")). Grant these permissions?"
    alert.addButton(withTitle: "Grant")
    alert.addButton(withTitle: "Keep Blocked")
    guard alert.runModal() == .alertFirstButtonReturn else { return wallpaper }
    return try library.grant(Set(pending), to: wallpaper)
  }
  private func show(_ error: Error) {
    lastError = error.localizedDescription
    NSAlert(error: error).runModal()
  }
}
