import AVFoundation
import AppKit

private final class PlayerView: NSView {
  override func makeBackingLayer() -> CALayer { AVPlayerLayer() }
  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

@MainActor
final class VideoWallpaperRenderer: WallpaperRenderer {
  private let playerView = PlayerView()
  private var player: AVQueuePlayer?
  private var looper: AVPlayerLooper?

  var view: NSView { playerView }

  init() {
    playerView.wantsLayer = true
    playerView.playerLayer.videoGravity = .resizeAspectFill
    playerView.playerLayer.backgroundColor = NSColor.black.cgColor
  }

  func load(_ wallpaper: Wallpaper) throws {
    let asset = AVURLAsset(url: wallpaper.entryURL)
    let item = AVPlayerItem(asset: asset)
    let queue = AVQueuePlayer()
    queue.isMuted = true

    player = queue
    looper = AVPlayerLooper(player: queue, templateItem: item)
    playerView.playerLayer.player = queue
  }

  func configure(for display: DisplayDescriptor) {
    playerView.layer?.contentsScale = display.backingScaleFactor
  }

  func play() { player?.play() }
  func pause() { player?.pause() }

  func stop() {
    player?.pause()
    looper?.disableLooping()
    looper = nil
    player = nil
    playerView.playerLayer.player = nil
  }
}
