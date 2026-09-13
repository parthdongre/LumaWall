import SwiftUI

struct WallpaperImportMenu: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    Menu {
      Button {
        model.importWallpaper()
      } label: {
        Label("Import Wallpaper…", systemImage: "square.and.arrow.down")
      }

      Button {
        model.chooseWallpaperEngineProject()
      } label: {
        Label("Import Wallpaper Engine Project…", systemImage: "shippingbox")
      }

      Divider()

      Button {
        model.sidebarSelection = .creator
      } label: {
        Label("Create Wallpaper…", systemImage: "wand.and.stars")
      }
    } label: {
      Label("Add", systemImage: "plus")
    }
    .help("Import or create a wallpaper")
  }
}
