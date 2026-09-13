import SwiftUI

struct LibraryOverviewView: View {
  @EnvironmentObject private var model: AppModel
  @Binding var selection: SidebarDestination?
  let columns = [GridItem(.adaptive(minimum: 220), spacing: 18)]
  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 18) {
        ForEach(model.wallpapers) { w in
          Button {
            selection = .wallpaper(w.id)
          } label: {
            VStack(alignment: .leading, spacing: 10) {
              WallpaperThumbnail(wallpaper: w).aspectRatio(16 / 9, contentMode: .fit)
              Text(w.name).font(.headline)
              Text("\(w.type.rawValue.capitalized) • \(w.author)").font(.caption).foregroundStyle(
                .secondary)
            }.padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
          }.buttonStyle(.plain)
        }
      }.padding(24)
    }.navigationTitle("Library")
  }
}
struct WallpaperThumbnail: View {
  let wallpaper: Wallpaper
  var body: some View {
    Group {
      if let u = wallpaper.thumbnailURL, let i = NSImage(contentsOf: u) {
        Image(nsImage: i).resizable().scaledToFill()
      } else {
        Rectangle().fill(.black.gradient).overlay {
          Image(systemName: wallpaper.type==.metal ? "cpu" : "sparkles.rectangle.stack").font(
            .system(size: 42)
          ).foregroundStyle(.white)
        }
      }
    }.clipShape(RoundedRectangle(cornerRadius: 12))
  }
}
