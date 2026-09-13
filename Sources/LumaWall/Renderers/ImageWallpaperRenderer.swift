import AppKit

@MainActor
final class ImageWallpaperRenderer: WallpaperRenderer {
  private let imageView = NSImageView()
  private var displaySize = CGSize.zero
  private var renderScale = 1.0

  var view: NSView { imageView }

  var diagnostics: RendererDiagnostics {
    RendererDiagnostics(
      rendererName: "Image",
      preferredFPS: 0,
      renderScale: renderScale,
      pixelWidth:
        Int(
          displaySize.width
            * renderScale
        ),
      pixelHeight:
        Int(
          displaySize.height
            * renderScale
        ),
      playbackRate: nil,
      muted: nil
    )
  }

  init() {
    imageView.imageScaling =
      .scaleProportionallyUpOrDown

    imageView.imageAlignment =
      .alignCenter

    imageView.wantsLayer = true

    imageView.layer?
      .backgroundColor =
      NSColor.black.cgColor
  }

  func configure(
    for display:
      DisplayDescriptor
  ) {
    displaySize =
      display.nativePixelSize

    imageView.layer?
      .contentsScale =
      display.backingScaleFactor
  }

  func load(
    _ wallpaper: Wallpaper
  ) throws {
    guard
      let image =
        NSImage(
          contentsOf:
            wallpaper.entryURL
        )
    else {
      throw
        WallpaperError
          .unreadableAsset(
            wallpaper.entryURL
          )
    }

    imageView.image = image
  }

  func setRenderScale(
    _ scale: Double
  ) {
    renderScale =
      min(
        max(
          scale,
          0.25
        ),
        1
      )
  }

  func setFitMode(
    _ mode:
      WallpaperFitMode
  ) {
    switch mode {
    case .fill:
      imageView.imageScaling =
        .scaleProportionallyUpOrDown
      imageView.layer?
        .contentsGravity =
        .resizeAspectFill

    case .fit:
      imageView.imageScaling =
        .scaleProportionallyUpOrDown
      imageView.layer?
        .contentsGravity =
        .resizeAspect

    case .stretch:
      imageView.imageScaling =
        .scaleAxesIndependently
      imageView.layer?
        .contentsGravity =
        .resize

    case .center:
      imageView.imageScaling =
        .scaleNone
      imageView.layer?
        .contentsGravity =
        .center
    }
  }

  func play() {}
  func pause() {}

  func stop() {
    imageView.image = nil
  }
}
