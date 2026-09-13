import SwiftUI

struct LibraryOverviewView: View {
  @EnvironmentObject private var model: AppModel
  @Binding var selection: SidebarDestination?
  let columns = [GridItem(.adaptive(minimum: 220), spacing: 18)]

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 18) {
        ForEach(model.wallpapers) { wallpaper in
          Button {
            selection = .wallpaper(wallpaper.id)
          } label: {
            VStack(alignment: .leading, spacing: 10) {
              WallpaperThumbnail(wallpaper: wallpaper)
                .aspectRatio(16 / 9, contentMode: .fit)
                .task { await model.ensurePreview(for: wallpaper.id) }
              Text(wallpaper.name)
                .font(.headline)
              Text("\(wallpaper.type.rawValue.capitalized) • \(wallpaper.author)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(24)
    }
    .navigationTitle("Library")
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
            Image(
              systemName: wallpaper.type == .metal
                ? "cpu"
                : "sparkles.rectangle.stack"
            )
            .font(.system(size: 42))
            .foregroundStyle(.white)
          }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}
