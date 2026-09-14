import Combine
import CoreGraphics
import Foundation

@MainActor
final class ScreenCapturePermissionService: ObservableObject {
  @Published private(set) var isGranted: Bool

  private let preflight: () -> Bool
  private let requestAccess: () -> Bool

  init(
    preflight: @escaping () -> Bool = { CGPreflightScreenCaptureAccess() },
    requestAccess: @escaping () -> Bool = { CGRequestScreenCaptureAccess() }
  ) {
    self.preflight = preflight
    self.requestAccess = requestAccess
    isGranted = preflight()
  }

  func refresh() {
    isGranted = preflight()
  }

  @discardableResult
  func request() -> Bool {
    let requested = requestAccess()
    let granted = requested || preflight()
    isGranted = granted
    return granted
  }
}
