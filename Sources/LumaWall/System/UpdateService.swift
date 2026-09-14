import AppKit
import Combine
import CryptoKit
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

private enum UpdateIntegrityError: LocalizedError {
  case missingChecksums
  case missingChecksumEntry(String)
  case checksumMismatch

  var errorDescription: String? {
    switch self {
    case .missingChecksums:
      return "This release is missing SHA-256 checksums, so LumaWall will not open the installer automatically."
    case .missingChecksumEntry(let name):
      return "The release checksum file does not contain an entry for \(name)."
    case .checksumMismatch:
      return "The downloaded installer failed SHA-256 verification and was not opened."
    }
  }
}

@MainActor
final class UpdateService: ObservableObject {
  @Published private(set) var isChecking = false
  @Published private(set) var isDownloading = false
  @Published private(set) var latestVersion: String?
  @Published private(set) var updateAvailable = false
  @Published private(set) var lastCheckedAt: Date?
  @Published private(set) var statusMessage = "Updates have not been checked yet."
  @Published var automaticallyChecksForUpdates: Bool {
    didSet {
      defaults.set(automaticallyChecksForUpdates, forKey: Keys.automaticChecks)
    }
  }

  private var installerURL: URL?
  private var installerAssetName: String?
  private var checksumURL: URL?
  private var releasePageURL: URL?
  private let defaults: UserDefaults

  private enum Keys {
    static let automaticChecks = "updates.automaticChecks"
    static let lastCheckedAt = "updates.lastCheckedAt"
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    automaticallyChecksForUpdates =
      defaults.object(forKey: Keys.automaticChecks) as? Bool
      ?? true
    lastCheckedAt = defaults.object(forKey: Keys.lastCheckedAt) as? Date
  }

  func performAutomaticCheckIfNeeded(currentVersion: String) {
    guard automaticallyChecksForUpdates, !isChecking else { return }

    if let lastCheckedAt,
      Date().timeIntervalSince(lastCheckedAt) < 24 * 60 * 60
    {
      return
    }

    checkForUpdates(currentVersion: currentVersion)
  }

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
          installerAssetName = nil
          checksumURL = nil
          releasePageURL = nil
          recordSuccessfulCheck()
          statusMessage = "No public LumaWall release has been published yet."
          return
        }

        guard (200...299).contains(http.statusCode) else {
          throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let normalized = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let installerAsset =
          release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
          ?? release.assets.first(where: { $0.name.lowercased().hasSuffix(".pkg") })

        latestVersion = normalized
        releasePageURL = release.html_url
        installerURL = installerAsset?.browser_download_url
        installerAssetName = installerAsset?.name
        checksumURL =
          release.assets.first(where: {
            $0.name.caseInsensitiveCompare("SHA256SUMS.txt") == .orderedSame
          })?.browser_download_url

        updateAvailable = Self.compareVersions(normalized, currentVersion) == .orderedDescending
        recordSuccessfulCheck()

        if updateAvailable, installerAsset == nil {
          statusMessage = "LumaWall \(normalized) is available, but this release has no macOS installer."
        } else if updateAvailable, checksumURL == nil {
          statusMessage = "LumaWall \(normalized) is available, but its installer cannot be verified automatically."
        } else {
          statusMessage =
            updateAvailable
            ? "LumaWall \(normalized) is available."
            : "LumaWall is up to date."
        }
      } catch {
        statusMessage = "Could not check for updates: \(error.localizedDescription)"
      }
    }
  }

  func downloadAndOpenInstaller() {
    guard let installerURL, let installerAssetName, !isDownloading else {
      if installerURL == nil {
        openReleasePage()
      }
      return
    }

    guard let checksumURL else {
      statusMessage = UpdateIntegrityError.missingChecksums.localizedDescription
      return
    }

    isDownloading = true
    statusMessage = "Downloading update…"

    Task {
      defer { isDownloading = false }

      do {
        let (temporaryURL, response) = try await URLSession.shared.download(from: installerURL)
        try Self.requireSuccessfulHTTPResponse(response)

        statusMessage = "Verifying update integrity…"

        let (checksumData, checksumResponse) = try await URLSession.shared.data(from: checksumURL)
        try Self.requireSuccessfulHTTPResponse(checksumResponse)

        guard let checksumText = String(data: checksumData, encoding: .utf8),
          let expectedChecksum = Self.checksum(
            named: installerAssetName,
            from: checksumText
          )
        else {
          throw UpdateIntegrityError.missingChecksumEntry(installerAssetName)
        }

        let actualChecksum = try await Task.detached(priority: .utility) {
          try Self.sha256Hex(of: temporaryURL)
        }.value

        guard actualChecksum.caseInsensitiveCompare(expectedChecksum) == .orderedSame else {
          try? FileManager.default.removeItem(at: temporaryURL)
          throw UpdateIntegrityError.checksumMismatch
        }

        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let destination = Self.uniqueDestination(
          in: downloads,
          preferredName: installerAssetName
        )

        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        statusMessage = "Update verified. Opening installer…"
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

  nonisolated static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
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

  nonisolated static func checksum(named fileName: String, from manifest: String) -> String? {
    let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")

    for rawLine in manifest.split(whereSeparator: \.isNewline) {
      let parts = rawLine.split(maxSplits: 1, whereSeparator: \.isWhitespace)
      guard parts.count == 2 else { continue }

      let hash = String(parts[0])
      guard hash.count == 64,
        hash.unicodeScalars.allSatisfy({ hexCharacters.contains($0) })
      else {
        continue
      }

      var listedName = String(parts[1]).trimmingCharacters(in: .whitespaces)
      if listedName.hasPrefix("*") {
        listedName.removeFirst()
      }

      if listedName == fileName {
        return hash.lowercased()
      }
    }

    return nil
  }

  nonisolated static func sha256Hex(of url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }

    var hasher = SHA256()

    while true {
      let data = try handle.read(upToCount: 1_048_576) ?? Data()
      if data.isEmpty { break }
      hasher.update(data: data)
    }

    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  private func recordSuccessfulCheck() {
    let now = Date()
    lastCheckedAt = now
    defaults.set(now, forKey: Keys.lastCheckedAt)
  }

  nonisolated private static func requireSuccessfulHTTPResponse(_ response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse,
      (200...299).contains(http.statusCode)
    else {
      throw URLError(.badServerResponse)
    }
  }

  nonisolated private static func uniqueDestination(
    in directory: URL,
    preferredName: String
  ) -> URL {
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
