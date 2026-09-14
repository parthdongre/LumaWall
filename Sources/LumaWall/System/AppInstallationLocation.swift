import AppKit
import Foundation

struct AppInstallationLocation: Equatable {
  let bundleURL: URL

  static var current: AppInstallationLocation {
    AppInstallationLocation(bundleURL: Bundle.main.bundleURL)
  }

  var isAppBundle: Bool {
    bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame
  }

  var isRunningFromDiskImage: Bool {
    guard isAppBundle else { return false }
    let path = bundleURL.standardizedFileURL.path
    return path == "/Volumes" || path.hasPrefix("/Volumes/")
  }

  var isInstalledInApplications: Bool {
    guard isAppBundle else { return false }

    let components = bundleURL.standardizedFileURL.pathComponents
    guard let appIndex = components.lastIndex(where: {
      $0.caseInsensitiveCompare("Applications") == .orderedSame
    }) else {
      return false
    }

    return appIndex == components.count - 2
  }

  var shouldRecommendInstallation: Bool {
    isAppBundle && !isInstalledInApplications
  }

  var recommendationTitle: String {
    isRunningFromDiskImage
      ? "Finish installing LumaWall"
      : "Move LumaWall to Applications"
  }

  var recommendationMessage: String {
    if isRunningFromDiskImage {
      return "LumaWall is running from the installer disk image. Drag LumaWall.app into Applications, then open the installed copy."
    }

    return "LumaWall works best from Applications so Launch at Login, updates, and macOS app registration use a stable location."
  }

  func openApplicationsFolder() {
    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
  }

  func revealCurrentApp() {
    guard isAppBundle else { return }
    NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
  }
}
