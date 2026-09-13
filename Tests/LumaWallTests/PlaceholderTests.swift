import Testing

@Test @MainActor
func bundledAuroraIsDiscoverable() {
  let library = WallpaperLibrary()
  let wallpapers = library.loadAll()
  #expect(wallpapers.contains { $0.name == "Aurora" && $0.author == "LumaWall" })
}
