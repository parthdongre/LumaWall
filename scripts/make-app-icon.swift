#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
  fputs("Usage: make-app-icon.swift <output.iconset>\n", stderr)
  exit(2)
}

let outputDirectory = URL(
  fileURLWithPath: CommandLine.arguments[1],
  isDirectory: true
)

try FileManager.default.createDirectory(
  at: outputDirectory,
  withIntermediateDirectories: true
)

struct IconVariant {
  let filename: String
  let pixels: Int
}

let variants = [
  IconVariant(filename: "icon_16x16.png", pixels: 16),
  IconVariant(filename: "icon_16x16@2x.png", pixels: 32),
  IconVariant(filename: "icon_32x32.png", pixels: 32),
  IconVariant(filename: "icon_32x32@2x.png", pixels: 64),
  IconVariant(filename: "icon_128x128.png", pixels: 128),
  IconVariant(filename: "icon_128x128@2x.png", pixels: 256),
  IconVariant(filename: "icon_256x256.png", pixels: 256),
  IconVariant(filename: "icon_256x256@2x.png", pixels: 512),
  IconVariant(filename: "icon_512x512.png", pixels: 512),
  IconVariant(filename: "icon_512x512@2x.png", pixels: 1024),
]

func makeIcon(size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  defer { image.unlockFocus() }

  guard let context = NSGraphicsContext.current?.cgContext else {
    return image
  }

  context.setAllowsAntialiasing(true)
  context.setShouldAntialias(true)

  let outerInset = size * 0.045
  let outerRect = CGRect(
    x: outerInset,
    y: outerInset,
    width: size - outerInset * 2,
    height: size - outerInset * 2
  )
  let cornerRadius = size * 0.215
  let outerPath = CGPath(
    roundedRect: outerRect,
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
  )

  context.saveGState()
  context.addPath(outerPath)
  context.clip()

  let backgroundColors = [
    NSColor(calibratedRed: 0.025, green: 0.028, blue: 0.045, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.095, green: 0.035, blue: 0.11, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.018, green: 0.018, blue: 0.027, alpha: 1).cgColor,
  ] as CFArray

  let backgroundGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: backgroundColors,
    locations: [0, 0.52, 1]
  )!

  context.drawLinearGradient(
    backgroundGradient,
    start: CGPoint(x: size * 0.18, y: size * 0.92),
    end: CGPoint(x: size * 0.86, y: size * 0.08),
    options: []
  )

  let glowColors = [
    NSColor(calibratedRed: 0.94, green: 0.055, blue: 0.26, alpha: 0.78).cgColor,
    NSColor(calibratedRed: 0.95, green: 0.08, blue: 0.39, alpha: 0).cgColor,
  ] as CFArray
  let glowGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: glowColors,
    locations: [0, 1]
  )!

  context.drawRadialGradient(
    glowGradient,
    startCenter: CGPoint(x: size * 0.72, y: size * 0.72),
    startRadius: 0,
    endCenter: CGPoint(x: size * 0.72, y: size * 0.72),
    endRadius: size * 0.58,
    options: [.drawsAfterEndLocation]
  )

  let coolGlowColors = [
    NSColor(calibratedRed: 0.34, green: 0.22, blue: 1, alpha: 0.45).cgColor,
    NSColor(calibratedRed: 0.20, green: 0.16, blue: 0.95, alpha: 0).cgColor,
  ] as CFArray
  let coolGlow = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: coolGlowColors,
    locations: [0, 1]
  )!

  context.drawRadialGradient(
    coolGlow,
    startCenter: CGPoint(x: size * 0.25, y: size * 0.26),
    startRadius: 0,
    endCenter: CGPoint(x: size * 0.25, y: size * 0.26),
    endRadius: size * 0.52,
    options: [.drawsAfterEndLocation]
  )

  context.setFillColor(
    NSColor(calibratedWhite: 1, alpha: 0.055).cgColor
  )
  let glassRect = CGRect(
    x: size * 0.17,
    y: size * 0.18,
    width: size * 0.66,
    height: size * 0.64
  )
  let glassPath = CGPath(
    roundedRect: glassRect,
    cornerWidth: size * 0.11,
    cornerHeight: size * 0.11,
    transform: nil
  )
  context.addPath(glassPath)
  context.fillPath()

  context.setStrokeColor(
    NSColor(calibratedWhite: 1, alpha: 0.22).cgColor
  )
  context.setLineWidth(size * 0.018)
  context.addPath(glassPath)
  context.strokePath()

  func drawWave(
    from start: CGPoint,
    control1: CGPoint,
    control2: CGPoint,
    to end: CGPoint,
    width: CGFloat,
    color: NSColor
  ) {
    let path = CGMutablePath()
    path.move(to: start)
    path.addCurve(to: end, control1: control1, control2: control2)

    context.saveGState()
    context.setLineCap(.round)
    context.setLineJoin(.round)

    context.setStrokeColor(color.withAlphaComponent(0.22).cgColor)
    context.setLineWidth(width * 2.5)
    context.addPath(path)
    context.strokePath()

    context.setStrokeColor(color.cgColor)
    context.setLineWidth(width)
    context.addPath(path)
    context.strokePath()
    context.restoreGState()
  }

  drawWave(
    from: CGPoint(x: size * 0.24, y: size * 0.35),
    control1: CGPoint(x: size * 0.38, y: size * 0.20),
    control2: CGPoint(x: size * 0.52, y: size * 0.72),
    to: CGPoint(x: size * 0.76, y: size * 0.58),
    width: size * 0.037,
    color: NSColor(calibratedRed: 1, green: 0.19, blue: 0.36, alpha: 0.96)
  )

  drawWave(
    from: CGPoint(x: size * 0.24, y: size * 0.50),
    control1: CGPoint(x: size * 0.40, y: size * 0.67),
    control2: CGPoint(x: size * 0.55, y: size * 0.35),
    to: CGPoint(x: size * 0.76, y: size * 0.70),
    width: size * 0.023,
    color: NSColor(calibratedRed: 0.72, green: 0.57, blue: 1, alpha: 0.94)
  )

  context.restoreGState()

  context.setStrokeColor(
    NSColor(calibratedWhite: 1, alpha: 0.20).cgColor
  )
  context.setLineWidth(max(1, size * 0.006))
  context.addPath(outerPath)
  context.strokePath()

  return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
  guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let data = bitmap.representation(using: .png, properties: [:])
  else {
    throw NSError(
      domain: "LumaWallIcon",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Could not encode app icon PNG."]
    )
  }

  try data.write(to: url, options: .atomic)
}

for variant in variants {
  let image = makeIcon(size: CGFloat(variant.pixels))
  try writePNG(
    image,
    to: outputDirectory.appendingPathComponent(variant.filename)
  )
}

print("Generated LumaWall iconset at \(outputDirectory.path)")
