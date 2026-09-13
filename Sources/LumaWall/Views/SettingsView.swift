import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    TabView {
      general
        .tabItem { Label("General", systemImage: "gearshape") }

      performance
        .tabItem { Label("Performance", systemImage: "gauge.with.dots.needle.67percent") }

      audio
        .tabItem { Label("Audio", systemImage: "waveform") }

      updates
        .tabItem { Label("Updates", systemImage: "arrow.down.circle") }

      recovery
        .tabItem { Label("Recovery", systemImage: "cross.case") }

      about
        .tabItem { Label("About", systemImage: "info.circle") }
    }
    .padding(20)
    .frame(width: 650, height: 560)
  }

  private var general: some View {
    Form {
      Section("Startup") {
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
      }

      Section("Library") {
        Button("Open Wallpaper Folder") {
          model.openLibraryFolder()
        }

        Button("Clear Recent History") {
          model.clearRecents()
        }

        Button("Reset All Creator Controls") {
          model.resetAllCreatorSettings()
        }
      }

      Section("Getting started") {
        Button("Show Welcome Guide") {
          model.reopenOnboarding()
        }

        Text(
          "LumaWall is a macOS-only app. Wallpaper importing, display setup, playlists, updates, diagnostics and recovery are all available from the app."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
  }

  private var performance: some View {
    Form {
      Section("Quality") {
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
      }

      Section("Automatic performance") {
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

        Text(
          "Critical thermal conditions can always pause rendering to protect system responsiveness."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
  }

  private var audio: some View {
    Form {
      Section("Audio-reactive wallpapers") {
        Toggle(
          "Capture system audio",
          isOn: Binding(
            get: { model.systemAudioEnabled },
            set: { model.setSystemAudioEnabled($0) }
          )
        )

        Text(
          "macOS will ask for Screen Recording permission the first time system-audio capture is enabled. LumaWall excludes its own process audio."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("Privacy") {
        Label(
          "Audio analysis stays on your Mac and is converted into level, bass, mids, treble and FFT spectrum data for active wallpapers.",
          systemImage: "lock.shield"
        )
        .font(.callout)
      }
    }
  }

  private var updates: some View {
    Form {
      Section("Software Update") {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Installed version")
            Text("LumaWall \(AppVersion.display)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button(model.updater.isChecking ? "Checking…" : "Check for Updates") {
            model.checkForUpdates()
          }
          .disabled(model.updater.isChecking)
        }

        if let latest = model.updater.latestVersion {
          LabeledContent("Latest release", value: latest)
        }

        Text(model.updater.statusMessage)
          .font(.callout)
          .foregroundStyle(model.updater.updateAvailable ? .primary : .secondary)

        if model.updater.updateAvailable {
          Button(model.updater.isDownloading ? "Downloading…" : "Download & Open Installer") {
            model.updater.downloadAndOpenInstaller()
          }
          .buttonStyle(.borderedProminent)
          .disabled(model.updater.isDownloading)
        } else if model.updater.latestVersion != nil {
          Button("View Release") {
            model.updater.openReleasePage()
          }
        }
      }

      Section("How updates work") {
        Text(
          "LumaWall checks the official GitHub Releases feed. When an update is available, the app downloads the macOS DMG or PKG to Downloads and opens it for installation."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
  }

  private var recovery: some View {
    Form {
      Section("Safe Mode") {
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

        Text(
          "Safe Mode starts LumaWall without automatically restoring the previous live wallpapers. Use it if a wallpaper causes repeated instability."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("Reset active rendering") {
        Button("Stop All Wallpapers & Clear Saved Assignments", role: .destructive) {
          model.stopAllAndClearAssignments()
        }

        Button("Open Diagnostics") {
          model.sidebarSelection = .diagnostics
          NSApp.activate(ignoringOtherApps: true)
          DispatchQueue.main.async {
            LumaWallAppDelegate.bringControlWindowForward()
          }
        }

        Button("Open macOS Crash Reports") {
          model.openCrashReportsFolder()
        }
      }

      if let error = model.lastError {
        Section("Last error") {
          Text(error)
            .textSelection(.enabled)
            .foregroundStyle(.red)
        }
      }
    }
  }

  private var about: some View {
    Form {
      Section {
        VStack(spacing: 12) {
          Image(systemName: "sparkles.rectangle.stack.fill")
            .font(.system(size: 58))
          Text("LumaWall")
            .font(.largeTitle.bold())
          Text("Native live wallpapers for macOS")
            .foregroundStyle(.secondary)
          Text("Version \(AppVersion.display)")
            .font(.caption.monospaced())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
      }

      Section("Platform") {
        LabeledContent("Operating system", value: "macOS 14 or later")
        LabeledContent("Renderer stack", value: "AppKit • SwiftUI • Metal • WebKit • AVFoundation")
        LabeledContent("Wallpaper package", value: ".wall v1")
      }

      Section("Support") {
        Button("Copy Diagnostic Report") {
          model.copyDiagnosticReport()
        }

        Button("Export Diagnostic Report…") {
          model.exportDiagnosticReport()
        }
      }
    }
  }
}
