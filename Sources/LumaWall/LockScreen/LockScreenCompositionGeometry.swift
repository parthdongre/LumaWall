import CoreGraphics
import Foundation

enum LockScreenCompositionGeometry {
  static func destinationRect(
    sourceSize: CGSize,
    targetSize: CGSize,
    fitMode: WallpaperFitMode
  ) -> CGRect {
    guard
      sourceSize.width > 0,
      sourceSize.height > 0,
      targetSize.width > 0,
      targetSize.height > 0
    else {
      return CGRect(origin: .zero, size: targetSize)
    }

    switch fitMode {
    case .stretch:
      return CGRect(origin: .zero, size: targetSize)

    case .center:
      return CGRect(
        x: (targetSize.width - sourceSize.width) / 2,
        y: (targetSize.height - sourceSize.height) / 2,
        width: sourceSize.width,
        height: sourceSize.height
      )

    case .fit, .fill:
      let widthScale = targetSize.width / sourceSize.width
      let heightScale = targetSize.height / sourceSize.height
      let scale = fitMode == .fill
        ? max(widthScale, heightScale)
        : min(widthScale, heightScale)

      let width = sourceSize.width * scale
      let height = sourceSize.height * scale

      return CGRect(
        x: (targetSize.width - width) / 2,
        y: (targetSize.height - height) / 2,
        width: width,
        height: height
      )
    }
  }
}
