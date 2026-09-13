import SwiftUI

@main
struct LumaWallApp: App {
  @NSApplicationDelegateAdaptor(LumaWallAppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel()

  var body: some Scene {
    WindowGroup("LumaWall", id: "main") {
      ContentView()
        .environmentObject(model)
        .frame(minWidth: 980, minHeight: 640)
    }
    .commands {
      CommandMenu("Wallpaper") {
        Button(model.isPaused ? "Resume Wallpapers" : "Pause Wallpapers") {
          model.togglePause()
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])

        Button("Stop All Wallpapers") {
          model.stopWallpapers(on: nil)
        }
        .keyboardShortcut(".", modifiers: [.command, .shift])

        Divider()

        Button("Library") {
          model.sidebarSelection = .library(.all)
        }
        .keyboardShortcut("1", modifiers: .command)

        Button("Favorites") {
          model.sidebarSelection = .library(.favorites)
        }
        .keyboardShortcut("2", modifiers: .command)

        Button("Recent") {
          model.sidebarSelection = .library(.recent)
        }
        .keyboardShortcut("3", modifiers: .command)

        Divider()

        Button("Import Wallpaper…") {
          model.importWallpaper()
        }
        .keyboardShortcut("o", modifiers: [.command, .shift])
      }
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
