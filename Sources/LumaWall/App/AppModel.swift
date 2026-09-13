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
  @Published var renderScale = 0.85
  @Published var displays: [DisplayDescriptor] = []
  @Published var propertyValues: [UUID: [String: WallpaperPropertyValue]] = [:]
  @Published var systemAudioEnabled = false
  @Published var lastError: String?
  @Published var sidebarSelection: SidebarDestination? = .library(.all)
  @Published var searchText = ""
  @Published var librarySortOrder: LibrarySortOrder = .name
  @Published private(set) var favoriteWallpaperIDs: Set<UUID> = []
  @Published private(set) var recentWallpaperIDs: [UUID] = []
  @Published var qualityPreset: RenderQualityPreset = .balanced
  @Published var restoreAssignmentsOnLaunch = true
  @Published private(set) var isSafeMode = false
  @Published var statusMessage: String?
  @Published var showOnboarding = false
  @Published var onboardingPage = 0

  let engine = WallpaperEngine()
  let governor = PerformanceGovernor()
  let audio = AudioReactiveController()
  let automation = WallpaperAutomationController()
  let launchAtLogin = LaunchAtLoginController()
  let updater = UpdateService()
  let library: WallpaperLibrary

  private var cancellables = Set<AnyCancellable>()
  private var previewGenerationInFlight = Set<UUID>()
  private let defaults = UserDefaults.standard

  private enum Keys {
    static let favorites = "library.favoriteWallpaperIDs"
    static let recents = "library.recentWallpaperIDs"
    static let sort = "library.sortOrder"
    static let propertyValues = "wallpaper.propertyValues"
    static let qualityPreset = "performance.qualityPreset"
    static let targetFPS = "performance.targetFPS"
    static let renderScale = "performance.renderScale"
    static let adaptiveQuality = "performance.adaptiveQuality"
    static let pauseFullscreen = "performance.pauseFullscreen"
    static let pauseGames = "performance.pauseGames"
    static let restoreAssignments = "startup.restoreAssignments"
    static let safeModeNextLaunch = "startup.safeModeNextLaunch"
    static let onboardingCompleted = "onboarding.completed"
  }

  init() {
    library = WallpaperLibrary()
    wallpapers = library.loadAll()
    displays = DisplayManager.connectedDisplays()
    selectedWallpaperID = wallpapers.first?.id
    showOnboarding = !defaults.bool(forKey: Keys.onboardingCompleted)

    favoriteWallpaperIDs = Set(
      defaults.stringArray(forKey: Keys.favorites)?.compactMap(UUID.init(uuidString:)) ?? [])
    recentWallpaperIDs =
      defaults.stringArray(forKey: Keys.recents)?.compactMap(UUID.init(uuidString:)) ?? []
    librarySortOrder =
      defaults.string(forKey: Keys.sort).flatMap(LibrarySortOrder.init(rawValue:)) ?? .name
    qualityPreset =
      defaults.string(forKey: Keys.qualityPreset).flatMap(RenderQualityPreset.init(rawValue:))
      ?? .balanced

    let savedFPS = defaults.integer(forKey: Keys.targetFPS)
    targetFPS = savedFPS > 0 ? savedFPS : (qualityPreset.targetFPS ?? 60)
    let savedScale = defaults.object(forKey: Keys.renderScale) as? Double
    renderScale = savedScale ?? qualityPreset.renderScale ?? 0.85

    restoreAssignmentsOnLaunch =
      defaults.object(forKey: Keys.restoreAssignments) as? Bool ?? true

    let requestedSafeMode =
      CommandLine.arguments.contains("--safe-mode") || defaults.bool(forKey: Keys.safeModeNextLaunch)
    isSafeMode = requestedSafeMode
    defaults.set(false, forKey: Keys.safeModeNextLaunch)

    let savedProperties = Self.loadSavedProperties(from: defaults)
    for wallpaper in wallpapers {
      var values = Dictionary(
        uniqueKeysWithValues: wallpaper.properties.map { ($0.id, $0.defaultValue) })
      if let persisted = savedProperties[wallpaper.id] {
        values.merge(persisted) { _, saved in saved }
      }
      propertyValues[wallpaper.id] = values
    }

    governor.pauseForFullscreen =
      defaults.object(forKey: Keys.pauseFullscreen) as? Bool ?? true
    governor.pauseForGames =
      defaults.object(forKey: Keys.pauseGames) as? Bool ?? true
    governor.setAdaptiveQualityEnabled(
      defaults.object(forKey: Keys.adaptiveQuality) as? Bool ?? true)
    governor.setUserTargets(fps: targetFPS, renderScale: renderScale)
    governor.onPolicyChanged = { [weak self] policy in
      self?.engine.apply(policy: policy)
    }
    governor.start()

    audio.onFrame = { [weak self] frame in
      Task { @MainActor in self?.engine.updateAudio(frame) }
    }
    automation.onWallpaperRequested = { [weak self] id in
      self?.applyWallpaper(id: id, to: nil)
    }

    governor.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(
      in: &cancellables)
    automation.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(
      in: &cancellables)
    launchAtLogin.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(
      in: &cancellables)
    updater.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(
      in: &cancellables)

    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.displays = DisplayManager.connectedDisplays()
      }
    }

    NotificationCenter.default.addObserver(
      forName: .lumaWallOpenFiles,
      object: nil,
      queue: .main
    ) { [weak self] note in
      let urls = note.object as? [URL] ?? []
      Task { @MainActor in
        for url in urls {
          self?.importWallpaper(from: url)
        }
      }
    }

    NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.shutdown()
      }
    }

    if restoreAssignmentsOnLaunch && !isSafeMode {
      Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: 650_000_000)
        self?.restoreAssignments()
      }
    } else if isSafeMode {
      statusMessage = "Safe Mode is active. Saved wallpapers were not restored."
    }
  }

  var selectedWallpaper: Wallpaper? {
    guard let id = selectedWallpaperID else { return nil }
    return wallpapers.first { $0.id == id }
  }

  var recentWallpapers: [Wallpaper] {
    recentWallpaperIDs.compactMap { id in wallpapers.first(where: { $0.id == id }) }
  }

  var activeWallpaperIDs: Set<UUID> {
    Set(engine.assignmentSnapshot.values)
  }

  var applicationSupportPath: String {
    library.libraryRoot.deletingLastPathComponent().path
  }

  var diagnosticReport: String {
    let process = ProcessInfo.processInfo
    let assignments = displays.map { display in
      let wallpaper = assignmentName(for: display)
      return "  • \(display.name) [\(display.id)]: \(wallpaper)"
    }.joined(separator: "\n")

    return """
    LumaWall Diagnostics
    ====================
    Version: \(AppVersion.display)
    macOS: \(process.operatingSystemVersionString)
    Architecture: \(Self.architectureName)
    Safe Mode: \(isSafeMode)
    Restore on Launch: \(restoreAssignmentsOnLaunch)

    Rendering
    ---------
    Quality Preset: \(qualityPreset.displayName)
    Preferred FPS: \(targetFPS)
    Preferred Render Scale: \(Int(renderScale * 100))%
    Adaptive Quality: \(governor.adaptiveQualityEnabled)
    User Paused: \(isPaused)
    Low Power Mode: \(process.isLowPowerModeEnabled)
    Thermal State: \(Self.thermalStateName(process.thermalState))
    Foreground App: \(governor.foregroundActivity.ownerName ?? "Unknown")
    Foreground Fullscreen: \(governor.foregroundActivity.isFullscreen)
    Foreground Game: \(governor.foregroundActivity.isGame)

    Library
    -------
    Wallpapers: \(wallpapers.count)
    Favorites: \(favoriteWallpaperIDs.count)
    Recent: \(recentWallpaperIDs.count)
    System Audio Enabled: \(systemAudioEnabled)

    Displays / Assignments
    ----------------------
    \(assignments.isEmpty ? "  None" : assignments)

    Last Error
    ----------
    \(lastError ?? "None")
    """
  }

  func wallpapers(for scope: LibraryScope) -> [Wallpaper] {
    var result: [Wallpaper]

    switch scope {
    case .all:
      result = wallpapers
    case .favorites:
      result = wallpapers.filter { favoriteWallpaperIDs.contains($0.id) }
    case .recent:
      result = recentWallpapers
    case .metal:
      result = wallpapers.filter { $0.type == .metal }
    case .web:
      result = wallpapers.filter { $0.type == .web }
    case .video:
      result = wallpapers.filter { $0.type == .video }
    case .image:
      result = wallpapers.filter { $0.type == .image }
    case .audioReactive:
      result = wallpapers.filter {
        $0.requestedPermissions.contains(.systemAudio)
      }
    }

    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !query.isEmpty {
      result = result.filter {
        $0.name.localizedCaseInsensitiveContains(query)
          || $0.author.localizedCaseInsensitiveContains(query)
          || $0.type.rawValue.localizedCaseInsensitiveContains(query)
      }
    }

    if scope == .recent || librarySortOrder == .recent {
      let ranks = Dictionary(uniqueKeysWithValues: recentWallpaperIDs.enumerated().map { ($1, $0) })
      return result.sorted {
        (ranks[$0.id] ?? Int.max, $0.name) < (ranks[$1.id] ?? Int.max, $1.name)
      }
    }

    return result.sorted {
      switch librarySortOrder {
      case .name:
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      case .author:
        let comparison = $0.author.localizedCaseInsensitiveCompare($1.author)
        return comparison == .orderedSame
          ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
          : comparison == .orderedAscending
      case .type:
        return ($0.type.rawValue, $0.name) < ($1.type.rawValue, $1.name)
      case .recent:
        return false
      }
    }
  }

  func isFavorite(_ id: UUID) -> Bool {
    favoriteWallpaperIDs.contains(id)
  }

  func toggleFavorite(_ id: UUID) {
    if favoriteWallpaperIDs.contains(id) {
      favoriteWallpaperIDs.remove(id)
    } else {
      favoriteWallpaperIDs.insert(id)
    }
    defaults.set(favoriteWallpaperIDs.map(\.uuidString).sorted(), forKey: Keys.favorites)
  }

  func clearRecents() {
    recentWallpaperIDs.removeAll()
    defaults.removeObject(forKey: Keys.recents)
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
    governor.stop()
    if systemAudioEnabled {
      Task { await audio.stop() }
    }
  }

  func nextOnboardingPage() {
    onboardingPage = min(3, onboardingPage + 1)
  }

  func previousOnboardingPage() {
    onboardingPage = max(0, onboardingPage - 1)
  }

  func finishOnboarding() {
    defaults.set(true, forKey: Keys.onboardingCompleted)
    showOnboarding = false
    onboardingPage = 0
    statusMessage = "Welcome to LumaWall"
  }

  func reopenOnboarding() {
    onboardingPage = 0
    showOnboarding = true
  }

  func checkForUpdates() {
    updater.checkForUpdates(currentVersion: AppVersion.version)
  }

  func importWallpaper() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = true
    panel.prompt = "Import"
    guard panel.runModal() == .OK else { return }
    for url in panel.urls {
      importWallpaper(from: url)
    }
  }

  func importWallpaper(from url: URL) {
    do {
      var wallpaper = try library.importWallpaper(from: url)
      wallpaper = try requestSensitivePermissions(for: wallpaper)
      wallpapers.removeAll(where: { $0.id == wallpaper.id })
      wallpapers.append(wallpaper)
      propertyValues[wallpaper.id] = Dictionary(
        uniqueKeysWithValues: wallpaper.properties.map { ($0.id, $0.defaultValue) })
      selectedWallpaperID = wallpaper.id
      sidebarSelection = .wallpaper(wallpaper.id)
      statusMessage = "Imported \(wallpaper.name)"
    } catch {
      show(error)
    }
  }

  func exportSelectedWallpaper() {
    guard let wallpaper = selectedWallpaper else { return }
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "\(wallpaper.name).wall"
    guard panel.runModal() == .OK, var url = panel.url else { return }
    if url.pathExtension.lowercased() != "wall" {
      url.appendPathExtension("wall")
    }
    do {
      try library.exportWallpaper(wallpaper, to: url)
      statusMessage = "Exported \(wallpaper.name)"
    } catch {
      show(error)
    }
  }

  func applySelectedWallpaper() {
    guard let id = selectedWallpaperID else { return }
    applyWallpaper(id: id, to: selectedTargetDisplayID)
  }

  func applyWallpaper(id: UUID, to displayID: CGDirectDisplayID?) {
    guard let index = wallpapers.firstIndex(where: { $0.id == id }) else { return }
    do {
      let wallpaper = try requestSensitivePermissions(for: wallpapers[index])
      wallpapers[index] = wallpaper
      let targets = displayID.flatMap { wanted in displays.filter { $0.id == wanted } } ?? displays
      try engine.apply(
        wallpaper: wallpaper,
        to: targets,
        properties: propertyValues[id] ?? [:]
      )
      selectedWallpaperID = id
      markWallpaperUsed(id)
      saveAssignments()
      statusMessage =
        displayID == nil
        ? "Applied \(wallpaper.name) to all displays"
        : "Applied \(wallpaper.name)"
    } catch {
      show(error)
    }
  }

  func stopWallpapers(on displayID: CGDirectDisplayID?) {
    if let displayID {
      engine.removeWallpaper(from: displayID)
    } else {
      engine.stopAll()
    }
    saveAssignments()
    statusMessage = displayID == nil ? "Stopped all wallpapers" : "Stopped wallpaper"
  }

  func stopAllAndClearAssignments() {
    engine.stopAll()
    defaults.removeObject(forKey: "displayAssignments")
    statusMessage = "Stopped all wallpapers and cleared saved display assignments"
  }

  func togglePause() {
    isPaused.toggle()
    engine.setUserPaused(isPaused)
  }

  func applyQualityPreset(_ preset: RenderQualityPreset) {
    qualityPreset = preset
    defaults.set(preset.rawValue, forKey: Keys.qualityPreset)
    guard let fps = preset.targetFPS, let scale = preset.renderScale else { return }
    targetFPS = fps
    renderScale = scale
    defaults.set(fps, forKey: Keys.targetFPS)
    defaults.set(scale, forKey: Keys.renderScale)
    governor.setUserTargets(fps: fps, renderScale: scale)
  }

  func updateFPS(_ fps: Int) {
    qualityPreset = .custom
    targetFPS = max(15, min(120, fps))
    defaults.set(RenderQualityPreset.custom.rawValue, forKey: Keys.qualityPreset)
    defaults.set(targetFPS, forKey: Keys.targetFPS)
    governor.setUserTargets(fps: targetFPS, renderScale: renderScale)
  }

  func updateRenderScale(_ scale: Double) {
    qualityPreset = .custom
    renderScale = min(max(scale, 0.25), 1)
    defaults.set(RenderQualityPreset.custom.rawValue, forKey: Keys.qualityPreset)
    defaults.set(renderScale, forKey: Keys.renderScale)
    governor.setUserTargets(fps: targetFPS, renderScale: renderScale)
  }

  func setAdaptiveQualityEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: Keys.adaptiveQuality)
    governor.setAdaptiveQualityEnabled(enabled)
  }

  func setPauseForFullscreen(_ enabled: Bool) {
    defaults.set(enabled, forKey: Keys.pauseFullscreen)
    governor.pauseForFullscreen = enabled
    governor.refresh()
  }

  func setPauseForGames(_ enabled: Bool) {
    defaults.set(enabled, forKey: Keys.pauseGames)
    governor.pauseForGames = enabled
    governor.refresh()
  }

  func setProperty(_ value: WallpaperPropertyValue, propertyID: String, wallpaperID: UUID) {
    var values = propertyValues[wallpaperID] ?? [:]
    values[propertyID] = value
    propertyValues[wallpaperID] = values
    savePropertyValues()
    engine.setProperties(values, for: wallpaperID)
  }

  func resetProperties(for wallpaperID: UUID) {
    guard let wallpaper = wallpapers.first(where: { $0.id == wallpaperID }) else { return }
    let values = Dictionary(
      uniqueKeysWithValues: wallpaper.properties.map { ($0.id, $0.defaultValue) })
    propertyValues[wallpaperID] = values
    savePropertyValues()
    engine.setProperties(values, for: wallpaperID)
  }

  func resetAllCreatorSettings() {
    propertyValues.removeAll()
    for wallpaper in wallpapers {
      propertyValues[wallpaper.id] = Dictionary(
        uniqueKeysWithValues: wallpaper.properties.map { ($0.id, $0.defaultValue) })
    }
    savePropertyValues()
    for id in activeWallpaperIDs {
      engine.setProperties(propertyValues[id] ?? [:], for: id)
    }
    statusMessage = "Reset all creator controls"
  }

  func setSystemAudioEnabled(_ enabled: Bool) {
    systemAudioEnabled = enabled
    Task {
      do {
        if enabled {
          try await audio.startSystemAudio()
        } else {
          await audio.stop()
        }
      } catch {
        await MainActor.run {
          self.systemAudioEnabled = false
          self.show(error)
        }
      }
    }
  }

  func setRestoreAssignmentsOnLaunch(_ enabled: Bool) {
    restoreAssignmentsOnLaunch = enabled
    defaults.set(enabled, forKey: Keys.restoreAssignments)
  }

  func enableSafeModeForNextLaunch() {
    defaults.set(true, forKey: Keys.safeModeNextLaunch)
    statusMessage = "Safe Mode will be used on the next launch"
  }

  func createPlaylistFromAll() {
    guard !wallpapers.isEmpty else { return }
    automation.playlists.append(
      .init(
        name: "All Wallpapers",
        wallpaperIDs: wallpapers.map(\.id),
        intervalSeconds: 300,
        shuffle: false
      ))
  }

  func addDailySchedule(for id: UUID, hour: Int, minute: Int) {
    automation.schedules.append(
      .init(wallpaperID: id, trigger: .daily(hour: hour, minute: minute)))
  }

  func addSunriseSchedule(for id: UUID) {
    automation.schedules.append(
      .init(wallpaperID: id, trigger: .sunrise(offsetMinutes: 0)))
  }

  func assignmentName(for display: DisplayDescriptor) -> String {
    guard let id = engine.assignmentSnapshot[display.id],
      let wallpaper = wallpapers.first(where: { $0.id == id })
    else { return "Not assigned" }
    return wallpaper.name
  }

  func activeDisplayNames(for wallpaperID: UUID) -> [String] {
    displays.compactMap { display in
      engine.assignmentSnapshot[display.id] == wallpaperID ? display.name : nil
    }
  }

  func isWallpaperActive(_ id: UUID) -> Bool {
    activeWallpaperIDs.contains(id)
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

      let activeDisplays = displays.filter {
        engine.assignmentSnapshot[$0.id] == wallpaperID
      }
      if !activeDisplays.isEmpty {
        try engine.apply(
          wallpaper: updated,
          to: activeDisplays,
          properties: propertyValues[wallpaperID] ?? [:]
        )
      }
    } catch {
      show(error)
    }
  }

  func openLibraryFolder() {
    NSWorkspace.shared.open(library.libraryRoot)
  }

  func openCrashReportsFolder() {
    let url = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
    NSWorkspace.shared.open(url)
  }

  func copyDiagnosticReport() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(diagnosticReport, forType: .string)
    statusMessage = "Diagnostics copied to clipboard"
  }

  func exportDiagnosticReport() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "LumaWall-Diagnostics.txt"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try diagnosticReport.write(to: url, atomically: true, encoding: .utf8)
      statusMessage = "Diagnostics exported"
    } catch {
      show(error)
    }
  }

  private func markWallpaperUsed(_ id: UUID) {
    recentWallpaperIDs.removeAll(where: { $0 == id })
    recentWallpaperIDs.insert(id, at: 0)
    if recentWallpaperIDs.count > 20 {
      recentWallpaperIDs = Array(recentWallpaperIDs.prefix(20))
    }
    defaults.set(recentWallpaperIDs.map(\.uuidString), forKey: Keys.recents)
  }

  private func restoreAssignments() {
    guard
      let saved = defaults.dictionary(forKey: "displayAssignments") as? [String: String]
    else { return }

    for display in displays {
      guard
        let raw = saved[String(display.id)],
        let id = UUID(uuidString: raw),
        let wallpaper = wallpapers.first(where: { $0.id == id })
      else { continue }

      do {
        try engine.apply(
          wallpaper: wallpaper,
          to: [display],
          properties: propertyValues[id] ?? [:]
        )
      } catch {
        lastError = "Could not restore \(wallpaper.name): \(error.localizedDescription)"
      }
    }
  }

  private func saveAssignments() {
    let dictionary = engine.assignmentSnapshot.reduce(into: [String: String]()) {
      $0[String($1.key)] = $1.value.uuidString
    }
    defaults.set(dictionary, forKey: "displayAssignments")
  }

  private func savePropertyValues() {
    let stringKeyed = Dictionary(
      uniqueKeysWithValues: propertyValues.map { ($0.key.uuidString, $0.value) })
    if let data = try? JSONEncoder().encode(stringKeyed) {
      defaults.set(data, forKey: Keys.propertyValues)
    }
  }

  private static func loadSavedProperties(
    from defaults: UserDefaults
  ) -> [UUID: [String: WallpaperPropertyValue]] {
    guard
      let data = defaults.data(forKey: Keys.propertyValues),
      let decoded = try? JSONDecoder().decode(
        [String: [String: WallpaperPropertyValue]].self,
        from: data
      )
    else {
      return [:]
    }

    return decoded.reduce(into: [:]) { result, element in
      if let id = UUID(uuidString: element.key) {
        result[id] = element.value
      }
    }
  }

  private func requestSensitivePermissions(for wallpaper: Wallpaper) throws -> Wallpaper {
    let pending = wallpaper.requestedPermissions.filter {
      $0.isSensitive && !wallpaper.grantedPermissions.contains($0)
    }
    guard !pending.isEmpty else { return wallpaper }

    let alert = NSAlert()
    alert.messageText = "Wallpaper permissions"
    alert.informativeText =
      "\(wallpaper.name) requests: \(pending.map(\.displayName).sorted().joined(separator: ", ")). Grant these permissions?"
    alert.addButton(withTitle: "Grant")
    alert.addButton(withTitle: "Keep Blocked")
    guard alert.runModal() == .alertFirstButtonReturn else { return wallpaper }
    return try library.grant(Set(pending), to: wallpaper)
  }

  private func show(_ error: Error) {
    lastError = error.localizedDescription
    NSAlert(error: error).runModal()
  }

  private static var architectureName: String {
    #if arch(arm64)
      return "Apple Silicon (arm64)"
    #elseif arch(x86_64)
      return "Intel (x86_64)"
    #else
      return "Unknown"
    #endif
  }

  private static func thermalStateName(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "Nominal"
    case .fair: return "Fair"
    case .serious: return "Serious"
    case .critical: return "Critical"
    @unknown default: return "Unknown"
    }
  }
}
