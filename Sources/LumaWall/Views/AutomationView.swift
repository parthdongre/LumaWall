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
