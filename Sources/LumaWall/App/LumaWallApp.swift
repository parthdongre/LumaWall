import SwiftUI

@main
struct LumaWallApp: App {
  @NSApplicationDelegateAdaptor(LumaWallAppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel()

  var body: some Scene {
    Window("LumaWall", id: "main") {
      ContentView()
        .environmentObject(model)
        .frame(minWidth: 980, minHeight: 640)
        .sheet(
          isPresented: Binding(
            get: { model.showOnboarding },
            set: { model.showOnboarding = $0 }
          )
        ) {
          OnboardingView()
            .environmentObject(model)
        }
    }
    .defaultSize(width: 1180, height: 760)
    .windowResizability(.contentMinSize)
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

        Button("Import Wallpaper Engine Project…") {
          model.chooseWallpaperEngineProject()
        }

        Button("Creator Studio") {
          model.sidebarSelection = .creator
        }
      }
    }

    MenuBarExtra {
      MenuBarView()
        .environmentObject(model)
    } label: {
      Label(
        "LumaWall",
        systemImage: model.updater.updateAvailable
          ? "arrow.down.circle.fill"
          : "sparkles.rectangle.stack"
      )
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
        .environmentObject(model)
    }
  }
}
