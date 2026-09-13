import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    Form {
      Section("General") {
        Toggle(
          "Restore wallpapers when LumaWall opens",
          isOn: Binding(
            get: { model.restoreAssignmentsOnLaunch },
            set: { model.setRestoreAssignmentsOnLaunch($0) }
          )
        )

        Toggle(
          "Launch LumaWall at login",
          isOn: Binding(
            get: { model.launchAtLogin.isEnabled },
            set: { enabled in
              do {
                try model.launchAtLogin.setEnabled(enabled)
              } catch {
                model.lastError = error.localizedDescription
              }
            }
          )
        )

        Text(
          "Launch at login becomes fully functional when LumaWall is installed as an app bundle in Applications."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("Rendering") {
        Picker(
          "Quality preset",
          selection: Binding(
            get: { model.qualityPreset },
            set: { model.applyQualityPreset($0) }
          )
        ) {
          ForEach(RenderQualityPreset.allCases) { preset in
            Text(preset.displayName)
              .tag(preset)
          }
        }

        Toggle(
          "Adaptive battery and thermal quality",
          isOn: Binding(
            get: { model.governor.adaptiveQualityEnabled },
            set: { model.setAdaptiveQualityEnabled($0) }
          )
        )

        Toggle(
          "Pause for fullscreen apps",
          isOn: Binding(
            get: { model.governor.pauseForFullscreen },
            set: { model.setPauseForFullscreen($0) }
          )
        )

        Toggle(
          "Pause for games when detectable",
          isOn: Binding(
            get: { model.governor.pauseForGames },
            set: { model.setPauseForGames($0) }
          )
        )

        HStack {
          Text("Preferred FPS")
          Spacer()
          Picker(
            "",
            selection: Binding(
              get: { model.targetFPS },
              set: { model.updateFPS($0) }
            )
          ) {
            Text("30").tag(30)
            Text("60").tag(60)
            Text("120").tag(120)
          }
          .labelsHidden()
          .pickerStyle(.segmented)
          .frame(width: 220)
        }

        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text("Preferred render scale")
            Spacer()
            Text("\(Int(model.renderScale * 100))%")
              .foregroundStyle(.secondary)
          }
          Slider(
            value: Binding(
              get: { model.renderScale },
              set: { model.updateRenderScale($0) }
            ),
            in: 0.25...1,
            step: 0.05
          )
        }

        Text(
          "Critical thermal state and fullscreen/game pause rules can still override the preferred quality."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("Audio-reactive wallpapers") {
        Toggle(
          "Capture system audio",
          isOn: Binding(
            get: { model.systemAudioEnabled },
            set: { model.setSystemAudioEnabled($0) }
          )
        )

        Text(
          "Uses ScreenCaptureKit, excludes LumaWall's own process audio, and only sends FFT data to wallpapers that have the system-audio capability."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("Library") {
        HStack {
          Button("Open Wallpaper Folder") {
            model.openLibraryFolder()
          }

          Button("Clear Recent History") {
            model.clearRecents()
          }

          Button("Reset Creator Controls") {
            model.resetAllCreatorSettings()
          }
        }

        Text(model.applicationSupportPath)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }

      Section("Recovery") {
        if model.isSafeMode {
          Label(
            "Safe Mode is active. Saved wallpaper assignments were not restored.",
            systemImage: "shield.fill"
          )
          .foregroundStyle(.orange)
        }

        Button("Use Safe Mode on Next Launch") {
          model.enableSafeModeForNextLaunch()
        }

        Button("Stop All Wallpapers & Clear Assignments", role: .destructive) {
          model.stopAllAndClearAssignments()
        }

        Button("Open Diagnostics") {
          model.sidebarSelection = .diagnostics
          NSApp.activate(ignoringOtherApps: true)
          DispatchQueue.main.async {
            LumaWallAppDelegate.bringControlWindowForward()
          }
        }

        Text(
          "You can also launch from Terminal with “LumaWall --safe-mode” to skip wallpaper restoration for that run."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("About") {
        LabeledContent("Version", value: AppVersion.display)
        LabeledContent("Minimum macOS", value: "14.0")
        LabeledContent("Wallpaper package format", value: ".wall v1")
      }
    }
    .padding(20)
    .frame(width: 620, height: 720)
  }
}
