import Foundation

@MainActor
final class SystemSuspensionCoordinator {
  enum Reason: String, CaseIterable, Hashable, Sendable {
    case systemSleep
    case screensSleep
    case sessionInactive

    var displayName: String {
      switch self {
      case .systemSleep:
        return "System sleep"
      case .screensSleep:
        return "Displays asleep"
      case .sessionInactive:
        return "User session inactive"
      }
    }
  }

  private(set) var activeReasons: Set<Reason> = []
  var onChanged: ((Bool) -> Void)?

  var isSuspended: Bool {
    !activeReasons.isEmpty
  }

  func set(_ reason: Reason, active: Bool) {
    let wasSuspended = isSuspended

    if active {
      activeReasons.insert(reason)
    } else {
      activeReasons.remove(reason)
    }

    let nowSuspended = isSuspended
    if wasSuspended != nowSuspended {
      onChanged?(nowSuspended)
    }
  }

  func clear() {
    let wasSuspended = isSuspended
    activeReasons.removeAll()

    if wasSuspended {
      onChanged?(false)
    }
  }
}
