import Foundation
import Testing
@testable import LumaWall

private func makeCrashDefaults() -> (UserDefaults, String) {
  let suite = "LumaWallTests.CrashQuarantine.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defaults.removePersistentDomain(forName: suite)
  return (defaults, suite)
}

private func destroyCrashDefaults(_ defaults: UserDefaults, suite: String) {
  defaults.removePersistentDomain(forName: suite)
}

@Test @MainActor
func crashQuarantineStartsClean() {
  let (defaults, suite) = makeCrashDefaults()
  defer { destroyCrashDefaults(defaults, suite: suite) }

  let service = CrashQuarantineService(defaults: defaults)

  #expect(service.previousLaunchWasClean)
  #expect(service.suspectedWallpaperIDs.isEmpty)
  #expect(service.quarantinedIDs.isEmpty)
}

@Test @MainActor
func crashQuarantineTracksOnlyWallpapersActiveAtCrash() {
  let (defaults, suite) = makeCrashDefaults()
  defer { destroyCrashDefaults(defaults, suite: suite) }

  let active = UUID()
  defaults.set(false, forKey: "stability.cleanShutdown")
  defaults.set([active.uuidString], forKey: "stability.activeWallpaperIDs")

  let service = CrashQuarantineService(defaults: defaults)

  #expect(!service.previousLaunchWasClean)
  #expect(service.suspectedWallpaperIDs == Set([active]))
  #expect(service.crashCount(for: active) == 1)
  #expect(!service.isQuarantined(active))
}

@Test @MainActor
func crashQuarantineDisablesWallpaperAfterThreshold() {
  let (defaults, suite) = makeCrashDefaults()
  defer { destroyCrashDefaults(defaults, suite: suite) }

  let wallpaper = UUID()
  defaults.set(false, forKey: "stability.cleanShutdown")
  defaults.set([wallpaper.uuidString], forKey: "stability.activeWallpaperIDs")

  _ = CrashQuarantineService(defaults: defaults, crashThreshold: 3)
  _ = CrashQuarantineService(defaults: defaults, crashThreshold: 3)
  let third = CrashQuarantineService(defaults: defaults, crashThreshold: 3)

  #expect(third.crashCount(for: wallpaper) == 3)
  #expect(third.isQuarantined(wallpaper))
}

@Test @MainActor
func stoppingWallpaperBeforeCrashPreventsFalseAttribution() {
  let (defaults, suite) = makeCrashDefaults()
  defer { destroyCrashDefaults(defaults, suite: suite) }

  let wallpaper = UUID()
  let service = CrashQuarantineService(defaults: defaults)
  service.recordActiveWallpaperIDs([wallpaper])
  service.recordActiveWallpaperIDs([])

  let nextLaunch = CrashQuarantineService(defaults: defaults)

  #expect(!nextLaunch.previousLaunchWasClean)
  #expect(nextLaunch.suspectedWallpaperIDs.isEmpty)
  #expect(nextLaunch.crashCount(for: wallpaper) == 0)
  #expect(!nextLaunch.isQuarantined(wallpaper))
}

@Test @MainActor
func stableWallpaperClearsCrashCount() {
  let (defaults, suite) = makeCrashDefaults()
  defer { destroyCrashDefaults(defaults, suite: suite) }

  let wallpaper = UUID()
  defaults.set(false, forKey: "stability.cleanShutdown")
  defaults.set([wallpaper.uuidString], forKey: "stability.activeWallpaperIDs")

  let service = CrashQuarantineService(defaults: defaults)
  #expect(service.crashCount(for: wallpaper) == 1)

  service.markStable([wallpaper])

  #expect(service.crashCount(for: wallpaper) == 0)
}

@Test @MainActor
func reEnablingWallpaperClearsQuarantineAndCount() {
  let (defaults, suite) = makeCrashDefaults()
  defer { destroyCrashDefaults(defaults, suite: suite) }

  let wallpaper = UUID()
  defaults.set(false, forKey: "stability.cleanShutdown")
  defaults.set([wallpaper.uuidString], forKey: "stability.activeWallpaperIDs")

  _ = CrashQuarantineService(defaults: defaults, crashThreshold: 1)
  let service = CrashQuarantineService(defaults: defaults, crashThreshold: 1)
  #expect(service.isQuarantined(wallpaper))

  service.allowAgain(wallpaper)

  #expect(!service.isQuarantined(wallpaper))
  #expect(service.crashCount(for: wallpaper) == 0)
}

@Test @MainActor
func cleanShutdownClearsActiveCrashAttribution() {
  let (defaults, suite) = makeCrashDefaults()
  defer { destroyCrashDefaults(defaults, suite: suite) }

  let wallpaper = UUID()
  let service = CrashQuarantineService(defaults: defaults)
  service.recordActiveWallpaperIDs([wallpaper])
  service.markCleanShutdown()

  let nextLaunch = CrashQuarantineService(defaults: defaults)

  #expect(nextLaunch.previousLaunchWasClean)
  #expect(nextLaunch.suspectedWallpaperIDs.isEmpty)
  #expect(nextLaunch.crashCount(for: wallpaper) == 0)
}

@Test @MainActor
func resetStabilityHistoryClearsCountsAndQuarantine() {
  let (defaults, suite) = makeCrashDefaults()
  defer { destroyCrashDefaults(defaults, suite: suite) }

  let wallpaper = UUID()
  defaults.set(false, forKey: "stability.cleanShutdown")
  defaults.set([wallpaper.uuidString], forKey: "stability.activeWallpaperIDs")

  let service = CrashQuarantineService(defaults: defaults, crashThreshold: 1)
  #expect(service.isQuarantined(wallpaper))

  service.resetHistory()

  #expect(service.quarantinedIDs.isEmpty)
  #expect(service.crashCount(for: wallpaper) == 0)
}
