import AppKit
import SwiftUI

struct WallpaperDetailView: View {
  @EnvironmentObject private var model: AppModel
  let wallpaper: Wallpaper
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        WallpaperThumbnail(wallpaper: wallpaper).frame(maxWidth: 760).aspectRatio(
          16 / 9, contentMode: .fit)
        HStack {
          VStack(alignment: .leading) {
            Text(wallpaper.name).font(.largeTitle.bold())
            Text("by \(wallpaper.author)").foregroundStyle(.secondary)
          }
          Spacer()
          Text(wallpaper.type.rawValue.uppercased()).font(.caption.monospaced()).padding(8)
            .background(.quaternary, in: Capsule())
        }
        GroupBox("Display & performance") {
          VStack(alignment: .leading, spacing: 14) {
            Picker("Apply to", selection: $model.selectedTargetDisplayID) {
              Text("All displays").tag(Optional<CGDirectDisplayID>.none)
              ForEach(model.displays) { d in Text(d.name).tag(Optional(d.id)) }
            }
            HStack {
              Picker(
                "FPS",
                selection: Binding(
                  get: { model.targetFPS },
                  set: { fps in model.updateFPS(fps) }
                )
              ) {
                Text("30").tag(30)
                Text("60").tag(60)
                Text("120").tag(120)
              }.pickerStyle(.segmented).frame(width: 260)
              VStack(alignment: .leading) {
                Text("Render scale \(Int(model.renderScale*100))%").font(.caption)
                Slider(
                  value: Binding(
                    get: { model.renderScale },
                    set: { scale in model.updateRenderScale(scale) }
                  ),
                  in: 0.25...1, step: 0.05)
              }
            }
          }
        }
        if !wallpaper.properties.isEmpty {
          GroupBox("Creator controls") {
            VStack(alignment: .leading, spacing: 14) {
              ForEach(wallpaper.properties) { propertyControl($0) }
            }
          }
        }
        if !wallpaper.requestedPermissions.isEmpty {
          GroupBox("Permissions") {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(
                wallpaper.requestedPermissions.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self
              ) { permission in
                HStack {
                  let granted =
                    model.wallpapers.first(where: { $0.id == wallpaper.id })?.grantedPermissions
                    .contains(permission) ?? false
                  Image(systemName: granted ? "checkmark.shield.fill" : "shield.slash")
                  Text(permission.displayName)
                  Spacer()
                  Button(granted ? "Revoke" : "Grant") {
                    model.setPermission(permission, granted: !granted, for: wallpaper.id)
                  }
                  .buttonStyle(.borderless)
                }
              }
            }
          }
        }
        HStack {
          Button("Set Wallpaper") {
            model.selectedWallpaperID = wallpaper.id
            model.applySelectedWallpaper()
          }.buttonStyle(.borderedProminent).controlSize(.large)
          Button(model.isPaused ? "Resume" : "Pause") { model.togglePause() }.controlSize(.large)
          Button("Export .wall") {
            model.selectedWallpaperID = wallpaper.id
            model.exportSelectedWallpaper()
          }.controlSize(.large)
        }
      }.padding(28)
    }
  }
  @ViewBuilder private func propertyControl(_ p: WallpaperProperty) -> some View {
    let current = model.propertyValues[wallpaper.id]?[p.id] ?? p.defaultValue
    switch p.kind {
    case .slider:
      VStack(alignment: .leading) {
        Text("\(p.name): \(String(format:"%.2f",current.numberValue ?? 0))")
        Slider(
          value: Binding(
            get: {
              model.propertyValues[wallpaper.id]?[p.id]?.numberValue ?? p.defaultValue.numberValue
                ?? 0
            }, set: { model.setProperty(.number($0), propertyID: p.id, wallpaperID: wallpaper.id) }),
          in: (p.minValue ?? 0)...(p.maxValue ?? 1), step: p.step ?? 0.01)
      }
    case .toggle:
      Toggle(
        p.name,
        isOn: Binding(
          get: {
            model.propertyValues[wallpaper.id]?[p.id]?.boolValue ?? p.defaultValue.boolValue
              ?? false
          }, set: { model.setProperty(.bool($0), propertyID: p.id, wallpaperID: wallpaper.id) }))
    case .dropdown:
      Picker(
        p.name,
        selection: Binding(
          get: {
            model.propertyValues[wallpaper.id]?[p.id]?.stringValue ?? p.defaultValue.stringValue
              ?? p.options?.first ?? ""
          }, set: { model.setProperty(.string($0), propertyID: p.id, wallpaperID: wallpaper.id) })
      ) { ForEach(p.options ?? [], id: \.self) { Text($0).tag($0) } }
    case .color:
      ColorPicker(
        p.name,
        selection: Binding(
          get: {
            Color(
              hex: model.propertyValues[wallpaper.id]?[p.id]?.stringValue ?? p.defaultValue
                .stringValue ?? "#FFFFFF")
          },
          set: {
            model.setProperty(.string($0.hexString), propertyID: p.id, wallpaperID: wallpaper.id)
          }))
    }
  }
}
extension Color {
  fileprivate init(hex: String) {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    let n = UInt64(s, radix: 16) ?? 0xFFFFFF
    self.init(
      red: Double((n >> 16) & 255) / 255, green: Double((n >> 8) & 255) / 255,
      blue: Double(n & 255) / 255)
  }
  fileprivate var hexString: String {
    let c = NSColor(self).usingColorSpace(.sRGB) ?? .white
    return String(
      format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255),
      Int(c.blueComponent * 255))
  }
}
