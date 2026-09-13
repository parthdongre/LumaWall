import AppKit

@MainActor
final class ImageWallpaperRenderer: WallpaperRenderer {
  private let imageView = NSImageView()
  var view: NSView { imageView }

  init() {
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.wantsLayer = true
    imageView.layer?.backgroundColor = NSColor.black.cgColor
  }

  func load(_ wallpaper: Wallpaper) throws {
    guard let image = NSImage(contentsOf: wallpaper.entryURL) else {
      throw WallpaperError.unreadableAsset(wallpaper.entryURL)
    }
    imageView.image = image
  }

  func play() {}
  func pause() {}
  func stop() { imageView.image = nil }
}
