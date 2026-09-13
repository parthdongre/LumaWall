import SwiftUI

struct LibraryOverviewView: View {
  @EnvironmentObject private var model: AppModel
  let scope: LibraryScope
  @Binding var selection: SidebarDestination?

  private let columns = [
    GridItem(.adaptive(minimum: 230, maximum: 340), spacing: 18)
  ]

  private var visibleWallpapers: [Wallpaper] {
    model.wallpapers(for: scope)
  }

  var body: some View {
    Group {
      if visibleWallpapers.isEmpty {
        ContentUnavailableView(
          emptyTitle,
          systemImage: emptySymbol,
          description: Text(emptyDescription)
        )
      } else {
        ScrollView {
          LazyVGrid(columns: columns, spacing: 18) {
            ForEach(visibleWallpapers) { wallpaper in
              wallpaperCard(wallpaper)
            }
          }
          .padding(24)
        }
      }
    }
    .navigationTitle(scope.displayName)
    .searchable(text: $model.searchText, prompt: "Search wallpapers or creators")
    .toolbar {
      ToolbarItemGroup {
        Menu {
          ForEach(LibrarySortOrder.allCases) { order in
            Button {
              model.librarySortOrder = order
              UserDefaults.standard.set(order.rawValue, forKey: "library.sortOrder")
            } label: {
              if model.librarySortOrder == order {
                Label(order.displayName, systemImage: "checkmark")
              } else {
                Text(order.displayName)
              }
            }
          }
        } label: {
          Label("Sort", systemImage: "arrow.up.arrow.down")
        }

        Menu {
          ForEach(
            [LibraryScope.all, .metal, .web, .video, .image, .audioReactive]
          ) { destination in
            Button {
              model.searchText = ""
              selection = .library(destination)
            } label: {
              Label(destination.displayName, systemImage: destination.symbolName)
            }
          }
        } label: {
          Label("Types", systemImage: "line.3.horizontal.decrease.circle")
        }

        Button(action: model.importWallpaper) {
          Label("Import", systemImage: "plus")
        }
      }
    }
  }

  @ViewBuilder
  private func wallpaperCard(_ wallpaper: Wallpaper) -> some View {
    ZStack(alignment: .topTrailing) {
      Button {
        model.selectedWallpaperID = wallpaper.id
        selection = .wallpaper(wallpaper.id)
      } label: {
        VStack(alignment: .leading, spacing: 10) {
          ZStack(alignment: .bottomLeading) {
            WallpaperThumbnail(wallpaper: wallpaper)
              .aspectRatio(16 / 9, contentMode: .fit)

            HStack(spacing: 6) {
              badge(
                wallpaper.type.rawValue.uppercased(),
                symbol: typeSymbol(wallpaper.type)
              )
              if wallpaper.requestedPermissions.contains(.systemAudio) {
                badge("AUDIO", symbol: "waveform")
              }
              if model.isWallpaperActive(wallpaper.id) {
                badge("ACTIVE", symbol: "play.fill")
              }
            }
            .padding(9)
          }

          Text(wallpaper.name)
            .font(.headline)
            .lineLimit(1)

          HStack {
            Text(wallpaper.author)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
            Spacer()
            if model.isFavorite(wallpaper.id) {
              Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            }
          }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
      }
      .buttonStyle(.plain)

      Button {
        model.toggleFavorite(wallpaper.id)
      } label: {
        Image(systemName: model.isFavorite(wallpaper.id) ? "star.fill" : "star")
          .padding(8)
          .background(.ultraThinMaterial, in: Circle())
      }
      .buttonStyle(.plain)
      .padding(8)
      .help(model.isFavorite(wallpaper.id) ? "Remove from Favorites" : "Add to Favorites")
    }
  }

  private func badge(_ text: String, symbol: String) -> some View {
    Label(text, systemImage: symbol)
      .font(.system(size: 9, weight: .semibold))
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(.black.opacity(0.62), in: Capsule())
      .foregroundStyle(.white)
  }

  private func typeSymbol(_ type: WallpaperType) -> String {
    switch type {
    case .image: return "photo"
    case .video: return "film"
    case .web: return "globe"
    case .metal: return "cpu"
    }
  }

  private var emptyTitle: String {
    switch scope {
    case .favorites: return "No Favorites Yet"
    case .recent: return "No Recent Wallpapers"
    default: return model.searchText.isEmpty ? "No Wallpapers" : "No Results"
    }
  }

  private var emptySymbol: String {
    switch scope {
    case .favorites: return "star"
    case .recent: return "clock"
    default: return "photo.on.rectangle.angled"
    }
  }

  private var emptyDescription: String {
    switch scope {
    case .favorites:
      return "Star wallpapers you want to keep close."
    case .recent:
      return "Wallpapers you apply will appear here."
    default:
      return model.searchText.isEmpty
        ? "Import a wallpaper package or asset to get started."
        : "Try another search."
    }
  }
}

struct WallpaperThumbnail: View {
  let wallpaper: Wallpaper

  var body: some View {
    Group {
      if let url = wallpaper.thumbnailURL, let image = NSImage(contentsOf: url) {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Rectangle()
          .fill(.black.gradient)
          .overlay {
            VStack(spacing: 8) {
              Image(systemName: wallpaper.type == .metal ? "cpu" : "sparkles.rectangle.stack")
                .font(.system(size: 38))
              Text(wallpaper.type.rawValue.uppercased())
                .font(.caption2.monospaced())
            }
            .foregroundStyle(.white.opacity(0.9))
          }
      }
    }
    .clipped()
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}
