import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
  @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled
  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
    isEnabled = SMAppService.mainApp.status == .enabled
  }
  func refresh() { isEnabled = SMAppService.mainApp.status == .enabled }
}
