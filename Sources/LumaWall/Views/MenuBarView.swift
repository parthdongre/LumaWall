import SwiftUI

struct MenuBarView: View {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("LumaWall")
            .font(.headline)
          Text(statusText)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(
          systemName: model.governor.foregroundActivity.isFullscreen
            ? "pause.circle.fill"
            : "sparkles.rectangle.stack.fill"
        )
        .font(.title2)
      }

      Divider()

      Button {
        model.togglePause()
      } label: {
        Label(
          model.isPaused ? "Resume Wallpapers" : "Pause Wallpapers",
          systemImage: model.isPaused ? "play.fill" : "pause.fill"
        )
      }

      if !model.recentWallpapers.isEmpty {
        Menu("Switch Wallpaper") {
          ForEach(model.recentWallpapers.prefix(8)) { wallpaper in
            Button(wallpaper.name) {
              model.applyWallpaper(id: wallpaper.id, to: nil)
            }
          }
        }
      }

      Menu("Quality: \(model.qualityPreset.displayName)") {
        ForEach(RenderQualityPreset.allCases.filter { $0 != .custom }) { preset in
          Button(preset.displayName) {
            model.applyQualityPreset(preset)
          }
        }
      }

      Toggle(
        "System audio",
        isOn: Binding(
          get: { model.systemAudioEnabled },
          set: { model.setSystemAudioEnabled($0) }
        )
      )

      Divider()

      Button {
        openMainWindow()
      } label: {
        Label("Open LumaWall", systemImage: "macwindow")
      }

      Button {
        model.sidebarSelection = .library(.favorites)
        openMainWindow()
      } label: {
        Label("Favorites", systemImage: "star")
      }

      Button {
        model.stopWallpapers(on: nil)
      } label: {
        Label("Stop All Wallpapers", systemImage: "stop.fill")
      }

      Divider()

      Button("Quit LumaWall") {
        model.shutdown()
        DispatchQueue.main.async {
          NSApp.terminate(nil)
        }
      }
    }
    .padding(12)
    .frame(width: 280)
  }

  private var statusText: String {
    if model.isSafeMode {
      return "Safe Mode"
    }
    if model.isPaused {
      return "Paused"
    }
    if model.governor.foregroundActivity.isFullscreen {
      return "Auto-paused for fullscreen"
    }
    if let app = model.governor.foregroundActivity.ownerName,
      model.governor.foregroundActivity.isGame
    {
      return "Game detected: \(app)"
    }
    return "\(model.activeWallpaperIDs.count) active • \(model.targetFPS) FPS"
  }

  private func openMainWindow() {
    openWindow(id: "main")
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.async {
      LumaWallAppDelegate.bringControlWindowForward()
    }
  }
}
