import SwiftUI

struct AutomationView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    Form {
      Section("Playlists") {
        ForEach(model.automation.playlists) { playlist in
          HStack {
            VStack(alignment: .leading) {
              Text(playlist.name)
              Text(
                "\(playlist.wallpaperIDs.count) wallpapers • every \(Int(playlist.intervalSeconds))s"
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Play") { model.automation.play(playlist) }
          }
        }
        Button("Create playlist from library") { model.createPlaylistFromAll() }
      }

      Section("Schedules") {
        ForEach(model.automation.schedules) { schedule in
          Text(scheduleText(schedule))
        }
        if let id = model.selectedWallpaperID {
          Button("Schedule selected at 8:00 PM") {
            model.addDailySchedule(for: id, hour: 20, minute: 0)
          }
          Button("Switch selected at sunrise") {
            model.addSunriseSchedule(for: id)
          }
        }
      }

      Section("Smart Rules") {
        if model.automation.smartRules.isEmpty {
          Text(
            "Rules can switch wallpapers when battery, charging, display, appearance or time conditions change."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        } else {
          ForEach(model.automation.smartRules) { rule in
            HStack(alignment: .top) {
              Toggle(
                "",
                isOn: Binding(
                  get: { rule.enabled },
                  set: {
                    model.automation.setSmartRuleEnabled(
                      rule.id,
                      enabled: $0
                    )
                  }
                )
              )
              .labelsHidden()

              VStack(alignment: .leading, spacing: 3) {
                Text(rule.name)
                  .font(.headline)

                Text(
                  model.wallpapers.first(where: { $0.id == rule.wallpaperID })?.name
                    ?? "Missing wallpaper"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                  rule.conditions
                    .map(\.displayName)
                    .joined(separator: " + ")
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
              }

              Spacer()

              Text("P\(rule.priority)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

              Button {
                model.removeSmartRule(rule.id)
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.plain)
              .help("Delete rule")
            }
          }
        }

        if model.selectedWallpaperID != nil {
          Menu {
            Button("Battery below 30%") {
              model.addSmartRuleForSelected(
                name: "Battery Saver",
                condition: .batteryBelow(30),
                priority: 80
              )
            }

            Button("When charging") {
              model.addSmartRuleForSelected(
                name: "Charging",
                condition: .charging(true),
                priority: 40
              )
            }

            Button("External display connected") {
              model.addSmartRuleForSelected(
                name: "External Display",
                condition: .externalDisplayConnected(true),
                priority: 60
              )
            }

            Button("Low Power Mode") {
              model.addSmartRuleForSelected(
                name: "Low Power",
                condition: .lowPowerMode(true),
                priority: 100
              )
            }

            Button("Dark Mode") {
              model.addSmartRuleForSelected(
                name: "Dark Mode",
                condition: .darkMode(true),
                priority: 30
              )
            }

            Button("Night — 10 PM to 6 AM") {
              model.addSmartRuleForSelected(
                name: "Night",
                condition: .timeRange(
                  startMinutes: 22 * 60,
                  endMinutes: 6 * 60
                ),
                priority: 20
              )
            }
          } label: {
            Label(
              "Add Rule for Selected Wallpaper",
              systemImage: "plus.circle"
            )
          }
        }
      }

      Section("Solar location") {
        HStack {
          TextField(
            "Latitude",
            value: Binding(
              get: { model.automation.solarLocation?.latitude ?? 18.52 },
              set: {
                model.automation.solarLocation = SolarLocation(
                  latitude: $0,
                  longitude: model.automation.solarLocation?.longitude ?? 73.86
                )
              }),
            format: .number
          )
          TextField(
            "Longitude",
            value: Binding(
              get: { model.automation.solarLocation?.longitude ?? 73.86 },
              set: {
                model.automation.solarLocation = SolarLocation(
                  latitude: model.automation.solarLocation?.latitude ?? 18.52,
                  longitude: $0
                )
              }),
            format: .number
          )
        }
      }
    }
    .padding(24)
    .navigationTitle("Playlists & Schedules")
  }

  private func scheduleText(_ schedule: WallpaperSchedule) -> String {
    switch schedule.trigger {
    case .daily(let hour, let minute):
      return String(format: "Daily %02d:%02d", hour, minute)
    case .date(let date):
      return date.formatted()
    case .sunrise(let offset):
      return "Sunrise \(offset >= 0 ? "+" : "")\(offset)m"
    case .sunset(let offset):
      return "Sunset \(offset >= 0 ? "+" : "")\(offset)m"
    }
  }
}
