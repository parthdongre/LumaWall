import Combine
import Foundation
import IOKit.ps

enum MacPowerSource: String, Codable, Sendable {
  case ac
  case battery
  case unknown

  var displayName: String {
    switch self {
    case .ac: return "Power Adapter"
    case .battery: return "Battery"
    case .unknown: return "Unknown"
    }
  }
}

struct BatterySnapshot: Equatable, Sendable {
  var source: MacPowerSource
  var percent: Int?
  var isCharging: Bool
}

@MainActor
final class PowerSourceMonitor: ObservableObject {
  @Published private(set) var snapshot = BatterySnapshot(
    source: .unknown,
    percent: nil,
    isCharging: false
  )

  private var timer: Timer?

  func start() {
    refresh()
    timer?.invalidate()
    timer = .scheduledTimer(
      withTimeInterval: 10,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor in
        self?.refresh()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  func refresh() {
    guard
      let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let sources =
        IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
    else {
      snapshot = BatterySnapshot(
        source: .unknown,
        percent: nil,
        isCharging: false
      )
      return
    }

    let providing =
      IOPSGetProvidingPowerSourceType(info)?
        .takeUnretainedValue() as String?

    let source: MacPowerSource
    if providing == kIOPSACPowerValue {
      source = .ac
    } else if providing == kIOPSBatteryPowerValue {
      source = .battery
    } else {
      source = .unknown
    }

    var percent: Int?
    var charging = false

    for item in sources {
      guard
        let description =
          IOPSGetPowerSourceDescription(info, item)?
            .takeUnretainedValue() as? [String: Any]
      else {
        continue
      }

      if let current =
        description[kIOPSCurrentCapacityKey] as? Int,
        let maximum =
          description[kIOPSMaxCapacityKey] as? Int,
        maximum > 0
      {
        percent = Int(
          (
            Double(current) / Double(maximum) * 100
          ).rounded()
        )
      }

      charging =
        description[kIOPSIsChargingKey] as? Bool
        ?? charging
    }

    snapshot = BatterySnapshot(
      source: source,
      percent: percent,
      isCharging: charging
    )
  }
}
