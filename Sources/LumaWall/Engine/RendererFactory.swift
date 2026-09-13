import Foundation

@MainActor
enum RendererFactory {
  static func makeRenderer(for type: WallpaperType) -> WallpaperRenderer {
    switch type {
    case .image:
      return ImageWallpaperRenderer()
    case .video:
      return VideoWallpaperRenderer()
    case .web:
      return WebWallpaperRenderer()
    case .metal:
      return MetalWallpaperRenderer()
    }
  }
}
