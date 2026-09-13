import Foundation

@MainActor
final class CrashQuarantineService {
  private let defaults = UserDefaults.standard
  private let crashThreshold = 3

  private enum Keys {
    static let cleanShutdown = "stability.cleanShutdown"
    static let activeWallpaperIDs = "stability.activeWallpaperIDs"
    static let crashCounts = "stability.crashCounts"
    static let quarantinedIDs = "stability.quarantinedIDs"
  }

  init() {
    let previousWasClean =
      defaults.object(forKey: Keys.cleanShutdown) as? Bool ?? true

    if !previousWasClean {
      var counts = crashCounts
      for id in previouslyActiveWallpaperIDs {
        counts[id, default: 0] += 1
      }
      saveCrashCounts(counts)

      var quarantined = quarantinedIDs
      for (id, count) in counts where count >= crashThreshold {
        quarantined.insert(id)
      }
      saveQuarantinedIDs(quarantined)
    }

    defaults.set(false, forKey: Keys.cleanShutdown)
  }

  var quarantinedIDs: Set<UUID> {
    Set(
      defaults.stringArray(forKey: Keys.quarantinedIDs)?
        .compactMap(UUID.init(uuidString:))
        ?? []
    )
  }

  func isQuarantined(_ id: UUID) -> Bool {
    quarantinedIDs.contains(id)
  }

  func recordActiveWallpaperIDs(_ ids: Set<UUID>) {
    defaults.set(
      ids.map(\.uuidString).sorted(),
      forKey: Keys.activeWallpaperIDs
    )
  }

  func markStable(_ ids: Set<UUID>) {
    var counts = crashCounts
    for id in ids {
      counts[id] = 0
    }
    saveCrashCounts(counts)
  }

  func allowAgain(_ id: UUID) {
    var quarantined = quarantinedIDs
    quarantined.remove(id)
    saveQuarantinedIDs(quarantined)

    var counts = crashCounts
    counts[id] = 0
    saveCrashCounts(counts)
  }

  func markCleanShutdown() {
    defaults.set(true, forKey: Keys.cleanShutdown)
    recordActiveWallpaperIDs([])
  }

  private var previouslyActiveWallpaperIDs: Set<UUID> {
    Set(
      defaults.stringArray(forKey: Keys.activeWallpaperIDs)?
        .compactMap(UUID.init(uuidString:))
        ?? []
    )
  }

  private var crashCounts: [UUID: Int] {
    guard
      let dictionary =
        defaults.dictionary(forKey: Keys.crashCounts) as? [String: Int]
    else {
      return [:]
    }

    return dictionary.reduce(into: [:]) { result, element in
      if let id = UUID(uuidString: element.key) {
        result[id] = element.value
      }
    }
  }

  private func saveCrashCounts(_ counts: [UUID: Int]) {
    defaults.set(
      Dictionary(
        uniqueKeysWithValues: counts.map {
          ($0.key.uuidString, $0.value)
        }
      ),
      forKey: Keys.crashCounts
    )
  }

  private func saveQuarantinedIDs(_ ids: Set<UUID>) {
    defaults.set(
      ids.map(\.uuidString).sorted(),
      forKey: Keys.quarantinedIDs
    )
  }
}
