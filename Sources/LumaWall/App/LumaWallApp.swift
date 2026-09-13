import SwiftUI

@main
struct LumaWallApp: App {
  @StateObject private var model = AppModel()

  var body: some Scene {
    WindowGroup("LumaWall") {
      ContentView()
        .environmentObject(model)
        .frame(minWidth: 980, minHeight: 640)
    }

    MenuBarExtra("LumaWall", systemImage: "sparkles.rectangle.stack") {
      MenuBarView()
        .environmentObject(model)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
        .environmentObject(model)
    }
  }
}
