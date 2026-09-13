import CoreGraphics
import Foundation

enum ClockOverlayLayout {
  static func normalizedPoint(
    for settings: TimeDateOverlaySettings
  ) -> CGPoint {
    if
      let x = settings.customNormalizedX,
      let y = settings.customNormalizedY
    {
      return CGPoint(
        x: CGFloat(min(max(x, 0), 1)),
        y: CGFloat(min(max(y, 0), 1))
      )
    }

    switch settings.position {
    case .topLeft:
      return CGPoint(x: 0.16, y: 0.16)
    case .topCenter:
      return CGPoint(x: 0.5, y: 0.16)
    case .topRight:
      return CGPoint(x: 0.84, y: 0.16)
    case .centerLeft:
      return CGPoint(x: 0.16, y: 0.5)
    case .center:
      return CGPoint(x: 0.5, y: 0.5)
    case .centerRight:
      return CGPoint(x: 0.84, y: 0.5)
    case .bottomLeft:
      return CGPoint(x: 0.16, y: 0.84)
    case .bottomCenter:
      return CGPoint(x: 0.5, y: 0.84)
    case .bottomRight:
      return CGPoint(x: 0.84, y: 0.84)
    }
  }

  static func customPoint(
    fromPreviewLocation location: CGPoint,
    previewSize: CGSize
  ) -> CGPoint {
    guard previewSize.width > 0, previewSize.height > 0 else {
      return CGPoint(x: 0.5, y: 0.5)
    }

    return CGPoint(
      x: min(max(location.x / previewSize.width, 0.04), 0.96),
      y: min(max(location.y / previewSize.height, 0.04), 0.96)
    )
  }

  static func appKitOrigin(
    boundsSize: CGSize,
    overlaySize: CGSize,
    settings: TimeDateOverlaySettings
  ) -> CGPoint {
    let horizontal = CGFloat(settings.horizontalInset)
    let vertical = CGFloat(settings.verticalInset)

    if settings.customNormalizedX != nil, settings.customNormalizedY != nil {
      let normalized = normalizedPoint(for: settings)
      let centerX = normalized.x * boundsSize.width

      // Creator/SwiftUI preview coordinates are top-down. AppKit is bottom-up.
      let centerY = (1 - normalized.y) * boundsSize.height

      let minX = horizontal
      let maxX = max(horizontal, boundsSize.width - overlaySize.width - horizontal)
      let minY = vertical
      let maxY = max(vertical, boundsSize.height - overlaySize.height - vertical)

      return CGPoint(
        x: min(max(centerX - overlaySize.width / 2, minX), maxX),
        y: min(max(centerY - overlaySize.height / 2, minY), maxY)
      )
    }

    let left = horizontal
    let centerX = (boundsSize.width - overlaySize.width) / 2
    let right = boundsSize.width - overlaySize.width - horizontal

    let bottom = vertical
    let centerY = (boundsSize.height - overlaySize.height) / 2
    let top = boundsSize.height - overlaySize.height - vertical

    switch settings.position {
    case .topLeft: return CGPoint(x: left, y: top)
    case .topCenter: return CGPoint(x: centerX, y: top)
    case .topRight: return CGPoint(x: right, y: top)
    case .centerLeft: return CGPoint(x: left, y: centerY)
    case .center: return CGPoint(x: centerX, y: centerY)
    case .centerRight: return CGPoint(x: right, y: centerY)
    case .bottomLeft: return CGPoint(x: left, y: bottom)
    case .bottomCenter: return CGPoint(x: centerX, y: bottom)
    case .bottomRight: return CGPoint(x: right, y: bottom)
    }
  }
}
