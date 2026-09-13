import AppKit
import CoreImage
import Foundation

@MainActor
final class LockScreenSnapshotService {
  private let fileManager = FileManager.default
  private let previewGenerator = PreviewGenerator()

  var snapshotRoot: URL {
    fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]
    .appendingPathComponent("LumaWall", isDirectory: true)
    .appendingPathComponent("LockScreen", isDirectory: true)
  }

  func generate(
    wallpaper: Wallpaper,
    display: DisplayDescriptor,
    settings: LockScreenCompanionSettings,
    timeDateSettings: TimeDateOverlaySettings?,
    propertyValues: [String: WallpaperPropertyValue]
  ) async throws -> LockScreenSnapshot {
    let targetSize = CGSize(
      width: max(1, display.nativePixelSize.width),
      height: max(1, display.nativePixelSize.height)
    )

    let source = try await previewGenerator.renderImage(
      for: wallpaper,
      targetSize: targetSize,
      propertyValues: propertyValues
    )

    let composed = try compose(
      source: source,
      targetSize: targetSize,
      fitMode: settings.fitMode,
      blurRadius: settings.blurRadius,
      dimAmount: settings.dimAmount,
      saturation: settings.saturation,
      vignetteIntensity: settings.vignetteIntensity
    )

    if
      settings.includeWallpaperTimeDate,
      let timeDateSettings,
      timeDateSettings.enabled
    {
      drawTimeDate(
        timeDateSettings,
        into: composed,
        targetSize: targetSize,
        backingScale: max(display.backingScaleFactor, 1)
      )
    }

    try fileManager.createDirectory(
      at: snapshotRoot,
      withIntermediateDirectories: true
    )

    let fileURL = snapshotRoot.appendingPathComponent(
      "display-\(display.id).png"
    )

    guard
      let png = composed.representation(
        using: .png,
        properties: [:]
      )
    else {
      throw LockScreenCompanionError.couldNotEncodePNG
    }

    try png.write(to: fileURL, options: .atomic)

    return LockScreenSnapshot(
      displayID: display.id,
      displayName: display.name,
      wallpaperID: wallpaper.id,
      wallpaperName: wallpaper.name,
      fileURL: fileURL,
      pixelWidth: Int(targetSize.width),
      pixelHeight: Int(targetSize.height),
      generatedAt: Date()
    )
  }

  func revealSnapshotFolder() {
    try? fileManager.createDirectory(
      at: snapshotRoot,
      withIntermediateDirectories: true
    )
    NSWorkspace.shared.open(snapshotRoot)
  }

  func openWallpaperSettings() {
    openSystemSettings(
      "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"
    )
  }

  func openScreenSaverSettings() {
    openSystemSettings(
      "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension"
    )
  }

  private func openSystemSettings(_ pane: String) {
    if let url = URL(string: pane), NSWorkspace.shared.open(url) {
      return
    }

    NSWorkspace.shared.open(
      URL(fileURLWithPath: "/System/Applications/System Settings.app")
    )
  }

  private func compose(
    source: NSImage,
    targetSize: CGSize,
    fitMode: WallpaperFitMode,
    blurRadius: Double,
    dimAmount: Double,
    saturation: Double,
    vignetteIntensity: Double
  ) throws -> NSBitmapImageRep {
    guard let sourceCG = cgImage(from: source) else {
      throw LockScreenCompanionError.couldNotCreateBitmap
    }

    guard
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: max(1, Int(targetSize.width.rounded())),
        pixelsHigh: max(1, Int(targetSize.height.rounded())),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: false,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      ),
      let graphics = NSGraphicsContext(bitmapImageRep: bitmap)
    else {
      throw LockScreenCompanionError.couldNotCreateBitmap
    }

    bitmap.size = targetSize
    let sourceSize = CGSize(width: sourceCG.width, height: sourceCG.height)
    let destination = LockScreenCompositionGeometry.destinationRect(
      sourceSize: sourceSize,
      targetSize: targetSize,
      fitMode: fitMode
    )

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    NSColor.black.setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()

    NSImage(cgImage: sourceCG, size: sourceSize).draw(
      in: destination,
      from: CGRect(origin: .zero, size: sourceSize),
      operation: .copy,
      fraction: 1
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let rasterCG = bitmap.cgImage else {
      throw LockScreenCompanionError.couldNotCreateBitmap
    }

    let extent = CGRect(origin: .zero, size: targetSize)
    var image = CIImage(cgImage: rasterCG)

    image = image.applyingFilter(
      "CIColorControls",
      parameters: [
        kCIInputSaturationKey: min(max(saturation, 0), 2)
      ]
    )

    let blur = min(max(blurRadius, 0), 60)
    if blur > 0.01 {
      image = image
        .clampedToExtent()
        .applyingFilter(
          "CIGaussianBlur",
          parameters: [kCIInputRadiusKey: blur]
        )
        .cropped(to: extent)
    }

    let vignette = min(max(vignetteIntensity, 0), 2)
    if vignette > 0.01 {
      image = image.applyingFilter(
        "CIVignette",
        parameters: [
          kCIInputIntensityKey: vignette,
          kCIInputRadiusKey: min(targetSize.width, targetSize.height) * 0.65,
        ]
      )
    }

    let dim = min(max(dimAmount, 0), 0.9)
    if dim > 0.001 {
      let overlay = CIImage(
        color: CIColor(red: 0, green: 0, blue: 0, alpha: dim)
      )
      .cropped(to: extent)

      image = overlay.composited(over: image)
    }

    let context = CIContext()
    guard let filteredCG = context.createCGImage(image, from: extent) else {
      throw LockScreenCompanionError.couldNotCreateBitmap
    }

    let filtered = NSBitmapImageRep(cgImage: filteredCG)
    filtered.size = targetSize
    return filtered
  }

  private func cgImage(from image: NSImage) -> CGImage? {
    var rect = CGRect(origin: .zero, size: image.size)
    return image.cgImage(
      forProposedRect: &rect,
      context: nil,
      hints: nil
    )
  }

  private func drawTimeDate(
    _ settings: TimeDateOverlaySettings,
    into bitmap: NSBitmapImageRep,
    targetSize: CGSize,
    backingScale: CGFloat
  ) {
    guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
      return
    }

    let scale = max(backingScale, 1)
    let date = Date()

    let time = Self.timeString(date, settings: settings)
    let dateText = Self.dateString(date, settings: settings)

    let color = NSColor(
      lumawallHex: settings.colorHex
    ).withAlphaComponent(CGFloat(settings.opacity))

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    var timeAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(
        ofSize: CGFloat(settings.timeFontSize) * scale,
        weight: settings.fontWeight.nsWeight
      ),
      .foregroundColor: color,
      .paragraphStyle: paragraph,
    ]

    var dateAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(
        ofSize: CGFloat(settings.dateFontSize) * scale,
        weight: .medium
      ),
      .foregroundColor: color.withAlphaComponent(0.9),
      .paragraphStyle: paragraph,
    ]

    if settings.shadow {
      let shadow = NSShadow()
      shadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
      shadow.shadowBlurRadius = 12 * scale
      shadow.shadowOffset = NSSize(width: 0, height: -2 * scale)
      timeAttributes[.shadow] = shadow
      dateAttributes[.shadow] = shadow
    }

    let timeSize = (time as NSString).size(withAttributes: timeAttributes)
    let dateSize =
      settings.dateStyle == .none
      ? .zero
      : (dateText as NSString).size(withAttributes: dateAttributes)

    let paddingX = 24 * scale
    let paddingY = 18 * scale
    let gap = settings.dateStyle == .none ? 0 : 5 * scale

    let overlaySize = CGSize(
      width: max(timeSize.width, dateSize.width) + paddingX * 2,
      height: timeSize.height + dateSize.height + gap + paddingY * 2
    )

    var pixelSettings = settings
    pixelSettings.horizontalInset *= Double(scale)
    pixelSettings.verticalInset *= Double(scale)

    let origin = ClockOverlayLayout.appKitOrigin(
      boundsSize: targetSize,
      overlaySize: overlaySize,
      settings: pixelSettings
    )

    let overlayRect = CGRect(origin: origin, size: overlaySize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    let cardOpacity =
      settings.glassEnabled
      ? max(settings.backgroundOpacity, settings.glassOpacity * 0.30)
      : settings.backgroundOpacity

    if cardOpacity > 0.001 {
      NSColor.black
        .withAlphaComponent(CGFloat(min(cardOpacity, 0.8)))
        .setFill()

      NSBezierPath(
        roundedRect: overlayRect,
        xRadius: CGFloat(settings.cornerRadius) * scale,
        yRadius: CGFloat(settings.cornerRadius) * scale
      ).fill()
    }

    let timeRect = CGRect(
      x: overlayRect.minX + paddingX,
      y: overlayRect.maxY - paddingY - timeSize.height,
      width: overlayRect.width - paddingX * 2,
      height: timeSize.height
    )

    (time as NSString).draw(
      in: timeRect,
      withAttributes: timeAttributes
    )

    if settings.dateStyle != .none {
      let dateRect = CGRect(
        x: overlayRect.minX + paddingX,
        y: timeRect.minY - gap - dateSize.height,
        width: overlayRect.width - paddingX * 2,
        height: dateSize.height
      )

      (dateText as NSString).draw(
        in: dateRect,
        withAttributes: dateAttributes
      )
    }

    NSGraphicsContext.restoreGraphicsState()
  }

  private static func timeString(
    _ date: Date,
    settings: TimeDateOverlaySettings
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = settings.localeIdentifier
      .map { Locale(identifier: $0) }
      ?? .autoupdatingCurrent
    formatter.timeZone = settings.timezoneIdentifier
      .flatMap { TimeZone(identifier: $0) }
      ?? .autoupdatingCurrent

    switch settings.hourFormat {
    case .system:
      formatter.timeStyle = settings.showSeconds ? .medium : .short
      formatter.dateStyle = .none
    case .twelveHour:
      formatter.dateFormat = settings.showSeconds ? "h:mm:ss a" : "h:mm a"
    case .twentyFourHour:
      formatter.dateFormat = settings.showSeconds ? "HH:mm:ss" : "HH:mm"
    }

    return formatter.string(from: date)
  }

  private static func dateString(
    _ date: Date,
    settings: TimeDateOverlaySettings
  ) -> String {
    guard settings.dateStyle != .none else { return "" }

    let locale = settings.localeIdentifier
      .map { Locale(identifier: $0) }
      ?? .autoupdatingCurrent
    let timezone = settings.timezoneIdentifier
      .flatMap { TimeZone(identifier: $0) }
      ?? .autoupdatingCurrent

    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timezone
    formatter.timeStyle = .none
    formatter.dateStyle = settings.dateStyle.foundationStyle

    var value = formatter.string(from: date)

    if settings.showWeekday && settings.dateStyle != .full {
      let weekday = DateFormatter()
      weekday.locale = locale
      weekday.timeZone = timezone
      weekday.dateFormat = "EEEE"
      value = weekday.string(from: date) + " • " + value
    }

    return settings.uppercaseDate ? value.uppercased() : value
  }
}

private extension ClockFontWeight {
  var nsWeight: NSFont.Weight {
    switch self {
    case .ultraLight: return .ultraLight
    case .light: return .light
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    }
  }
}

private extension ClockDateStyle {
  var foundationStyle: DateFormatter.Style {
    switch self {
    case .none: return .none
    case .short: return .short
    case .medium: return .medium
    case .long: return .long
    case .full: return .full
    }
  }
}

private extension NSColor {
  convenience init(lumawallHex: String) {
    var hex = lumawallHex
    if hex.hasPrefix("#") {
      hex.removeFirst()
    }

    let value = UInt64(hex, radix: 16) ?? 0xFFFFFF

    self.init(
      red: CGFloat((value >> 16) & 255) / 255,
      green: CGFloat((value >> 8) & 255) / 255,
      blue: CGFloat(value & 255) / 255,
      alpha: 1
    )
  }
}
