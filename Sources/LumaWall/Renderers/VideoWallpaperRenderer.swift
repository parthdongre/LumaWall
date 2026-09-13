import AVFoundation
import AppKit

private final class PlayerView: NSView {
  override func makeBackingLayer()
    -> CALayer
  {
    AVPlayerLayer()
  }

  var playerLayer:
    AVPlayerLayer
  {
    layer as! AVPlayerLayer
  }
}

@MainActor
final class VideoWallpaperRenderer:
  WallpaperRenderer
{
  private let playerView =
    PlayerView()

  private var player:
    AVQueuePlayer?

  private var looper:
    AVPlayerLooper?

  private var displaySize =
    CGSize.zero

  private var renderScale =
    1.0

  private var preferredFPS =
    60

  private var settings =
    VideoPlaybackSettings()

  private var fitMode:
    WallpaperFitMode =
    .fill

  var view: NSView {
    playerView
  }

  var diagnostics:
    RendererDiagnostics
  {
    RendererDiagnostics(
      rendererName:
        "Video / AVFoundation",
      preferredFPS:
        preferredFPS,
      renderScale:
        renderScale,
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
      playbackRate:
        settings.playbackRate,
      muted:
        settings.muted
    )
  }

  init() {
    playerView.wantsLayer =
      true

    playerView.playerLayer
      .videoGravity =
      .resizeAspectFill

    playerView.playerLayer
      .backgroundColor =
      NSColor.black.cgColor
  }

  func load(
    _ wallpaper: Wallpaper
  ) throws {
    let asset =
      AVURLAsset(
        url:
          wallpaper.entryURL
      )

    let item =
      AVPlayerItem(
        asset: asset
      )

    item.preferredForwardBufferDuration =
      2

    let queue =
      AVQueuePlayer()

    queue.isMuted =
      settings.muted

    queue.actionAtItemEnd =
      settings.loop
      ? .advance
      : .pause

    player = queue

    looper =
      settings.loop
      ? AVPlayerLooper(
        player: queue,
        templateItem: item
      )
      : nil

    if !settings.loop {
      queue.insert(
        item,
        after: nil
      )
    }

    playerView.playerLayer
      .player =
      queue

    playerView.playerLayer
      .videoGravity =
      fitMode.videoGravity
  }

  func configure(
    for display:
      DisplayDescriptor
  ) {
    displaySize =
      display.nativePixelSize

    preferredFPS =
      min(
        preferredFPS,
        display.maximumFPS
      )

    playerView.layer?
      .contentsScale =
      display.backingScaleFactor
  }

  func setFPS(
    _ fps: Int
  ) {
    preferredFPS =
      max(
        1,
        fps
      )
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
    fitMode = mode

    playerView.playerLayer
      .videoGravity =
      mode.videoGravity
  }

  func setVideoPlaybackSettings(
    _ settings:
      VideoPlaybackSettings
  ) {
    self.settings =
      settings

    player?.isMuted =
      settings.muted

    if player?
      .timeControlStatus
      == .playing
    {
      player?.rate =
        Float(
          settings.playbackRate
        )
    }
  }

  func play() {
    player?.play()

    player?.rate =
      Float(
        settings.playbackRate
      )
  }

  func pause() {
    player?.pause()
  }

  func stop() {
    player?.pause()

    looper?
      .disableLooping()

    looper = nil
    player = nil

    playerView.playerLayer
      .player = nil
  }
}
