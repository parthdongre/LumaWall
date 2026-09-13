import AppKit

@MainActor
protocol WallpaperRenderer: AnyObject {
  var view: NSView { get }
  func load(_ wallpaper: Wallpaper) throws
  func play()
  func pause()
  func stop()
  func configure(for display: DisplayDescriptor)
  func setFPS(_ fps: Int)
  func setRenderScale(_ scale: Double)
  func updateInteraction(_ state: InteractionState)
  func updateAudio(_ frame: AudioFrame)
  func setProperties(_ properties: [String: WallpaperPropertyValue])
}

extension WallpaperRenderer {
  func configure(for display: DisplayDescriptor) {}
  func setFPS(_ fps: Int) {}
  func setRenderScale(_ scale: Double) {}
  func updateInteraction(_ state: InteractionState) {}
  func updateAudio(_ frame: AudioFrame) {}
  func setProperties(_ properties: [String: WallpaperPropertyValue]) {}
}
