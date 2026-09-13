import AppKit

struct RendererDiagnostics: Hashable, Sendable {
  var rendererName: String
  var preferredFPS: Int
  var renderScale: Double
  var pixelWidth: Int
  var pixelHeight: Int
  var playbackRate: Double?
  var muted: Bool?
  var actualFPS: Double? = nil
  var averageFrameTimeMS: Double? = nil
  var droppedFrameRatio: Double? = nil
  var loadClass: RendererLoadClass = .unknown
}

@MainActor
protocol WallpaperRenderer: AnyObject {
  var view: NSView { get }
  var diagnostics: RendererDiagnostics { get }

  func load(_ wallpaper: Wallpaper) throws
  func play()
  func pause()
  func stop()

  func configure(for display: DisplayDescriptor)
  func setFPS(_ fps: Int)
  func setRenderScale(_ scale: Double)
  func setFitMode(_ mode: WallpaperFitMode)
  func setVideoPlaybackSettings(_ settings: VideoPlaybackSettings)

  func updateInteraction(_ state: InteractionState)
  func updateAudio(_ frame: AudioFrame)
  func setProperties(
    _ properties: [String: WallpaperPropertyValue]
  )
}

extension WallpaperRenderer {
  var diagnostics: RendererDiagnostics {
    RendererDiagnostics(
      rendererName: String(describing: type(of: self)),
      preferredFPS: 0,
      renderScale: 1,
      pixelWidth: 0,
      pixelHeight: 0,
      playbackRate: nil,
      muted: nil
    )
  }

  func configure(for display: DisplayDescriptor) {}
  func setFPS(_ fps: Int) {}
  func setRenderScale(_ scale: Double) {}
  func setFitMode(_ mode: WallpaperFitMode) {}
  func setVideoPlaybackSettings(
    _ settings: VideoPlaybackSettings
  ) {}
  func updateInteraction(_ state: InteractionState) {}
  func updateAudio(_ frame: AudioFrame) {}
  func setProperties(
    _ properties: [String: WallpaperPropertyValue]
  ) {}
}
