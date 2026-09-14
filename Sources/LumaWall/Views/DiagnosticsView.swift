import SwiftUI

struct DiagnosticsView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Diagnostics")
              .font(.largeTitle.bold())
            Text("Runtime state and recovery information")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text("v\(AppVersion.display)")
            .font(.caption.monospaced())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
        }

        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 180), spacing: 12)],
          spacing: 12
        ) {
          metric(
            title: "Displays",
            value: "\(model.displays.count)",
            symbol: "display.2"
          )
          metric(
            title: "Active Wallpapers",
            value: "\(model.activeWallpaperIDs.count)",
            symbol: "play.rectangle"
          )
          metric(
            title: "Preferred FPS",
            value: "\(model.targetFPS)",
            symbol: "gauge.with.dots.needle.67percent"
          )
          metric(
            title: "Render Scale",
            value: "\(Int(model.renderScale * 100))%",
            symbol: "viewfinder"
          )
          metric(
            title: "Low Power",
            value: ProcessInfo.processInfo.isLowPowerModeEnabled ? "On" : "Off",
            symbol: "battery.50percent"
          )
          metric(
            title: "Safe Mode",
            value: model.isSafeMode ? "Active" : "Off",
            symbol: "shield"
          )
          metric(
            title: "Fullscreen Paused",
            value: "\(model.engine.fullscreenPausedDisplayIDs.count)",
            symbol: "rectangle.slash"
          )
          metric(
            title: "System Suspended",
            value: model.suspension.isSuspended ? "Yes" : "No",
            symbol: "moon.zzz"
          )
        }

        GroupBox("Detected hardware") {
          VStack(alignment: .leading, spacing: 8) {
            diagnosticRow("Device", model.hardwareProfile.deviceFamily)
            diagnosticRow("Model identifier", model.hardwareProfile.modelIdentifier)
            diagnosticRow("Graphics / chip", model.hardwareProfile.chipName)
            diagnosticRow("Memory", "\(model.hardwareProfile.memoryGB) GB")
            diagnosticRow("CPU cores", "\(model.hardwareProfile.processorCount)")
            diagnosticRow(
              "Maximum Resolution",
              model.maximumResolutionEnabled ? "Locked to native pixels" : "Dynamic / manual"
            )
            diagnosticRow("Hardware recommendation", model.hardwareProfile.explanation)
          }
        }

        GroupBox("Display assignments") {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(model.displays) { display in
              HStack {
                Image(systemName: "display")
                VStack(alignment: .leading, spacing: 2) {
                  Text(display.name)
                  Text(model.assignmentName(for: display))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Text(
                    "\(display.nativeResolutionLabel) • \(display.refreshLabel) • \(String(format: "%.1f×", display.backingScaleFactor))"
                  )
                  .font(.caption2)
                  .foregroundStyle(.tertiary)

                  if model.engine.fullscreenPausedDisplayIDs.contains(display.id) {
                    Label(
                      "Paused for fullscreen app",
                      systemImage: "pause.circle.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(.orange)
                  }
                }
                Spacer()
              }
            }

            if model.displays.isEmpty {
              Text("No displays detected.")
                .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        GroupBox("Renderer profiler") {
          VStack(alignment: .leading, spacing: 10) {
            if model.engine.rendererSnapshots.isEmpty {
              Text("No active renderers.")
                .foregroundStyle(.secondary)
            } else {
              ForEach(model.engine.rendererSnapshots) { snapshot in
                VStack(alignment: .leading, spacing: 4) {
                  HStack {
                    Text(snapshot.displayName)
                      .font(.headline)
                    Spacer()
                    Text(snapshot.diagnostics.rendererName)
                      .font(.caption.monospaced())
                      .foregroundStyle(.secondary)
                  }

                  Text(
                    "\(snapshot.diagnostics.pixelWidth) × \(snapshot.diagnostics.pixelHeight) • target \(snapshot.diagnostics.preferredFPS) FPS • \(Int(snapshot.diagnostics.renderScale * 100))%"
                  )
                  .font(.caption.monospacedDigit())
                  .foregroundStyle(.secondary)

                  if let actual = snapshot.diagnostics.actualFPS {
                    HStack(spacing: 10) {
                      Text("actual \(String(format: "%.1f", actual)) FPS")

                      if let frame = snapshot.diagnostics.averageFrameTimeMS {
                        Text("\(String(format: "%.2f", frame)) ms")
                      }

                      if let dropped = snapshot.diagnostics.droppedFrameRatio {
                        Text("drop \(String(format: "%.1f", dropped * 100))%")
                      }

                      Text(snapshot.diagnostics.loadClass.displayName)
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(
                      snapshot.diagnostics.loadClass == .overloaded
                      ? Color.orange
                      : Color.secondary
                    )
                  }

                  if let rate = snapshot.diagnostics.playbackRate {
                    Text(
                      "Video \(String(format: "%.2f×", rate)) • "
                        + ((snapshot.diagnostics.muted ?? true) ? "muted" : "audio on")
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                  }
                }
                .padding(.vertical, 4)
              }
            }
          }
        }

        GroupBox("Power") {
          VStack(alignment: .leading, spacing: 8) {
            diagnosticRow("Source", model.power.snapshot.source.displayName)
            diagnosticRow(
              "Battery",
              model.power.snapshot.percent.map { "\($0)%" } ?? "Unavailable"
            )
            diagnosticRow(
              "Charging",
              model.power.snapshot.isCharging ? "Yes" : "No"
            )
            diagnosticRow(
              "Automatic profiles",
              model.usePowerProfiles ? "Enabled" : "Disabled"
            )
          }
        }

        GroupBox("System suspension") {
          VStack(alignment: .leading, spacing: 8) {
            diagnosticRow(
              "Rendering",
              model.suspension.isSuspended ? "Suspended" : "Active"
            )
            diagnosticRow(
              "Reasons",
              model.suspension.activeReasons.isEmpty
                ? "None"
                : model.suspension.activeReasons
                  .map(\.displayName)
                  .sorted()
                  .joined(separator: ", ")
            )
            Text(
              "System sleep, display sleep, and an inactive user session are tracked independently so one wake event cannot resume rendering while another suspension reason is still active."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        }

        GroupBox("Stability") {
          VStack(alignment: .leading, spacing: 8) {
            diagnosticRow(
              "Previous launch",
              model.quarantine.previousLaunchWasClean ? "Clean" : "Unclean"
            )
            diagnosticRow(
              "Suspected wallpapers",
              "\(model.quarantine.suspectedWallpaperIDs.count)"
            )
            diagnosticRow(
              "Quarantined wallpapers",
              "\(model.quarantine.quarantinedIDs.count)"
            )

            ForEach(model.suspectedCrashWallpapers) { wallpaper in
              diagnosticRow(
                wallpaper.name,
                "\(model.quarantine.crashCount(for: wallpaper.id)) stability strike(s)"
              )
            }
          }
        }

        GroupBox("Foreground activity") {
          VStack(alignment: .leading, spacing: 8) {
            diagnosticRow(
              "Application",
              model.governor.foregroundActivity.ownerName ?? "Unknown"
            )
            diagnosticRow(
              "Fullscreen",
              model.governor.foregroundActivity.isFullscreen ? "Yes" : "No"
            )
            diagnosticRow(
              "Game detected",
              model.governor.foregroundActivity.isGame ? "Yes" : "No"
            )
            diagnosticRow(
              "Adaptive quality",
              model.governor.adaptiveQualityEnabled ? "Enabled" : "Disabled"
            )
            diagnosticRow(
              "Workload adaptation",
              model.governor.experimentalLoadAdaptationEnabled ? "Enabled" : "Disabled"
            )
            diagnosticRow(
              "Measured pressure",
              String(describing: model.governor.loadPressure).capitalized
            )
          }
        }

        if let error = model.lastError {
          GroupBox("Last error") {
            Text(error)
              .textSelection(.enabled)
              .foregroundStyle(.red)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        GroupBox("Support tools") {
          VStack(alignment: .leading, spacing: 12) {
            Text(
              "If LumaWall behaves unexpectedly, copy or export this report before restarting. Crash reports are stored by macOS in DiagnosticReports."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
              Button("Copy Report") {
                model.copyDiagnosticReport()
              }
              Button("Export Report…") {
                model.exportDiagnosticReport()
              }
              Button("Open Crash Reports") {
                model.openCrashReportsFolder()
              }
              Button("Open LumaWall Data") {
                model.openLibraryFolder()
              }
            }
          }
        }

        GroupBox("Full diagnostic report") {
          ScrollView(.horizontal) {
            Text(model.diagnosticReport)
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(8)
          }
        }
      }
      .padding(28)
    }
    .navigationTitle("Diagnostics")
  }

  private func metric(title: String, value: String, symbol: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.title2)
        .frame(width: 32)
      VStack(alignment: .leading, spacing: 2) {
        Text(value)
          .font(.title3.bold())
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(14)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
  }

  private func diagnosticRow(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .textSelection(.enabled)
    }
  }
}
