import SwiftUI

enum SidebarDestination: Hashable {
  case library(LibraryScope)
  case discover
  case displays
  case automations
  case creator
  case overlayStudio
  case lockScreen
  case diagnostics
  case wallpaper(UUID)
}

struct ContentView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    NavigationSplitView {
      List(selection: $model.sidebarSelection) {
        Section("Library") {
          Label("All Wallpapers", systemImage: "square.grid.2x2")
            .tag(SidebarDestination.library(.all))
          Label("Discover", systemImage: "sparkles")
            .tag(SidebarDestination.discover)
          Label("Favorites", systemImage: "star")
            .tag(SidebarDestination.library(.favorites))
          Label("Recent", systemImage: "clock")
            .tag(SidebarDestination.library(.recent))
        }

        Section("Create") {
          Label("Creator Studio", systemImage: "wand.and.stars")
            .tag(SidebarDestination.creator)
          Label("Overlay Studio", systemImage: "clock.badge.plus")
            .tag(SidebarDestination.overlayStudio)
        }

        Section("System") {
          Label("Displays", systemImage: "display.2")
            .tag(SidebarDestination.displays)
          Label("Lock Screen", systemImage: "lock.rectangle")
            .tag(SidebarDestination.lockScreen)
          Label("Playlists & Schedules", systemImage: "clock.arrow.2.circlepath")
            .tag(SidebarDestination.automations)
          Label("Diagnostics", systemImage: "stethoscope")
            .tag(SidebarDestination.diagnostics)
        }
      }
      .navigationTitle("LumaWall")
      .toolbar {
        WallpaperImportMenu()
      }
    } detail: {
      switch model.sidebarSelection {
      case .library(let scope):
        LibraryOverviewView(scope: scope, selection: $model.sidebarSelection)
      case .discover:
        DiscoverView()
      case .displays:
        DisplaysView()
      case .automations:
        AutomationView()
      case .creator:
        CreatorStudioView()
      case .overlayStudio:
        OverlayStudioView()
      case .lockScreen:
        LockScreenCompanionView()
      case .diagnostics:
        DiagnosticsView()
      case .wallpaper(let id):
        if let wallpaper = model.wallpapers.first(where: { $0.id == id }) {
          WallpaperDetailView(wallpaper: wallpaper)
            .onAppear { model.selectedWallpaperID = id }
        } else {
          ContentUnavailableView(
            "Wallpaper unavailable",
            systemImage: "exclamationmark.triangle"
          )
        }
      case .none:
        ContentUnavailableView(
          "Choose a section",
          systemImage: "sparkles.rectangle.stack"
        )
      }
    }
    .safeAreaInset(edge: .top) {
      if model.installationLocation.shouldRecommendInstallation {
        InstallationRecommendationBanner()
          .padding(.horizontal, 14)
          .padding(.top, 10)
      }
    }
    .safeAreaInset(edge: .bottom) {
      if let message = model.statusMessage {
        HStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
          Text(message)
            .lineLimit(1)
          Spacer()
          Button {
            model.statusMessage = nil
          } label: {
            Image(systemName: "xmark")
          }
          .buttonStyle(.plain)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial)
      }
    }
  }
}
