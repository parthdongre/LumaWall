import Foundation

@MainActor
final class CrashQuarantineService {
  private let defaults: UserDefaults
  let crashThreshold: Int

  private enum Keys {
    static let cleanShutdown = "stability.cleanShutdown"
    static let activeWallpaperIDs = "stability.activeWallpaperIDs"
    static let crashCounts = "stability.crashCounts"
    static let quarantinedIDs = "stability.quarantinedIDs"
  }

  private(set) var previousLaunchWasClean: Bool
  private(set) var suspectedWallpaperIDs: Set<UUID>

  init(
    defaults: UserDefaults = .standard,
    crashThreshold: Int = 3
  ) {
    self.defaults = defaults
    self.crashThreshold = max(1, crashThreshold)

    let previousWasClean =
      defaults.object(forKey: Keys.cleanShutdown) as? Bool ?? true
    previousLaunchWasClean = previousWasClean

    let previousIDs = Self.loadIDs(
      defaults.stringArray(forKey: Keys.activeWallpaperIDs)
    )
    suspectedWallpaperIDs = previousWasClean ? [] : previousIDs

    if !previousWasClean {
      var counts = Self.loadCrashCounts(from: defaults)
      for id in previousIDs {
        counts[id, default: 0] += 1
      }
      Self.saveCrashCounts(counts, to: defaults)

      var quarantined = Self.loadIDs(
        defaults.stringArray(forKey: Keys.quarantinedIDs)
      )
      for (id, count) in counts where count >= self.crashThreshold {
        quarantined.insert(id)
      }
      Self.saveIDs(
        quarantined,
        key: Keys.quarantinedIDs,
        to: defaults
      )
    }

    defaults.set(false, forKey: Keys.cleanShutdown)
  }

  var quarantinedIDs: Set<UUID> {
    Self.loadIDs(
      defaults.stringArray(forKey: Keys.quarantinedIDs)
    )
  }

  func crashCount(for id: UUID) -> Int {
    crashCounts[id, default: 0]
  }

  func isQuarantined(_ id: UUID) -> Bool {
    quarantinedIDs.contains(id)
  }

  func recordActiveWallpaperIDs(_ ids: Set<UUID>) {
    Self.saveIDs(
      ids,
      key: Keys.activeWallpaperIDs,
      to: defaults
    )
  }

  func markStable(_ ids: Set<UUID>) {
    var counts = crashCounts
    for id in ids {
      counts[id] = 0
    }
    Self.saveCrashCounts(counts, to: defaults)
  }

  func allowAgain(_ id: UUID) {
    var quarantined = quarantinedIDs
    quarantined.remove(id)
    Self.saveIDs(
      quarantined,
      key: Keys.quarantinedIDs,
      to: defaults
    )

    var counts = crashCounts
    counts[id] = 0
    Self.saveCrashCounts(counts, to: defaults)
  }

  func resetHistory() {
    defaults.removeObject(forKey: Keys.crashCounts)
    defaults.removeObject(forKey: Keys.quarantinedIDs)
    defaults.removeObject(forKey: Keys.activeWallpaperIDs)
    previousLaunchWasClean = true
    suspectedWallpaperIDs = []
  }

  func markCleanShutdown() {
    defaults.set(true, forKey: Keys.cleanShutdown)
    recordActiveWallpaperIDs([])
  }

  private var crashCounts: [UUID: Int] {
    Self.loadCrashCounts(from: defaults)
  }

  private static func loadIDs(
    _ values: [String]?
  ) -> Set<UUID> {
    Set(values?.compactMap(UUID.init(uuidString:)) ?? [])
  }

  private static func saveIDs(
    _ ids: Set<UUID>,
    key: String,
    to defaults: UserDefaults
  ) {
    defaults.set(
      ids.map(\.uuidString).sorted(),
      forKey: key
    )
  }

  private static func loadCrashCounts(
    from defaults: UserDefaults
  ) -> [UUID: Int] {
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

  private static func saveCrashCounts(
    _ counts: [UUID: Int],
    to defaults: UserDefaults
  ) {
    defaults.set(
      Dictionary(
        uniqueKeysWithValues: counts.map {
          ($0.key.uuidString, $0.value)
        }
      ),
      forKey: Keys.crashCounts
    )
  }
}
