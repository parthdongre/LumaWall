import AppKit
import SwiftUI
import Testing
@testable import LumaWall

@Test("Capture macOS UI screenshots")
@MainActor
func captureMacOSUIScreenshots() async throws {
  guard
    let outputPath = ProcessInfo.processInfo.environment["LUMAWALL_SCREENSHOT_DIR"],
    !outputPath.isEmpty
  else {
    return
  }

  let output = URL(fileURLWithPath: outputPath, isDirectory: true)
  try FileManager.default.createDirectory(
    at: output,
    withIntermediateDirectories: true
  )

  let application = NSApplication.shared
  application.appearance = NSAppearance(named: .darkAqua)
  UserDefaults.standard.set(true, forKey: "onboarding.completed")
  UserDefaults.standard.set(false, forKey: "startup.safeModeNextLaunch")
  UserDefaults.standard.set(false, forKey: "startup.restoreAssignments")

  let model = AppModel()
  model.searchText = ""
  model.statusMessage = nil

  for wallpaper in model.wallpapers.prefix(6) {
    await model.ensurePreview(for: wallpaper.id)
  }

  model.sidebarSelection = .library(.all)
  try capture(
    ContentView()
      .environmentObject(model),
    size: NSSize(width: 1360, height: 860),
    title: "LumaWall",
    to: output.appendingPathComponent("01-library.png")
  )

  if let eventHorizon = model.wallpapers.first(where: { $0.name == "Event Horizon" })
    ?? model.wallpapers.first
  {
    model.selectedWallpaperID = eventHorizon.id
    model.sidebarSelection = .wallpaper(eventHorizon.id)
    await model.ensurePreview(for: eventHorizon.id)

    try capture(
      ContentView()
        .environmentObject(model),
      size: NSSize(width: 1360, height: 900),
      title: "LumaWall",
      to: output.appendingPathComponent("02-wallpaper-detail.png")
    )
  }

  try capture(
    SettingsView()
      .environmentObject(model),
    size: NSSize(width: 690, height: 610),
    title: "LumaWall Settings",
    to: output.appendingPathComponent("03-settings.png")
  )

  model.sidebarSelection = .diagnostics
  try capture(
    ContentView()
      .environmentObject(model),
    size: NSSize(width: 1360, height: 900),
    title: "LumaWall",
    to: output.appendingPathComponent("04-diagnostics.png")
  )

  model.onboardingPage = 0
  try capture(
    OnboardingView()
      .environmentObject(model),
    size: NSSize(width: 720, height: 500),
    title: "Welcome to LumaWall",
    to: output.appendingPathComponent("05-onboarding.png")
  )

  model.onboardingPage = 2
  try capture(
    OnboardingView()
      .environmentObject(model),
    size: NSSize(width: 720, height: 500),
    title: "LumaWall Setup",
    to: output.appendingPathComponent("06-onboarding-performance.png")
  )

  if
    let creatorSource = model.wallpapers
      .compactMap(\.thumbnailURL)
      .first(where: { FileManager.default.fileExists(atPath: $0.path) })
  {
    model.setCreatorSource(creatorSource)
    model.creatorDraft.name = "Canva Concept"
    model.creatorDraft.author = "LumaWall Creator"
    model.creatorDraft.category = "Minimal"
    model.creatorDraft.tagsText = "dark, canva, concept"
    model.creatorDraft.clockPreset = .glass
  }

  model.sidebarSelection = .creator
  try capture(
    ContentView()
      .environmentObject(model),
    size: NSSize(width: 1440, height: 920),
    title: "LumaWall",
    to: output.appendingPathComponent("07-creator-studio.png")
  )

  if let overlayWallpaper = model.selectedWallpaperID ?? model.wallpapers.first?.id {
    model.selectedWallpaperID = overlayWallpaper
    var overlay = model.timeDateSettings(for: overlayWallpaper)
    overlay.enabled = true
    overlay.customNormalizedX = 0.72
    overlay.customNormalizedY = 0.24
    model.updateTimeDateSettings(overlay, for: overlayWallpaper)
  }

  model.sidebarSelection = .overlayStudio
  try capture(
    ContentView()
      .environmentObject(model),
    size: NSSize(width: 1440, height: 980),
    title: "LumaWall",
    to: output.appendingPathComponent("08-overlay-studio.png")
  )

  model.sidebarSelection = .lockScreen
  try capture(
    ContentView()
      .environmentObject(model),
    size: NSSize(width: 1440, height: 940),
    title: "LumaWall",
    to: output.appendingPathComponent("09-lock-screen-companion.png")
  )

  model.sidebarSelection = .discover
  try capture(
    ContentView()
      .environmentObject(model),
    size: NSSize(width: 1440, height: 900),
    title: "LumaWall",
    to: output.appendingPathComponent("10-discover.png")
  )

  model.shutdown()
}

@MainActor
private func capture<V: View>(
  _ rootView: V,
  size: NSSize,
  title: String,
  to destination: URL
) throws {
  let darkAppearance = NSAppearance(named: .darkAqua)
  let contentView = NSHostingView(
    rootView: rootView
      .environment(\.colorScheme, .dark)
  )
  contentView.appearance = darkAppearance
  contentView.frame = NSRect(origin: .zero, size: size)

  let window = NSWindow(
    contentRect: NSRect(origin: .zero, size: size),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
  )
  window.appearance = darkAppearance
  window.title = title
  window.contentView = contentView
  window.setContentSize(size)
  window.center()
  window.makeKeyAndOrderFront(nil)

  contentView.layoutSubtreeIfNeeded()
  window.displayIfNeeded()

  for _ in 0..<5 {
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    contentView.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
  }

  guard let rep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
    throw ScreenshotError.couldNotCreateBitmap
  }
  contentView.cacheDisplay(in: contentView.bounds, to: rep)

  guard let data = rep.representation(using: .png, properties: [:]) else {
    throw ScreenshotError.couldNotEncodePNG
  }
  try data.write(to: destination, options: .atomic)

  window.orderOut(nil)
  window.contentView = nil
  window.close()
}

private enum ScreenshotError: Error {
  case couldNotCreateBitmap
  case couldNotEncodePNG
}
