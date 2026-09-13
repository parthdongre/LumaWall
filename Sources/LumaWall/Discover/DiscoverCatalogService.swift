import Combine
import CryptoKit
import Foundation

@MainActor
final class DiscoverCatalogService: ObservableObject {
  @Published private(set) var items: [DiscoverWallpaperListing] = []
  @Published private(set) var isLoading = false
  @Published private(set) var lastError: String?
  @Published private(set) var lastUpdated: Date?

  private let defaults = UserDefaults.standard
  private let endpointKey = "discover.catalogURL"
  private let maximumDownloadBytes: Int64 = 1_073_741_824

  var endpointString: String {
    defaults.string(forKey: endpointKey) ?? ""
  }

  func setEndpoint(_ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    defaults.set(trimmed, forKey: endpointKey)

    if trimmed.isEmpty {
      items = []
      lastError = nil
      lastUpdated = nil
    }
  }

  func refresh() async {
    guard !isLoading else { return }

    guard
      let url = URL(string: endpointString),
      !endpointString.isEmpty
    else {
      items = []
      lastError = nil
      return
    }

    do {
      try validateRemoteURL(url)

      isLoading = true
      defer { isLoading = false }

      var request = URLRequest(url: url)
      request.cachePolicy = .reloadRevalidatingCacheData
      request.timeoutInterval = 20

      let (data, response) = try await URLSession.shared.data(for: request)

      if
        let http = response as? HTTPURLResponse,
        !(200..<300).contains(http.statusCode)
      {
        throw URLError(.badServerResponse)
      }

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601

      let catalog: DiscoverCatalog
      do {
        catalog = try decoder.decode(DiscoverCatalog.self, from: data)
      } catch {
        throw DiscoverCatalogError.invalidCatalog
      }

      guard catalog.formatVersion == 1 else {
        throw DiscoverCatalogError.invalidCatalog
      }

      for item in catalog.items {
        try validateRemoteURL(item.packageURL)
        if let previewURL = item.previewURL {
          try validateRemoteURL(previewURL)
        }
      }

      items = catalog.items
      lastUpdated = Date()
      lastError = nil
    } catch {
      items = []
      lastError = error.localizedDescription
    }
  }

  func loadLocalCatalog(from url: URL) throws {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    guard
      let catalog = try? decoder.decode(DiscoverCatalog.self, from: data),
      catalog.formatVersion == 1
    else {
      throw DiscoverCatalogError.invalidCatalog
    }

    items = catalog.items
    lastUpdated = Date()
    lastError = nil
  }

  func download(
    _ listing: DiscoverWallpaperListing
  ) async throws -> URL {
    try validateRemoteURL(listing.packageURL)

    let (temporaryURL, response) = try await URLSession.shared.download(
      from: listing.packageURL
    )

    if
      let http = response as? HTTPURLResponse,
      !(200..<300).contains(http.statusCode)
    {
      throw URLError(.badServerResponse)
    }

    let resource = try temporaryURL.resourceValues(
      forKeys: [.fileSizeKey]
    )

    if Int64(resource.fileSize ?? 0) > maximumDownloadBytes {
      throw DiscoverCatalogError.packageTooLarge
    }

    if
      let expected = listing.sha256?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased(),
      !expected.isEmpty
    {
      let actual = try sha256(of: temporaryURL)
      guard actual == expected else {
        throw DiscoverCatalogError.checksumMismatch
      }
    }

    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent("LumaWall-Discover-\(UUID().uuidString)")
      .appendingPathExtension("wall")

    try? FileManager.default.removeItem(at: destination)
    try FileManager.default.copyItem(
      at: temporaryURL,
      to: destination
    )

    return destination
  }

  private func validateRemoteURL(_ url: URL) throws {
    guard url.scheme?.lowercased() == "https" else {
      throw DiscoverCatalogError.insecureURL
    }
  }

  private func sha256(of fileURL: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: fileURL)
    defer { try? handle.close() }

    var hasher = SHA256()

    while true {
      let data = try handle.read(upToCount: 1_048_576) ?? Data()
      if data.isEmpty { break }
      hasher.update(data: data)
    }

    return hasher.finalize()
      .map { String(format: "%02x", $0) }
      .joined()
  }
}
