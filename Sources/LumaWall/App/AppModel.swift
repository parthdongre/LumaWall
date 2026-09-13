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
  @Published var maximumResolutionEnabled = true
  @Published var displays: [DisplayDescriptor] = []
  @Published private(set) var hardwareProfile: MacHardwareProfile
  @Published var propertyValues: [UUID: [String: WallpaperPropertyValue]] = [:]
  @Published var systemAudioEnabled = false
  @Published var lastError: String?
  @Published var sidebarSelection: SidebarDestination? = .library(.all)
  @Published var searchText = ""
  @Published var librarySortOrder: LibrarySortOrder = .name
  @Published private(set) var favoriteWallpaperIDs: Set<UUID> = []
  @Published private(set) var recentWallpaperIDs: [UUID] = []
  @Published var qualityPreset: RenderQualityPreset = .automatic
  @Published var restoreAssignmentsOnLaunch = true
  @Published private(set) var isSafeMode = false
  @Published var statusMessage: String?
  @Published var showOnboarding = false
  @Published var onboardingPage = 0
  @Published var transitionStyle: WallpaperTransitionStyle = .crossfade
  @Published var transitionDuration = 0.8
  @Published var displayProfiles: [CGDirectDisplayID: DisplayPerformanceProfile] = [:]
  @Published var fitModes: [UUID: WallpaperFitMode] = [:]
  @Published var videoPlaybackSettings: [UUID: VideoPlaybackSettings] = [:]
  @Published var timeDateOverlaySettings: [UUID: TimeDateOverlaySettings] = [:]
  @Published var usePowerProfiles = true
  @Published var pluggedInProfile = PowerPerformanceProfile.pluggedIn
  @Published var batteryProfile = PowerPerformanceProfile.battery
  @Published var lowPowerProfile = PowerPerformanceProfile.lowPower
  @Published var creatorDraft = CreatorWallpaperDraft()
  @Published var creatorAssetSummary: CreatorAssetSummary?
  @Published var creatorIsCreating = false

  let engine = WallpaperEngine()
  let governor = PerformanceGovernor()
  let audio = AudioReactiveController()
  let automation = WallpaperAutomationController()
  let launchAtLogin = LaunchAtLoginController()
  let updater = UpdateService()
  let power = PowerSourceMonitor()
  let quarantine = CrashQuarantineService()
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
    static let maximumResolution = "performance.maximumResolution"
    static let hardwareProfileApplied = "performance.hardwareProfileApplied"
    static let adaptiveQuality = "performance.adaptiveQuality"
    static let pauseFullscreen = "performance.pauseFullscreen"
    static let pauseGames = "performance.pauseGames"
    static let restoreAssignments = "startup.restoreAssignments"
    static let safeModeNextLaunch = "startup.safeModeNextLaunch"
    static let onboardingCompleted = "onboarding.completed"
    static let transitionStyle = "rendering.transitionStyle"
    static let transitionDuration = "rendering.transitionDuration"
    static let displayProfiles = "rendering.displayProfiles"
    static let fitModes = "rendering.fitModes"
    static let videoSettings = "rendering.videoSettings"
    static let timeDateSettings = "overlay.timeDateSettings"
    static let usePowerProfiles = "performance.usePowerProfiles"
    static let pluggedInProfile = "performance.pluggedInProfile"
    static let batteryProfile = "performance.batteryProfile"
    static let lowPowerProfile = "performance.lowPowerProfile"
    static let creatorAuthor = "creator.defaultAuthor"
  }

  init() {
    library = WallpaperLibrary()
    let detectedDisplays = DisplayManager.connectedDisplays()
    hardwareProfile = MacHardwareProfile.detect(displays: detectedDisplays)
    displays = detectedDisplays
    wallpapers = library.loadAll()
    selectedWallpaperID = wallpapers.first?.id
    creatorDraft.author = defaults.string(forKey: Keys.creatorAuthor) ?? ""
    showOnboarding = !defaults.bool(forKey: Keys.onboardingCompleted)

    favoriteWallpaperIDs = Set(
      defaults.stringArray(forKey: Keys.favorites)?.compactMap(UUID.init(uuidString:)) ?? [])
    recentWallpaperIDs =
      defaults.stringArray(forKey: Keys.recents)?.compactMap(UUID.init(uuidString:)) ?? []
    librarySortOrder =
      defaults.string(forKey: Keys.sort).flatMap(LibrarySortOrder.init(rawValue:)) ?? .name
    let hardwareProfileAlreadyApplied = defaults.bool(forKey: Keys.hardwareProfileApplied)
    if hardwareProfileAlreadyApplied {
      qualityPreset =
        defaults.string(forKey: Keys.qualityPreset).flatMap(RenderQualityPreset.init(rawValue:))
        ?? .automatic

      let savedFPS = defaults.integer(forKey: Keys.targetFPS)
      targetFPS = savedFPS > 0 ? savedFPS : hardwareProfile.recommendedFPS
      maximumResolutionEnabled =
        defaults.object(forKey: Keys.maximumResolution) as? Bool ?? true

      let savedScale = defaults.object(forKey: Keys.renderScale) as? Double
      renderScale =
        maximumResolutionEnabled
        ? 1.0
        : (savedScale ?? qualityPreset.renderScale ?? hardwareProfile.recommendedRenderScale)
    } else {
      qualityPreset = .automatic
      targetFPS = hardwareProfile.recommendedFPS
      renderScale = hardwareProfile.recommendedRenderScale
      maximumResolutionEnabled = true
      defaults.set(RenderQualityPreset.automatic.rawValue, forKey: Keys.qualityPreset)
      defaults.set(targetFPS, forKey: Keys.targetFPS)
      defaults.set(renderScale, forKey: Keys.renderScale)
      defaults.set(true, forKey: Keys.maximumResolution)
      defaults.set(true, forKey: Keys.hardwareProfileApplied)
    }

    restoreAssignmentsOnLaunch =
      defaults.object(forKey: Keys.restoreAssignments) as? Bool ?? true

    let requestedSafeMode =
      CommandLine.arguments.contains("--safe-mode") || defaults.bool(forKey: Keys.safeModeNextLaunch)
    isSafeMode = requestedSafeMode
    defaults.set(false, forKey: Keys.safeModeNextLaunch)

    transitionStyle =
      defaults.string(forKey: Keys.transitionStyle)
        .flatMap(WallpaperTransitionStyle.init(rawValue:))
      ?? .crossfade
    transitionDuration =
      defaults.object(forKey: Keys.transitionDuration) as? Double
      ?? 0.8

    fitModes = Self.loadFitModes(from: defaults)
    videoPlaybackSettings = Self.loadVideoSettings(from: defaults)
    timeDateOverlaySettings = Self.loadTimeDateSettings(from: defaults)
    displayProfiles = Self.loadDisplayProfiles(
      from: defaults,
      displays: detectedDisplays,
      fallbackFPS: targetFPS,
      fallbackScale: renderScale,
      maximumResolution: maximumResolutionEnabled
    )

    usePowerProfiles =
      defaults.object(forKey: Keys.usePowerProfiles) as? Bool
      ?? true
    pluggedInProfile =
      Self.loadPowerProfile(
        key: Keys.pluggedInProfile,
        from: defaults
      ) ?? .pluggedIn
    batteryProfile =
      Self.loadPowerProfile(
        key: Keys.batteryProfile,
        from: defaults
      ) ?? .battery
    lowPowerProfile =
      Self.loadPowerProfile(
        key: Keys.lowPowerProfile,
        from: defaults
      ) ?? .lowPower

    engine.setTransitionSettings(
      .init(
        style: transitionStyle,
        duration: transitionDuration
      )
    )
    engine.setDisplayProfiles(displayProfiles)
    for (id, mode) in fitModes {
      engine.setFitMode(mode, for: id)
    }
    for (id, settings) in videoPlaybackSettings {
      engine.setVideoPlaybackSettings(settings, for: id)
    }
    for (id, settings) in timeDateOverlaySettings {
      engine.setTimeDateOverlay(settings, for: id)
    }

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
    governor.setMaximumResolutionEnabled(maximumResolutionEnabled)
    governor.setUserTargets(fps: targetFPS, renderScale: renderScale)
    governor.onPolicyChanged = { [weak self] policy in
      self?.engine.apply(policy: policy)
    }
    governor.onFullscreenDisplaysChanged = { [weak self] displayIDs in
      self?.engine.setFullscreenPausedDisplays(displayIDs)
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
    power.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(
      in: &cancellables)
    power.$snapshot
      .dropFirst()
      .sink { [weak self] _ in
        self?.applyAutomaticPowerProfile()
      }
      .store(in: &cancellables)
    power.start()

    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        let updatedDisplays = DisplayManager.connectedDisplays()
        self.displays = updatedDisplays

        for display in updatedDisplays where self.displayProfiles[display.id] == nil {
          self.displayProfiles[display.id] = DisplayPerformanceProfile(
            displayID: display.id,
            targetFPS: min(self.targetFPS, display.maximumFPS),
            renderScale: self.renderScale,
            maximumResolution: self.maximumResolutionEnabled,
            fitMode: .fill
          )
        }

        self.saveDisplayProfiles()
        self.engine.setDisplayProfiles(self.displayProfiles)
        self.engine.refreshDisplays(updatedDisplays)
        self.hardwareProfile = MacHardwareProfile.detect(displays: updatedDisplays)

        if self.qualityPreset == .automatic {
          self.applyHardwareRecommendation()
        }
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

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.engine.setSystemSuspended(true)
        if self?.systemAudioEnabled == true {
          await self?.audio.stop()
        }
      }
    }

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        self.engine.setSystemSuspended(false)
        if self.systemAudioEnabled {
          try? await self.audio.startSystemAudio()
        }
      }
    }

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.screensDidSleepNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.engine.setSystemSuspended(true)
      }
    }

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.screensDidWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.engine.setSystemSuspended(false)
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

    Task { @MainActor [weak self] in
      guard let self else { return }
      if let marketingName = await MacHardwareProfile.resolveMarketingName() {
        self.hardwareProfile = self.hardwareProfile.replacingMarketingName(marketingName)
      }
    }

    if !quarantine.quarantinedIDs.isEmpty {
      statusMessage =
        "\(quarantine.quarantinedIDs.count) wallpaper(s) are quarantined after repeated crashes."
    }

    applyAutomaticPowerProfile()

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
      return "  • \(display.name) [\(display.id)]: \(wallpaper) — \(display.nativeResolutionLabel), \(display.refreshLabel), \(String(format: "%.1f×", display.backingScaleFactor))"
    }.joined(separator: "\n")

    return """
    LumaWall Diagnostics
    ====================
    Version: \(AppVersion.display)
    macOS: \(process.operatingSystemVersionString)
    Architecture: \(Self.architectureName)
    Device: \(hardwareProfile.deviceFamily)
    Model Identifier: \(hardwareProfile.modelIdentifier)
    Graphics / Chip: \(hardwareProfile.chipName)
    Memory: \(hardwareProfile.memoryGB) GB
    CPU Cores: \(hardwareProfile.processorCount)
    Safe Mode: \(isSafeMode)
    Restore on Launch: \(restoreAssignmentsOnLaunch)

    Rendering
    ---------
    Quality Preset: \(qualityPreset.displayName)
    Preferred FPS: \(targetFPS)
    Preferred Render Scale: \(Int(renderScale * 100))%
    Maximum Resolution: \(maximumResolutionEnabled)
    Hardware Recommendation: \(hardwareProfile.explanation)
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
    quarantine.markCleanShutdown()
    engine.stopAll()
    governor.stop()
    power.stop()
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

  func chooseCreatorAsset() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose Artwork"
    panel.message = "Choose a Canva image or video export."

    guard panel.runModal() == .OK, let url = panel.url else { return }
    setCreatorSource(url)
  }

  func setCreatorSource(_ url: URL) {
    do {
      let summary = try library.inspectCreatorAsset(url)
      creatorAssetSummary = summary
      creatorDraft.sourceURL = url

      if creatorDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        creatorDraft.name = url.deletingPathExtension().lastPathComponent
      }

      statusMessage = "Selected \(summary.filename)"
    } catch {
      show(error)
    }
  }

  func chooseCreatorThumbnail() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose Thumbnail"
    panel.message = "Choose a PNG, JPEG, HEIC, TIFF or WebP thumbnail."

    guard panel.runModal() == .OK, let url = panel.url else { return }

    let ext = url.pathExtension.lowercased()
    guard ["png", "jpg", "jpeg", "heic", "tiff", "webp"].contains(ext) else {
      show(CreatorPackageError.unsupportedSource(ext))
      return
    }

    creatorDraft.thumbnailURL = url
  }

  func clearCreatorThumbnail() {
    creatorDraft.thumbnailURL = nil
  }

  func resetCreatorStudio() {
    creatorDraft.reset(keepingAuthor: true)
    creatorAssetSummary = nil
  }

  func createCreatorWallpaper(exportAfterCreation: Bool = false) {
    guard creatorDraft.isReadyToCreate, !creatorIsCreating else { return }

    creatorIsCreating = true
    let draft = creatorDraft
    defaults.set(draft.author, forKey: Keys.creatorAuthor)

    Task { @MainActor [weak self] in
      guard let self else { return }

      defer {
        self.creatorIsCreating = false
      }

      do {
        var wallpaper = try await self.library.createWallpaper(from: draft)

        if wallpaper.thumbnailURL == nil {
          wallpaper = await self.library.generatePreviewIfNeeded(for: wallpaper)
        }

        self.wallpapers.removeAll(where: { $0.id == wallpaper.id })
        self.wallpapers.append(wallpaper)
        self.propertyValues[wallpaper.id] = [:]

        self.fitModes[wallpaper.id] = draft.fitMode
        self.saveFitModes()
        self.engine.setFitMode(draft.fitMode, for: wallpaper.id)

        if wallpaper.type == .video {
          let settings = VideoPlaybackSettings(
            playbackRate: draft.videoPlaybackRate,
            muted: draft.videoMuted,
            loop: draft.videoLoop
          )
          self.videoPlaybackSettings[wallpaper.id] = settings
          self.saveVideoSettings()
          self.engine.setVideoPlaybackSettings(settings, for: wallpaper.id)
        }

        if let overlay = draft.clockPreset.overlaySettings {
          self.timeDateOverlaySettings[wallpaper.id] = overlay
          self.saveTimeDateSettings()
          self.engine.setTimeDateOverlay(overlay, for: wallpaper.id)
        }

        self.selectedWallpaperID = wallpaper.id
        self.sidebarSelection = .wallpaper(wallpaper.id)
        self.statusMessage = "Created \(wallpaper.name)"

        if exportAfterCreation {
          self.exportWallpaper(wallpaper)
        }

        self.creatorDraft.reset(keepingAuthor: true)
        self.creatorAssetSummary = nil
      } catch {
        self.show(error)
      }
    }
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
    exportWallpaper(wallpaper)
  }

  private func exportWallpaper(_ wallpaper: Wallpaper) {
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

    guard !quarantine.isQuarantined(id) else {
      statusMessage =
        "\(wallpapers[index].name) is quarantined after repeated crashes. Re-enable it from Recovery."
      return
    }

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
      quarantine.recordActiveWallpaperIDs(activeWallpaperIDs)
      Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: 60_000_000_000)
        guard let self, self.activeWallpaperIDs.contains(id) else { return }
        self.quarantine.markStable([id])
      }
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
    quarantine.recordActiveWallpaperIDs([])
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

    if preset == .automatic {
      applyHardwareRecommendation()
      return
    }

    guard let fps = preset.targetFPS, let scale = preset.renderScale else { return }
    targetFPS = fps
    renderScale = maximumResolutionEnabled ? 1.0 : scale
    defaults.set(targetFPS, forKey: Keys.targetFPS)
    defaults.set(renderScale, forKey: Keys.renderScale)
    governor.setUserTargets(fps: targetFPS, renderScale: renderScale)
  }

  func applyHardwareRecommendation() {
    qualityPreset = .automatic
    targetFPS = hardwareProfile.recommendedFPS
    renderScale = maximumResolutionEnabled ? 1.0 : hardwareProfile.recommendedRenderScale
    defaults.set(RenderQualityPreset.automatic.rawValue, forKey: Keys.qualityPreset)
    defaults.set(targetFPS, forKey: Keys.targetFPS)
    defaults.set(renderScale, forKey: Keys.renderScale)
    governor.setUserTargets(fps: targetFPS, renderScale: renderScale)
    statusMessage = "Optimized for \(hardwareProfile.displayName)"
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
    if renderScale < 0.999 {
      maximumResolutionEnabled = false
      defaults.set(false, forKey: Keys.maximumResolution)
      governor.setMaximumResolutionEnabled(false)
    }
    defaults.set(RenderQualityPreset.custom.rawValue, forKey: Keys.qualityPreset)
    defaults.set(renderScale, forKey: Keys.renderScale)
    governor.setUserTargets(fps: targetFPS, renderScale: renderScale)
  }

  func setMaximumResolutionEnabled(_ enabled: Bool) {
    maximumResolutionEnabled = enabled
    defaults.set(enabled, forKey: Keys.maximumResolution)
    governor.setMaximumResolutionEnabled(enabled)

    if enabled {
      renderScale = 1.0
      defaults.set(1.0, forKey: Keys.renderScale)
      governor.setUserTargets(fps: targetFPS, renderScale: 1.0)
    } else {
      governor.setUserTargets(fps: targetFPS, renderScale: renderScale)
    }
  }

  func setTransitionStyle(_ style: WallpaperTransitionStyle) {
    transitionStyle = style
    defaults.set(style.rawValue, forKey: Keys.transitionStyle)
    engine.setTransitionSettings(
      .init(style: style, duration: transitionDuration)
    )
  }

  func setTransitionDuration(_ duration: Double) {
    transitionDuration = min(max(duration, 0), 4)
    defaults.set(transitionDuration, forKey: Keys.transitionDuration)
    engine.setTransitionSettings(
      .init(style: transitionStyle, duration: transitionDuration)
    )
  }

  func displayProfile(for display: DisplayDescriptor) -> DisplayPerformanceProfile {
    displayProfiles[display.id]
      ?? DisplayPerformanceProfile(
        displayID: display.id,
        targetFPS: min(targetFPS, display.maximumFPS),
        renderScale: renderScale,
        maximumResolution: maximumResolutionEnabled,
        fitMode: .fill
      )
  }

  func updateDisplayProfile(_ profile: DisplayPerformanceProfile) {
    displayProfiles[profile.displayID] = profile
    saveDisplayProfiles()
    engine.setDisplayProfiles(displayProfiles)
  }

  func setFitMode(_ mode: WallpaperFitMode, for wallpaperID: UUID) {
    fitModes[wallpaperID] = mode
    saveFitModes()
    engine.setFitMode(mode, for: wallpaperID)
  }

  func timeDateSettings(for wallpaperID: UUID) -> TimeDateOverlaySettings {
    timeDateOverlaySettings[wallpaperID] ?? .init()
  }

  func updateTimeDateSettings(
    _ settings: TimeDateOverlaySettings,
    for wallpaperID: UUID
  ) {
    timeDateOverlaySettings[wallpaperID] = settings
    saveTimeDateSettings()
    engine.setTimeDateOverlay(settings, for: wallpaperID)
  }

  func applyTimeDatePreset(
    _ preset: TimeDateOverlaySettings,
    to wallpaperID: UUID
  ) {
    var value = preset
    value.enabled = true
    updateTimeDateSettings(value, for: wallpaperID)
  }

  func videoSettings(for wallpaperID: UUID) -> VideoPlaybackSettings {
    videoPlaybackSettings[wallpaperID] ?? .init()
  }

  func updateVideoSettings(
    _ settings: VideoPlaybackSettings,
    for wallpaperID: UUID
  ) {
    videoPlaybackSettings[wallpaperID] = settings
    saveVideoSettings()
    engine.setVideoPlaybackSettings(settings, for: wallpaperID)
  }

  func isQuarantined(_ id: UUID) -> Bool {
    quarantine.isQuarantined(id)
  }

  func allowQuarantinedWallpaper(_ id: UUID) {
    quarantine.allowAgain(id)
    statusMessage = "Wallpaper re-enabled."
  }

  func setUsePowerProfiles(_ enabled: Bool) {
    usePowerProfiles = enabled
    defaults.set(enabled, forKey: Keys.usePowerProfiles)
    applyAutomaticPowerProfile()
  }

  func updatePowerProfile(
    _ profile: PowerPerformanceProfile,
    for source: MacPowerSource,
    lowPower: Bool = false
  ) {
    if lowPower {
      lowPowerProfile = profile
      savePowerProfile(profile, key: Keys.lowPowerProfile)
    } else if source == .battery {
      batteryProfile = profile
      savePowerProfile(profile, key: Keys.batteryProfile)
    } else {
      pluggedInProfile = profile
      savePowerProfile(profile, key: Keys.pluggedInProfile)
    }
    applyAutomaticPowerProfile()
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

  private func applyAutomaticPowerProfile() {
    guard usePowerProfiles, qualityPreset == .automatic else { return }

    let profile: PowerPerformanceProfile
    if ProcessInfo.processInfo.isLowPowerModeEnabled {
      profile = lowPowerProfile
    } else if power.snapshot.source == .battery {
      profile = batteryProfile
    } else {
      profile = pluggedInProfile
    }

    targetFPS = max(15, min(120, profile.fps))
    maximumResolutionEnabled = profile.maximumResolution
    renderScale = profile.maximumResolution
      ? 1.0
      : min(max(profile.renderScale, 0.25), 1.0)

    governor.setMaximumResolutionEnabled(maximumResolutionEnabled)
    governor.setUserTargets(
      fps: targetFPS,
      renderScale: renderScale
    )
  }

  private func restoreAssignments() {
    guard
      let saved = defaults.dictionary(forKey: "displayAssignments") as? [String: String]
    else { return }

    for display in displays {
      guard
        let raw = saved[String(display.id)],
        let id = UUID(uuidString: raw),
        let wallpaper = wallpapers.first(where: { $0.id == id }),
        !quarantine.isQuarantined(id)
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
    quarantine.recordActiveWallpaperIDs(activeWallpaperIDs)
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

  private func saveDisplayProfiles() {
    if let data = try? JSONEncoder().encode(Array(displayProfiles.values)) {
      defaults.set(data, forKey: Keys.displayProfiles)
    }
  }

  private func saveFitModes() {
    let dictionary = Dictionary(
      uniqueKeysWithValues: fitModes.map {
        ($0.key.uuidString, $0.value.rawValue)
      }
    )
    defaults.set(dictionary, forKey: Keys.fitModes)
  }

  private func saveVideoSettings() {
    let dictionary = Dictionary(
      uniqueKeysWithValues: videoPlaybackSettings.map {
        ($0.key.uuidString, $0.value)
      }
    )
    if let data = try? JSONEncoder().encode(dictionary) {
      defaults.set(data, forKey: Keys.videoSettings)
    }
  }

  private func saveTimeDateSettings() {
    let dictionary = Dictionary(
      uniqueKeysWithValues: timeDateOverlaySettings.map {
        ($0.key.uuidString, $0.value)
      }
    )
    if let data = try? JSONEncoder().encode(dictionary) {
      defaults.set(data, forKey: Keys.timeDateSettings)
    }
  }

  private func savePowerProfile(
    _ profile: PowerPerformanceProfile,
    key: String
  ) {
    if let data = try? JSONEncoder().encode(profile) {
      defaults.set(data, forKey: key)
    }
  }

  private static func loadDisplayProfiles(
    from defaults: UserDefaults,
    displays: [DisplayDescriptor],
    fallbackFPS: Int,
    fallbackScale: Double,
    maximumResolution: Bool
  ) -> [CGDirectDisplayID: DisplayPerformanceProfile] {
    let saved: [DisplayPerformanceProfile]
    if let data = defaults.data(forKey: Keys.displayProfiles),
      let decoded = try? JSONDecoder().decode(
        [DisplayPerformanceProfile].self,
        from: data
      )
    {
      saved = decoded
    } else {
      saved = []
    }

    var profiles = Dictionary(
      uniqueKeysWithValues: saved.map {
        (CGDirectDisplayID($0.displayID), $0)
      }
    )

    for display in displays where profiles[display.id] == nil {
      profiles[display.id] = DisplayPerformanceProfile(
        displayID: display.id,
        targetFPS: min(fallbackFPS, display.maximumFPS),
        renderScale: fallbackScale,
        maximumResolution: maximumResolution,
        fitMode: .fill
      )
    }

    return profiles
  }

  private static func loadFitModes(
    from defaults: UserDefaults
  ) -> [UUID: WallpaperFitMode] {
    guard
      let dictionary = defaults.dictionary(forKey: Keys.fitModes) as? [String: String]
    else {
      return [:]
    }

    return dictionary.reduce(into: [:]) { result, element in
      if let id = UUID(uuidString: element.key),
        let mode = WallpaperFitMode(rawValue: element.value)
      {
        result[id] = mode
      }
    }
  }

  private static func loadVideoSettings(
    from defaults: UserDefaults
  ) -> [UUID: VideoPlaybackSettings] {
    guard
      let data = defaults.data(forKey: Keys.videoSettings),
      let dictionary = try? JSONDecoder().decode(
        [String: VideoPlaybackSettings].self,
        from: data
      )
    else {
      return [:]
    }

    return dictionary.reduce(into: [:]) { result, element in
      if let id = UUID(uuidString: element.key) {
        result[id] = element.value
      }
    }
  }

  private static func loadTimeDateSettings(
    from defaults: UserDefaults
  ) -> [UUID: TimeDateOverlaySettings] {
    guard
      let data = defaults.data(forKey: Keys.timeDateSettings),
      let dictionary = try? JSONDecoder().decode(
        [String: TimeDateOverlaySettings].self,
        from: data
      )
    else {
      return [:]
    }

    return dictionary.reduce(into: [:]) { result, element in
      if let id = UUID(uuidString: element.key) {
        result[id] = element.value
      }
    }
  }

  private static func loadPowerProfile(
    key: String,
    from defaults: UserDefaults
  ) -> PowerPerformanceProfile? {
    guard
      let data = defaults.data(forKey: key)
    else {
      return nil
    }
    return try? JSONDecoder().decode(
      PowerPerformanceProfile.self,
      from: data
    )
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
