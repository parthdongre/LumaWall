import AppKit
import SwiftUI

struct WallpaperDetailView: View {
  @EnvironmentObject private var model: AppModel
  let wallpaper: Wallpaper

  private var currentWallpaper: Wallpaper {
    model.wallpapers.first(where: { $0.id == wallpaper.id }) ?? wallpaper
  }

  private var activeDisplays: [String] {
    model.activeDisplayNames(for: wallpaper.id)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        ZStack(alignment: .topTrailing) {
          WallpaperThumbnail(wallpaper: currentWallpaper)
            .frame(maxWidth: 820)
            .aspectRatio(16 / 9, contentMode: .fit)

          Button {
            model.toggleFavorite(wallpaper.id)
          } label: {
            Label(
              model.isFavorite(wallpaper.id) ? "Favorited" : "Favorite",
              systemImage: model.isFavorite(wallpaper.id) ? "star.fill" : "star"
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
          }
          .buttonStyle(.plain)
          .padding(12)
        }

        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            Text(currentWallpaper.name)
              .font(.largeTitle.bold())
            Text("by \(currentWallpaper.author)")
              .foregroundStyle(.secondary)

            if !activeDisplays.isEmpty {
              Label(
                "Active on \(activeDisplays.joined(separator: ", "))",
                systemImage: "play.circle.fill"
              )
              .font(.caption)
              .foregroundStyle(.green)
            }
          }

          Spacer()

          VStack(alignment: .trailing, spacing: 7) {
            Text(currentWallpaper.type.rawValue.uppercased())
              .font(.caption.monospaced())
              .padding(8)
              .background(.quaternary, in: Capsule())

            if currentWallpaper.requestedPermissions.contains(.systemAudio) {
              Label("Audio Reactive", systemImage: "waveform")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }

        GroupBox("Display & performance") {
          VStack(alignment: .leading, spacing: 16) {
            Picker("Apply to", selection: $model.selectedTargetDisplayID) {
              Text("All displays")
                .tag(Optional<CGDirectDisplayID>.none)
              ForEach(model.displays) { display in
                Text(display.name)
                  .tag(Optional(display.id))
              }
            }

            HStack(spacing: 18) {
              Picker(
                "Quality",
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
              .frame(width: 210)

              Picker(
                "FPS",
                selection: Binding(
                  get: { model.targetFPS },
                  set: { model.updateFPS($0) }
                )
              ) {
                Text("30").tag(30)
                Text("60").tag(60)
                Text("120").tag(120)
              }
              .pickerStyle(.segmented)
              .frame(width: 250)
            }

            Toggle(
              "Maximum Resolution",
              isOn: Binding(
                get: { model.maximumResolutionEnabled },
                set: { model.setMaximumResolutionEnabled($0) }
              )
            )

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

              if model.maximumResolutionEnabled {
                Text(
                  "Native pixels: "
                    + model.displays
                      .map { "\($0.name) \($0.nativeResolutionLabel)" }
                      .joined(separator: " • ")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
              }
            }
          }
        }

        GroupBox("Presentation") {
          VStack(alignment: .leading, spacing: 14) {
            Picker(
              "Wallpaper fit",
              selection: Binding(
                get: {
                  model.fitModes[wallpaper.id] ?? .fill
                },
                set: {
                  model.setFitMode($0, for: wallpaper.id)
                }
              )
            ) {
              ForEach(WallpaperFitMode.allCases) { mode in
                Text(mode.displayName)
                  .tag(mode)
              }
            }

            if currentWallpaper.type == .video {
              let settings = model.videoSettings(for: wallpaper.id)

              HStack {
                Text("Playback speed")
                Slider(
                  value: Binding(
                    get: { settings.playbackRate },
                    set: { value in
                      var updated = model.videoSettings(for: wallpaper.id)
                      updated.playbackRate = value
                      model.updateVideoSettings(updated, for: wallpaper.id)
                    }
                  ),
                  in: 0.25...2,
                  step: 0.05
                )
                Text(String(format: "%.2f×", settings.playbackRate))
                  .monospacedDigit()
                  .frame(width: 52)
              }

              Toggle(
                "Mute video audio",
                isOn: Binding(
                  get: { settings.muted },
                  set: { enabled in
                    var updated = model.videoSettings(for: wallpaper.id)
                    updated.muted = enabled
                    model.updateVideoSettings(updated, for: wallpaper.id)
                  }
                )
              )

              Toggle(
                "Loop video",
                isOn: Binding(
                  get: { settings.loop },
                  set: { enabled in
                    var updated = model.videoSettings(for: wallpaper.id)
                    updated.loop = enabled
                    model.updateVideoSettings(updated, for: wallpaper.id)
                  }
                )
              )
            }
          }
        }

        if model.isQuarantined(wallpaper.id) {
          GroupBox("Stability") {
            HStack {
              Label(
                "This wallpaper was disabled after repeated unclean exits.",
                systemImage: "exclamationmark.shield.fill"
              )
              .foregroundStyle(.orange)

              Spacer()

              Button("Re-enable") {
                model.allowQuarantinedWallpaper(wallpaper.id)
              }
            }
          }
        }

        GroupBox("Time & Date Overlay") {
          let clock = model.timeDateSettings(for: wallpaper.id)

          VStack(alignment: .leading, spacing: 14) {
            HStack {
              Toggle(
                "Show Time & Date",
                isOn: Binding(
                  get: { clock.enabled },
                  set: { enabled in
                    var updated = model.timeDateSettings(for: wallpaper.id)
                    updated.enabled = enabled
                    model.updateTimeDateSettings(updated, for: wallpaper.id)
                  }
                )
              )

              Spacer()

              Menu("Presets") {
                Button("Glass") {
                  model.applyTimeDatePreset(.glass, to: wallpaper.id)
                }
                Button("Minimal") {
                  model.applyTimeDatePreset(.minimal, to: wallpaper.id)
                }
                Button("Bold Center") {
                  model.applyTimeDatePreset(.bold, to: wallpaper.id)
                }
              }
            }

            if clock.enabled {
              Grid(
                alignment: .leading,
                horizontalSpacing: 18,
                verticalSpacing: 10
              ) {
                GridRow {
                  Text("Position")
                  Picker(
                    "",
                    selection: Binding(
                      get: { clock.position },
                      set: { position in
                        var updated = model.timeDateSettings(for: wallpaper.id)
                        updated.position = position
                        model.updateTimeDateSettings(updated, for: wallpaper.id)
                      }
                    )
                  ) {
                    ForEach(ClockOverlayPosition.allCases) { position in
                      Text(position.displayName)
                        .tag(position)
                    }
                  }
                }

                GridRow {
                  Text("Hour format")
                  Picker(
                    "",
                    selection: Binding(
                      get: { clock.hourFormat },
                      set: { format in
                        var updated = model.timeDateSettings(for: wallpaper.id)
                        updated.hourFormat = format
                        model.updateTimeDateSettings(updated, for: wallpaper.id)
                      }
                    )
                  ) {
                    ForEach(ClockHourFormat.allCases) { format in
                      Text(format.displayName)
                        .tag(format)
                    }
                  }
                }

                GridRow {
                  Text("Date")
                  Picker(
                    "",
                    selection: Binding(
                      get: { clock.dateStyle },
                      set: { style in
                        var updated = model.timeDateSettings(for: wallpaper.id)
                        updated.dateStyle = style
                        model.updateTimeDateSettings(updated, for: wallpaper.id)
                      }
                    )
                  ) {
                    ForEach(ClockDateStyle.allCases) { style in
                      Text(style.displayName)
                        .tag(style)
                    }
                  }
                }

                GridRow {
                  Text("Weight")
                  Picker(
                    "",
                    selection: Binding(
                      get: { clock.fontWeight },
                      set: { weight in
                        var updated = model.timeDateSettings(for: wallpaper.id)
                        updated.fontWeight = weight
                        model.updateTimeDateSettings(updated, for: wallpaper.id)
                      }
                    )
                  ) {
                    ForEach(ClockFontWeight.allCases) { weight in
                      Text(weight.displayName)
                        .tag(weight)
                    }
                  }
                }
              }

              HStack {
                Toggle(
                  "Seconds",
                  isOn: Binding(
                    get: { clock.showSeconds },
                    set: { enabled in
                      var updated = model.timeDateSettings(for: wallpaper.id)
                      updated.showSeconds = enabled
                      model.updateTimeDateSettings(updated, for: wallpaper.id)
                    }
                  )
                )

                Toggle(
                  "Weekday",
                  isOn: Binding(
                    get: { clock.showWeekday },
                    set: { enabled in
                      var updated = model.timeDateSettings(for: wallpaper.id)
                      updated.showWeekday = enabled
                      model.updateTimeDateSettings(updated, for: wallpaper.id)
                    }
                  )
                )

                Toggle(
                  "Glass",
                  isOn: Binding(
                    get: { clock.glassEnabled },
                    set: { enabled in
                      var updated = model.timeDateSettings(for: wallpaper.id)
                      updated.glassEnabled = enabled
                      model.updateTimeDateSettings(updated, for: wallpaper.id)
                    }
                  )
                )

                Toggle(
                  "Shadow",
                  isOn: Binding(
                    get: { clock.shadow },
                    set: { enabled in
                      var updated = model.timeDateSettings(for: wallpaper.id)
                      updated.shadow = enabled
                      model.updateTimeDateSettings(updated, for: wallpaper.id)
                    }
                  )
                )
              }

              HStack {
                Text("Clock size")
                Slider(
                  value: Binding(
                    get: { clock.timeFontSize },
                    set: { value in
                      var updated = model.timeDateSettings(for: wallpaper.id)
                      updated.timeFontSize = value
                      model.updateTimeDateSettings(updated, for: wallpaper.id)
                    }
                  ),
                  in: 28...160,
                  step: 2
                )
                Text("\(Int(clock.timeFontSize)) pt")
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
                  .frame(width: 52)
              }

              HStack {
                Text("Opacity")
                Slider(
                  value: Binding(
                    get: { clock.opacity },
                    set: { value in
                      var updated = model.timeDateSettings(for: wallpaper.id)
                      updated.opacity = value
                      model.updateTimeDateSettings(updated, for: wallpaper.id)
                    }
                  ),
                  in: 0.2...1,
                  step: 0.05
                )
                Text("\(Int(clock.opacity * 100))%")
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
                  .frame(width: 44)
              }

              ColorPicker(
                "Text color",
                selection: Binding(
                  get: { Color(hex: clock.colorHex) },
                  set: { color in
                    var updated = model.timeDateSettings(for: wallpaper.id)
                    updated.colorHex = color.hexString
                    model.updateTimeDateSettings(updated, for: wallpaper.id)
                  }
                )
              )

              TextField(
                "Timezone identifier — blank uses macOS timezone",
                text: Binding(
                  get: { clock.timezoneIdentifier ?? "" },
                  set: { text in
                    var updated = model.timeDateSettings(for: wallpaper.id)
                    updated.timezoneIdentifier =
                      text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      ? nil
                      : text.trimmingCharacters(in: .whitespacesAndNewlines)
                    model.updateTimeDateSettings(updated, for: wallpaper.id)
                  }
                )
              )

              Text(
                "Examples: Asia/Kolkata, Europe/London, America/New_York. The overlay is rendered natively above any image, video, WebGL or Metal wallpaper."
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }
        }

        if !currentWallpaper.properties.isEmpty {
          GroupBox("Creator controls") {
            VStack(alignment: .leading, spacing: 14) {
              ForEach(currentWallpaper.properties) { propertyControl($0) }

              Divider()

              Button("Reset Creator Controls") {
                model.resetProperties(for: wallpaper.id)
              }
            }
          }
        }

        if !currentWallpaper.requestedPermissions.isEmpty {
          GroupBox("Permissions") {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(
                currentWallpaper.requestedPermissions.sorted(by: {
                  $0.rawValue < $1.rawValue
                }),
                id: \.self
              ) { permission in
                HStack {
                  let granted =
                    model.wallpapers
                    .first(where: { $0.id == wallpaper.id })?
                    .grantedPermissions.contains(permission) ?? false

                  Image(
                    systemName: granted
                      ? "checkmark.shield.fill"
                      : "shield.slash"
                  )
                  Text(permission.displayName)
                  Spacer()
                  Button(granted ? "Revoke" : "Grant") {
                    model.setPermission(
                      permission,
                      granted: !granted,
                      for: wallpaper.id
                    )
                  }
                  .buttonStyle(.borderless)
                }
              }
            }
          }
        }

        GroupBox("Wallpaper tools") {
          HStack {
            Button {
              Task {
                await model.ensurePreview(for: wallpaper.id)
              }
            } label: {
              Label("Generate Preview", systemImage: "photo.badge.plus")
            }

            Button {
              model.selectedWallpaperID = wallpaper.id
              model.exportSelectedWallpaper()
            } label: {
              Label("Export .wall", systemImage: "square.and.arrow.up")
            }

            Spacer()

            if model.isWallpaperActive(wallpaper.id) {
              Button(role: .destructive) {
                model.stopWallpapers(on: model.selectedTargetDisplayID)
              } label: {
                Label(
                  model.selectedTargetDisplayID == nil ? "Stop Everywhere" : "Stop on Display",
                  systemImage: "stop.fill"
                )
              }
            }
          }
        }

        HStack(spacing: 12) {
          Button {
            model.selectedWallpaperID = wallpaper.id
            model.applySelectedWallpaper()
          } label: {
            Label("Set Wallpaper", systemImage: "play.fill")
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)

          Button {
            model.togglePause()
          } label: {
            Label(
              model.isPaused ? "Resume" : "Pause",
              systemImage: model.isPaused ? "play" : "pause"
            )
          }
          .controlSize(.large)
        }
      }
      .padding(28)
    }
    .navigationTitle(currentWallpaper.name)
  }

  @ViewBuilder
  private func propertyControl(_ property: WallpaperProperty) -> some View {
    let current =
      model.propertyValues[wallpaper.id]?[property.id]
      ?? property.defaultValue

    switch property.kind {
    case .slider:
      VStack(alignment: .leading) {
        HStack {
          Text(property.name)
          Spacer()
          Text(String(format: "%.2f", current.numberValue ?? 0))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        Slider(
          value: Binding(
            get: {
              model.propertyValues[wallpaper.id]?[property.id]?.numberValue
                ?? property.defaultValue.numberValue
                ?? 0
            },
            set: {
              model.setProperty(
                .number($0),
                propertyID: property.id,
                wallpaperID: wallpaper.id
              )
            }
          ),
          in: (property.minValue ?? 0)...(property.maxValue ?? 1),
          step: property.step ?? 0.01
        )
      }

    case .toggle:
      Toggle(
        property.name,
        isOn: Binding(
          get: {
            model.propertyValues[wallpaper.id]?[property.id]?.boolValue
              ?? property.defaultValue.boolValue
              ?? false
          },
          set: {
            model.setProperty(
              .bool($0),
              propertyID: property.id,
              wallpaperID: wallpaper.id
            )
          }
        )
      )

    case .dropdown:
      Picker(
        property.name,
        selection: Binding(
          get: {
            model.propertyValues[wallpaper.id]?[property.id]?.stringValue
              ?? property.defaultValue.stringValue
              ?? property.options?.first
              ?? ""
          },
          set: {
            model.setProperty(
              .string($0),
              propertyID: property.id,
              wallpaperID: wallpaper.id
            )
          }
        )
      ) {
        ForEach(property.options ?? [], id: \.self) { option in
          Text(option)
            .tag(option)
        }
      }

    case .color:
      ColorPicker(
        property.name,
        selection: Binding(
          get: {
            Color(
              hex:
                model.propertyValues[wallpaper.id]?[property.id]?.stringValue
                ?? property.defaultValue.stringValue
                ?? "#FFFFFF"
            )
          },
          set: {
            model.setProperty(
              .string($0.hexString),
              propertyID: property.id,
              wallpaperID: wallpaper.id
            )
          }
        )
      )
    }
  }
}
