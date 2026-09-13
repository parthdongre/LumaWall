import SwiftUI

struct MenuBarView: View {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var model: AppModel
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("LumaWall").font(.headline)
        Spacer()
        Text(model.governor.foregroundActivity.isFullscreen ? "Auto-paused" : "Active").font(
          .caption
        ).foregroundStyle(.secondary)
      }
      Button(model.isPaused ? "Resume Wallpapers" : "Pause Wallpapers") { model.togglePause() }
      Menu("FPS: \(model.targetFPS)") {
        ForEach([30, 60, 120], id: \.self) { fps in Button("\(fps) FPS") { model.updateFPS(fps) } }
      }
      Toggle(
        "System audio",
        isOn: Binding(
          get: { model.systemAudioEnabled },
          set: { enabled in model.setSystemAudioEnabled(enabled) }
        ))
      Divider()
      Button("Open LumaWall") {
        openWindow(id: "main")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
          LumaWallAppDelegate.bringControlWindowForward()
        }
      }
      Button("Quit") {
        model.shutdown()
        DispatchQueue.main.async {
          NSApp.terminate(nil)
        }
      }
    }.padding(12).frame(width: 250)
  }
}
