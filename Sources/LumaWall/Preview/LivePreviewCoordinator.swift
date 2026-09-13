import Combine
import Foundation

@MainActor
final class LivePreviewCoordinator: ObservableObject {
  @Published private(set) var activeWallpaperID: UUID?

  private var pendingTask: Task<Void, Never>?
  private let hoverDelayNanoseconds: UInt64

  init(hoverDelayNanoseconds: UInt64 = 450_000_000) {
    self.hoverDelayNanoseconds = hoverDelayNanoseconds
  }

  func hover(_ wallpaperID: UUID) {
    if activeWallpaperID == wallpaperID {
      return
    }

    pendingTask?.cancel()

    pendingTask = Task { @MainActor [weak self] in
      guard let self else { return }

      do {
        try await Task.sleep(
          nanoseconds: hoverDelayNanoseconds
        )
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      activeWallpaperID = wallpaperID
    }
  }

  func leave(_ wallpaperID: UUID) {
    pendingTask?.cancel()
    pendingTask = nil

    if activeWallpaperID == wallpaperID {
      activeWallpaperID = nil
    }
  }

  func stop() {
    pendingTask?.cancel()
    pendingTask = nil
    activeWallpaperID = nil
  }
}
