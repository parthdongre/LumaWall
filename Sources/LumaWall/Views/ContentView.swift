import SwiftUI

enum SidebarDestination: Hashable {
  case library, displays, automations
  case wallpaper(UUID)
}
struct ContentView: View {
  @EnvironmentObject private var model: AppModel
  @State private var selection: SidebarDestination? = .library
  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Section("LumaWall") {
          Label("Library", systemImage: "square.grid.2x2").tag(SidebarDestination.library)
          Label("Displays", systemImage: "display.2").tag(SidebarDestination.displays)
          Label("Playlists & Schedules", systemImage: "clock.arrow.2.circlepath").tag(
            SidebarDestination.automations)
        }
        Section("Wallpapers") {
          ForEach(model.wallpapers) { w in
            Label(w.name, systemImage: icon(w.type)).tag(SidebarDestination.wallpaper(w.id))
          }
        }
      }.navigationTitle("LumaWall").toolbar {
        Button(action: model.importWallpaper) { Label("Import", systemImage: "plus") }
      }
    } detail: {
      switch selection {
      case .library: LibraryOverviewView(selection: $selection)
      case .displays: DisplaysView()
      case .automations: AutomationView()
      case .wallpaper(let id):
        if let w = model.wallpapers.first(where: { $0.id == id }) {
          WallpaperDetailView(wallpaper: w).onAppear { model.selectedWallpaperID = id }
        }
      case .none:
        ContentUnavailableView("Choose a section", systemImage: "sparkles.rectangle.stack")
      }
    }
  }
  private func icon(_ t: WallpaperType) -> String {
    switch t {
    case .image: return "photo"
    case .video: return "film"
    case .web: return "globe"
    case .metal: return "cpu"
    }
  }
}
