import CoreGraphics
import Foundation

struct FullscreenDisplayGeometry: Hashable, Sendable {
  let id: CGDirectDisplayID
  let bounds: CGRect
}

struct ForegroundWindowGeometry: Sendable {
  let ownerPID: Int32
  let layer: Int
  let bounds: CGRect
  let alpha: Double
}

enum FullscreenDetection {
  /// CoreGraphics occasionally reports a fullscreen surface a pixel or two
  /// outside the display bounds. Keep this deliberately small: a normal
  /// maximized macOS window must not count as fullscreen just because it covers
  /// most of the display.
  static let edgeTolerance: CGFloat = 6

  static func matchingDisplayIDs(
    windows: [ForegroundWindowGeometry],
    frontmostPID: Int32,
    ownPID: Int32,
    displays: [FullscreenDisplayGeometry]
  ) -> Set<CGDirectDisplayID> {
    guard frontmostPID > 0, frontmostPID != ownPID else {
      return []
    }

    var result = Set<CGDirectDisplayID>()

    for window in windows {
      guard
        window.ownerPID == frontmostPID,
        window.layer == 0,
        window.alpha > 0.01,
        window.bounds.width > 0,
        window.bounds.height > 0
      else {
        continue
      }

      for display in displays where matchesDisplay(
        window.bounds,
        displayBounds: display.bounds
      ) {
        result.insert(display.id)
      }
    }

    return result
  }

  static func matchesDisplay(
    _ windowBounds: CGRect,
    displayBounds: CGRect,
    tolerance: CGFloat = edgeTolerance
  ) -> Bool {
    guard
      windowBounds.width > 0,
      windowBounds.height > 0,
      displayBounds.width > 0,
      displayBounds.height > 0
    else {
      return false
    }

    // Fullscreen means the window actually reaches all four display edges.
    // Area coverage alone is intentionally not used. On a 2940x1912 MacBook
    // display, a normal maximized window below a 50 px menu bar still covers
    // about 97.4% of the screen and was the source of the observed false pause.
    return
      abs(windowBounds.minX - displayBounds.minX) <= tolerance
      && abs(windowBounds.minY - displayBounds.minY) <= tolerance
      && abs(windowBounds.maxX - displayBounds.maxX) <= tolerance
      && abs(windowBounds.maxY - displayBounds.maxY) <= tolerance
  }
}

struct FullscreenPauseDebouncer {
  private(set) var committed = Set<CGDirectDisplayID>()
  private var pending = Set<CGDirectDisplayID>()
  private var pendingSamples = 0

  /// Entering fullscreen requires two consistent observations to avoid
  /// transition/animation jitter. Exiting fullscreen resumes immediately so a
  /// stale pause can never linger after switching apps or Spaces.
  mutating func ingest(
    _ candidate: Set<CGDirectDisplayID>
  ) -> Set<CGDirectDisplayID>? {
    if candidate == committed {
      pending = candidate
      pendingSamples = 0
      return nil
    }

    if candidate.isEmpty {
      pending = []
      pendingSamples = 0
      committed = []
      return committed
    }

    if candidate == pending {
      pendingSamples += 1
    } else {
      pending = candidate
      pendingSamples = 1
    }

    guard pendingSamples >= 2 else {
      return nil
    }

    committed = candidate
    pendingSamples = 0
    return committed
  }

  mutating func reset() {
    committed = []
    pending = []
    pendingSamples = 0
  }
}
