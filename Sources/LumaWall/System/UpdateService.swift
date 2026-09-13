import AppKit
import Combine
import Foundation

private struct GitHubRelease: Decodable {
  struct Asset: Decodable {
    let name: String
    let browser_download_url: URL
  }

  let tag_name: String
  let html_url: URL
  let assets: [Asset]
}

@MainActor
final class UpdateService: ObservableObject {
  @Published private(set) var isChecking = false
  @Published private(set) var isDownloading = false
  @Published private(set) var latestVersion: String?
  @Published private(set) var updateAvailable = false
  @Published private(set) var statusMessage = "Updates have not been checked yet."

  private var installerURL: URL?
  private var releasePageURL: URL?

  func checkForUpdates(currentVersion: String) {
    guard !isChecking else { return }
    isChecking = true
    statusMessage = "Checking for updates…"

    Task {
      defer { isChecking = false }

      do {
        let endpoint = URL(
          string: "https://api.github.com/repos/parthdongre/LumaWall/releases/latest"
        )!
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("LumaWall/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
          throw URLError(.badServerResponse)
        }

        if http.statusCode == 404 {
          latestVersion = nil
          updateAvailable = false
          installerURL = nil
          releasePageURL = nil
          statusMessage = "No public LumaWall release has been published yet."
          return
        }

        guard (200...299).contains(http.statusCode) else {
          throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let normalized = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        latestVersion = normalized
        releasePageURL = release.html_url
        installerURL =
          release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })?
          .browser_download_url
          ?? release.assets.first(where: { $0.name.lowercased().hasSuffix(".pkg") })?
          .browser_download_url

        updateAvailable = Self.compareVersions(normalized, currentVersion) == .orderedDescending
        statusMessage =
          updateAvailable
          ? "LumaWall \(normalized) is available."
          : "LumaWall is up to date."
      } catch {
        statusMessage = "Could not check for updates: \(error.localizedDescription)"
      }
    }
  }

  func downloadAndOpenInstaller() {
    guard let installerURL, !isDownloading else {
      if installerURL == nil {
        openReleasePage()
      }
      return
    }

    isDownloading = true
    statusMessage = "Downloading update…"

    Task {
      defer { isDownloading = false }

      do {
        let (temporaryURL, response) = try await URLSession.shared.download(from: installerURL)
        let suggested =
          response.suggestedFilename
          ?? installerURL.lastPathComponent.nonEmpty
          ?? "LumaWall-Update.dmg"

        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let destination = Self.uniqueDestination(
          in: downloads,
          preferredName: suggested
        )

        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        statusMessage = "Update downloaded. Opening installer…"
        NSWorkspace.shared.open(destination)
      } catch {
        statusMessage = "Update download failed: \(error.localizedDescription)"
      }
    }
  }

  func openReleasePage() {
    guard let releasePageURL else { return }
    NSWorkspace.shared.open(releasePageURL)
  }

  private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let left = lhs.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    let right = rhs.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    let count = max(left.count, right.count)

    for index in 0..<count {
      let l = index < left.count ? left[index] : 0
      let r = index < right.count ? right[index] : 0
      if l < r { return .orderedAscending }
      if l > r { return .orderedDescending }
    }
    return .orderedSame
  }

  private static func uniqueDestination(in directory: URL, preferredName: String) -> URL {
    let ext = (preferredName as NSString).pathExtension
    let stem = (preferredName as NSString).deletingPathExtension

    var candidate = directory.appendingPathComponent(preferredName)
    var suffix = 2

    while FileManager.default.fileExists(atPath: candidate.path) {
      let name = ext.isEmpty ? "\(stem) \(suffix)" : "\(stem) \(suffix).\(ext)"
      candidate = directory.appendingPathComponent(name)
      suffix += 1
    }
    return candidate
  }
}

private extension String {
  var nonEmpty: String? { isEmpty ? nil : self }
}
