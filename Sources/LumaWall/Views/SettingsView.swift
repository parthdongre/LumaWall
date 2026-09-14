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
      Section("This Mac") {
        HStack(spacing: 14) {
          Image(systemName: model.hardwareProfile.isPortable ? "laptopcomputer" : "desktopcomputer")
            .font(.system(size: 32))
            .frame(width: 44)

          VStack(alignment: .leading, spacing: 3) {
            Text(model.hardwareProfile.deviceFamily)
              .font(.headline)
            Text(model.hardwareProfile.chipName)
              .foregroundStyle(.secondary)
            Text(
              "\(model.hardwareProfile.modelIdentifier) • \(model.hardwareProfile.memoryGB) GB • \(model.hardwareProfile.processorCount) CPU cores"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }

          Spacer()

          Button("Optimize") {
            model.applyHardwareRecommendation()
          }
        }

        Text(model.hardwareProfile.explanation)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Resolution") {
        Toggle(
          "Maximum Resolution",
          isOn: Binding(
            get: { model.maximumResolutionEnabled },
            set: { model.setMaximumResolutionEnabled($0) }
          )
        )

        Text(
          model.maximumResolutionEnabled
            ? "Wallpapers render at each display's native backing-pixel resolution. Battery/thermal adaptation lowers FPS before resolution."
            : "Dynamic/manual render scaling is allowed to reduce GPU work."
        )
        .font(.caption)
        .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text("Render scale")
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
          .disabled(model.maximumResolutionEnabled)
        }

        ForEach(model.displays) { display in
          HStack {
            Text(display.name)
            Spacer()
            Text(
              model.maximumResolutionEnabled
                ? display.nativeResolutionLabel
                : "\(Int(display.nativePixelSize.width * model.renderScale)) × \(Int(display.nativePixelSize.height * model.renderScale))"
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
          }
        }

        Text(
          "Native resolution sets the render target. Image and video sharpness is still limited by the source file's own pixel resolution."
        )
        .font(.caption2)
        .foregroundStyle(.tertiary)
      }

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

        if model.qualityPreset == .automatic {
          Label(
            "Automatic is currently targeting \(model.targetFPS) FPS at native resolution.",
            systemImage: "sparkles"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }

      Section("Wallpaper transitions") {
        Picker(
          "Transition",
          selection: Binding(
            get: { model.transitionStyle },
            set: { model.setTransitionStyle($0) }
          )
        ) {
          ForEach(WallpaperTransitionStyle.allCases) { style in
            Text(style.displayName)
              .tag(style)
          }
        }

        HStack {
          Text("Duration")
          Slider(
            value: Binding(
              get: { model.transitionDuration },
              set: { model.setTransitionDuration($0) }
            ),
            in: 0...3,
            step: 0.1
          )
          Text(String(format: "%.1fs", model.transitionDuration))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 44)
        }

        Text(
          "Crossfade and Soft Zoom keep the old renderer alive until the incoming wallpaper is visible, then retire it safely."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("Power profiles") {
        Toggle(
          "Use automatic power profiles",
          isOn: Binding(
            get: { model.usePowerProfiles },
            set: { model.setUsePowerProfiles($0) }
          )
        )

        LabeledContent(
          "Current power source",
          value: model.power.snapshot.source.displayName
        )

        if let percent = model.power.snapshot.percent {
          LabeledContent(
            "Battery",
            value: "\(percent)%"
          )
        }

        powerProfileRow(
          title: "Plugged In",
          profile: model.pluggedInProfile,
          source: .ac
        )

        powerProfileRow(
          title: "Battery",
          profile: model.batteryProfile,
          source: .battery
        )

        powerProfileRow(
          title: "Low Power Mode",
          profile: model.lowPowerProfile,
          source: .battery,
          lowPower: true
        )
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
          "Live wallpaper previews in Library",
          isOn: Binding(
            get: { model.livePreviewsEnabled },
            set: { model.setLivePreviewsEnabled($0) }
          )
        )

        Text(
          "Live previews are delayed, limited to one renderer at a time, capped at 30 FPS and disabled while macOS Low Power Mode is active."
        )
        .font(.caption)
        .foregroundStyle(.secondary)

        Toggle(
          "Experimental workload-aware adaptation",
          isOn: Binding(
            get: { model.governor.experimentalLoadAdaptationEnabled },
            set: { model.setExperimentalAdaptiveRenderingEnabled($0) }
          )
        )

        if model.governor.experimentalLoadAdaptationEnabled {
          LabeledContent(
            "Measured renderer pressure",
            value: String(describing: model.governor.loadPressure).capitalized
          )
        }

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
          "With Maximum Resolution enabled, adaptive mode preserves native pixels and reduces frame rate first. Critical thermal conditions can still pause rendering."
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

        Toggle(
          "Automatically check for updates",
          isOn: $model.updater.automaticallyChecksForUpdates
        )

        if let lastCheckedAt = model.updater.lastCheckedAt {
          LabeledContent(
            "Last checked",
            value: lastCheckedAt.formatted(date: .abbreviated, time: .shortened)
          )
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
          "LumaWall checks the official GitHub Releases feed. Automatic checks run at most once per day. Before an update installer is opened, LumaWall verifies it against the release's SHA-256 checksum."
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

      Section("Crash quarantine") {
        let quarantined = model.wallpapers.filter {
          model.isQuarantined($0.id)
        }

        if quarantined.isEmpty {
          Label(
            "No quarantined wallpapers",
            systemImage: "checkmark.shield"
          )
          .foregroundStyle(.secondary)
        } else {
          ForEach(quarantined) { wallpaper in
            HStack {
              VStack(alignment: .leading) {
                Text(wallpaper.name)
                Text("Disabled after repeated unclean exits")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Spacer()

              Button("Re-enable") {
                model.allowQuarantinedWallpaper(wallpaper.id)
              }
            }
          }
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

  @ViewBuilder
  private func powerProfileRow(
    title: String,
    profile: PowerPerformanceProfile,
    source: MacPowerSource,
    lowPower: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)

      HStack {
        Picker(
          "FPS",
          selection: Binding(
            get: { profile.fps },
            set: { newFPS in
              var updated = profile
              updated.fps = newFPS
              model.updatePowerProfile(
                updated,
                for: source,
                lowPower: lowPower
              )
            }
          )
        ) {
          Text("30").tag(30)
          Text("60").tag(60)
          Text("120").tag(120)
        }
        .pickerStyle(.segmented)

        Toggle(
          "Native resolution",
          isOn: Binding(
            get: { profile.maximumResolution },
            set: { enabled in
              var updated = profile
              updated.maximumResolution = enabled
              if enabled {
                updated.renderScale = 1
              }
              model.updatePowerProfile(
                updated,
                for: source,
                lowPower: lowPower
              )
            }
          )
        )
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
