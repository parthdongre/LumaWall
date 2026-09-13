import AppKit
import SwiftUI

struct LiveWallpaperPreview: View {
  let wallpaper: Wallpaper
  let active: Bool

  var body: some View {
    Group {
      if active {
        RendererPreviewRepresentable(
          wallpaper: wallpaper
        )
      } else {
        WallpaperThumbnail(
          wallpaper: wallpaper
        )
      }
    }
    .clipped()
    .clipShape(
      RoundedRectangle(
        cornerRadius: 12
      )
    )
  }
}

private struct RendererPreviewRepresentable:
  NSViewRepresentable
{
  let wallpaper: Wallpaper

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(
    context: Context
  ) -> NSView {
    let container = NSView()
    container.wantsLayer = true
    container.layer?.backgroundColor =
      NSColor.black.cgColor

    context.coordinator.load(
      wallpaper,
      into: container
    )

    return container
  }

  func updateNSView(
    _ nsView: NSView,
    context: Context
  ) {
    if
      context.coordinator
        .wallpaperID
        != wallpaper.id
    {
      context.coordinator.load(
        wallpaper,
        into: nsView
      )
    }
  }

  static func dismantleNSView(
    _ nsView: NSView,
    coordinator: Coordinator
  ) {
    coordinator.stop()
    nsView.subviews.forEach {
      $0.removeFromSuperview()
    }
  }

  @MainActor
  final class Coordinator {
    private var renderer:
      WallpaperRenderer?

    private(set) var wallpaperID:
      UUID?

    func load(
      _ wallpaper: Wallpaper,
      into container: NSView
    ) {
      stop()

      let renderer =
        RendererFactory
          .makeRenderer(
            for:
              wallpaper.type
          )

      do {
        try renderer.load(
          wallpaper
        )

        renderer.setFPS(30)
        renderer.setRenderScale(0.35)
        renderer.setFitMode(.fill)
        renderer.setProperties(
          Dictionary(
            uniqueKeysWithValues:
              wallpaper
                .properties
                .map {
                  (
                    $0.id,
                    $0.defaultValue
                  )
                }
          )
        )

        let view = renderer.view
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)

        NSLayoutConstraint.activate([
          view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
          view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
          view.topAnchor.constraint(equalTo: container.topAnchor),
          view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.renderer = renderer
        wallpaperID = wallpaper.id
        renderer.play()
      } catch {
        renderer.stop()
        wallpaperID = nil
      }
    }

    func stop() {
      guard let renderer else {
        wallpaperID = nil
        return
      }

      renderer.pause()
      renderer.stop()
      renderer.view.removeFromSuperview()

      self.renderer = nil
      wallpaperID = nil
    }
  }
}
