import AppKit
import SwiftUI

struct LockScreenCompanionView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        header
        sourceControls
        appearanceControls
        displaysSection
        handoffSection
      }
      .padding(24)
    }
    .navigationTitle("Lock Screen")
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Lock Screen Companion")
        .font(.system(size: 26, weight: .bold))

      Text(
        "Generate native-resolution still compositions from your LumaWall wallpapers for every connected display."
      )
      .foregroundStyle(.secondary)

      Label(
        "Apple's secure authentication UI remains system-controlled. LumaWall prepares the visuals and hands them off through standard macOS settings.",
        systemImage: "lock.shield"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private var sourceControls: some View {
    GroupBox("Source") {
      VStack(alignment: .leading, spacing: 12) {
        Toggle(
          "Use the active wallpaper on each display",
          isOn: binding(
            get: { $0.useActiveWallpaperPerDisplay },
            set: { $0.useActiveWallpaperPerDisplay = $1 }
          )
        )

        Picker(
          "Fallback wallpaper",
          selection: Binding(
            get: { model.lockScreenSettings.fallbackWallpaperID },
            set: { value in
              var updated = model.lockScreenSettings
              updated.fallbackWallpaperID = value
              model.updateLockScreenSettings(updated)
            }
          )
        ) {
          Text("Automatic")
            .tag(Optional<UUID>.none)

          ForEach(model.wallpapers) { wallpaper in
            Text(wallpaper.name)
              .tag(Optional(wallpaper.id))
          }
        }

        Picker(
          "Fit",
          selection: binding(
            get: { $0.fitMode },
            set: { $0.fitMode = $1 }
          )
        ) {
          ForEach(WallpaperFitMode.allCases) { mode in
            Text(mode.displayName).tag(mode)
          }
        }

        Toggle(
          "Include wallpaper Time & Date overlay",
          isOn: binding(
            get: { $0.includeWallpaperTimeDate },
            set: { $0.includeWallpaperTimeDate = $1 }
          )
        )

        Toggle(
          "Regenerate after wallpaper/display changes",
          isOn: binding(
            get: { $0.autoRefresh },
            set: { $0.autoRefresh = $1 }
          )
        )
      }
      .padding(.vertical, 4)
    }
  }

  private var appearanceControls: some View {
    GroupBox("Appearance") {
      VStack(alignment: .leading, spacing: 12) {
        slider(
          "Blur",
          value: binding(
            get: { $0.blurRadius },
            set: { $0.blurRadius = $1 }
          ),
          range: 0...40,
          step: 1,
          label: { "\(Int($0)) px" }
        )

        slider(
          "Dim",
          value: binding(
            get: { $0.dimAmount },
            set: { $0.dimAmount = $1 }
          ),
          range: 0...0.7,
          step: 0.01,
          label: { "\(Int($0 * 100))%" }
        )

        slider(
          "Saturation",
          value: binding(
            get: { $0.saturation },
            set: { $0.saturation = $1 }
          ),
          range: 0...1.5,
          step: 0.05,
          label: { "\(Int($0 * 100))%" }
        )

        slider(
          "Vignette",
          value: binding(
            get: { $0.vignetteIntensity },
            set: { $0.vignetteIntensity = $1 }
          ),
          range: 0...1.5,
          step: 0.05,
          label: { String(format: "%.2f", $0) }
        )

        HStack {
          Button {
            model.generateLockScreenSnapshots()
          } label: {
            Label(
              model.lockScreenIsGenerating ? "Generating…" : "Generate Images",
              systemImage: "sparkles.rectangle.stack"
            )
          }
          .buttonStyle(.borderedProminent)
          .disabled(model.lockScreenIsGenerating || model.wallpapers.isEmpty)

          if model.lockScreenIsGenerating {
            ProgressView()
              .controlSize(.small)
          }

          Spacer()

          Button("Reveal Images") {
            model.revealLockScreenSnapshots()
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var displaysSection: some View {
    GroupBox("Connected displays") {
      VStack(alignment: .leading, spacing: 14) {
        ForEach(model.displays) { display in
          displayRow(display)

          if display.id != model.displays.last?.id {
            Divider()
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func displayRow(_ display: DisplayDescriptor) -> some View {
    let snapshot = model.lockScreenSnapshot(for: display.id)

    return HStack(spacing: 16) {
      preview(snapshot: snapshot, display: display)
        .frame(width: 240, height: 135)
        .clipShape(RoundedRectangle(cornerRadius: 12))

      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
          Text(display.name)
            .font(.headline)
        }

        Text(display.nativeResolutionLabel + " native pixels")
          .font(.caption)
          .foregroundStyle(.secondary)

        if let snapshot {
          Label(snapshot.wallpaperName, systemImage: "photo")
            .font(.caption)

          Text(
            "Generated "
              + snapshot.generatedAt.formatted(
                date: .abbreviated,
                time: .shortened
              )
          )
          .font(.caption2)
          .foregroundStyle(.secondary)
        } else {
          Text("No generated composition yet.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()
    }
  }

  @ViewBuilder
  private func preview(
    snapshot: LockScreenSnapshot?,
    display: DisplayDescriptor
  ) -> some View {
    if
      let snapshot,
      let image = NSImage(contentsOf: snapshot.fileURL)
    {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
    } else if let wallpaper = sourceWallpaper(for: display) {
      WallpaperThumbnail(wallpaper: wallpaper)
    } else {
      ZStack {
        Rectangle().fill(.quaternary)
        Image(systemName: "lock.rectangle")
          .font(.system(size: 30))
          .foregroundStyle(.secondary)
      }
    }
  }

  private var handoffSection: some View {
    GroupBox("macOS handoff") {
      VStack(alignment: .leading, spacing: 12) {
        Text(
          "Use the generated images through macOS Wallpaper settings. Screen Saver settings control the idle/locked transition."
        )

        HStack {
          Button {
            model.openWallpaperSettings()
          } label: {
            Label("Wallpaper Settings", systemImage: "photo.on.rectangle")
          }

          Button {
            model.openScreenSaverSettings()
          } label: {
            Label("Screen Saver Settings", systemImage: "moon.stars")
          }

          Button {
            model.revealLockScreenSnapshots()
          } label: {
            Label("Generated Files", systemImage: "folder")
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func sourceWallpaper(for display: DisplayDescriptor) -> Wallpaper? {
    if
      model.lockScreenSettings.useActiveWallpaperPerDisplay,
      let id = model.engine.assignmentSnapshot[display.id],
      let active = model.wallpapers.first(where: { $0.id == id })
    {
      return active
    }

    if
      let id = model.lockScreenSettings.fallbackWallpaperID,
      let fallback = model.wallpapers.first(where: { $0.id == id })
    {
      return fallback
    }

    if
      let id = model.selectedWallpaperID,
      let selected = model.wallpapers.first(where: { $0.id == id })
    {
      return selected
    }

    return model.wallpapers.first
  }

  private func binding<Value>(
    get: @escaping (LockScreenCompanionSettings) -> Value,
    set: @escaping (inout LockScreenCompanionSettings, Value) -> Void
  ) -> Binding<Value> {
    Binding(
      get: { get(model.lockScreenSettings) },
      set: { value in
        var updated = model.lockScreenSettings
        set(&updated, value)
        model.updateLockScreenSettings(updated)
      }
    )
  }

  private func slider(
    _ title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double,
    label: @escaping (Double) -> String
  ) -> some View {
    HStack {
      Text(title)
        .frame(width: 92, alignment: .leading)

      Slider(value: value, in: range, step: step)

      Text(label(value.wrappedValue))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 62, alignment: .trailing)
    }
  }
}
