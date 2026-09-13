import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var model: AppModel
  var body: some View {
    Form {
      Section("Performance") {
        Toggle(
          "Pause for fullscreen apps",
          isOn: Binding(
            get: { model.governor.pauseForFullscreen },
            set: { model.governor.pauseForFullscreen = $0 }))
        Toggle(
          "Pause for games when detectable",
          isOn: Binding(
            get: { model.governor.pauseForGames }, set: { model.governor.pauseForGames = $0 }))
        Text("Low Power Mode and thermal throttling are always respected.").foregroundStyle(
          .secondary)
      }
      Section("Audio reactive wallpapers") {
        Toggle(
          "Capture system audio",
          isOn: Binding(
            get: { model.systemAudioEnabled },
            set: { enabled in model.setSystemAudioEnabled(enabled) }
          ))
        Text("Uses ScreenCaptureKit and excludes LumaWall's own process audio.").foregroundStyle(
          .secondary)
      }
      Section("Startup") {
        Toggle(
          "Launch LumaWall at login",
          isOn: Binding(
            get: { model.launchAtLogin.isEnabled },
            set: { v in
              do { try model.launchAtLogin.setEnabled(v) } catch {
                model.lastError = error.localizedDescription
              }
            }))
        Text("Launch-at-login works when LumaWall is installed as a signed macOS app bundle.")
          .foregroundStyle(.secondary)
      }
    }.padding(20).frame(width: 520)
  }
}
