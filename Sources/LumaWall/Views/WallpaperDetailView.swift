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

extension Color {
  fileprivate init(hex: String) {
    var value = hex
    if value.hasPrefix("#") {
      value.removeFirst()
    }
    let number = UInt64(value, radix: 16) ?? 0xFFFFFF
    self.init(
      red: Double((number >> 16) & 255) / 255,
      green: Double((number >> 8) & 255) / 255,
      blue: Double(number & 255) / 255
    )
  }

  fileprivate var hexString: String {
    let color = NSColor(self).usingColorSpace(.sRGB) ?? .white
    return String(
      format: "#%02X%02X%02X",
      Int(color.redComponent * 255),
      Int(color.greenComponent * 255),
      Int(color.blueComponent * 255)
    )
  }
}
