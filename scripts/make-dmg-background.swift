import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
  fputs("usage: make-dmg-background.swift <output.png>\n", stderr)
  exit(1)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 660, height: 420)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let gradient = NSGradient(
  colors: [
    NSColor(calibratedRed: 0.055, green: 0.063, blue: 0.09, alpha: 1),
    NSColor(calibratedRed: 0.095, green: 0.075, blue: 0.17, alpha: 1),
  ]
)!
gradient.draw(in: rect, angle: -20)

let glow = NSBezierPath(ovalIn: NSRect(x: 380, y: 210, width: 300, height: 300))
NSColor(calibratedRed: 0.35, green: 0.24, blue: 0.75, alpha: 0.22).setFill()
glow.fill()

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center

let titleAttributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 28, weight: .bold),
  .foregroundColor: NSColor.white,
  .paragraphStyle: titleStyle,
]

let subtitleAttributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 15, weight: .medium),
  .foregroundColor: NSColor.white.withAlphaComponent(0.72),
  .paragraphStyle: titleStyle,
]

let arrowAttributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 44, weight: .light),
  .foregroundColor: NSColor.white.withAlphaComponent(0.48),
  .paragraphStyle: titleStyle,
]

("LumaWall" as NSString).draw(
  in: NSRect(x: 0, y: 344, width: size.width, height: 40),
  withAttributes: titleAttributes
)

("Drag LumaWall to Applications" as NSString).draw(
  in: NSRect(x: 0, y: 316, width: size.width, height: 24),
  withAttributes: subtitleAttributes
)

("→" as NSString).draw(
  in: NSRect(x: 270, y: 155, width: 120, height: 64),
  withAttributes: arrowAttributes
)

let footerAttributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 11, weight: .regular),
  .foregroundColor: NSColor.white.withAlphaComponent(0.42),
  .paragraphStyle: titleStyle,
]

("Native live wallpapers for macOS" as NSString).draw(
  in: NSRect(x: 0, y: 24, width: size.width, height: 18),
  withAttributes: footerAttributes
)

image.unlockFocus()

guard
  let tiff = image.tiffRepresentation,
  let rep = NSBitmapImageRep(data: tiff),
  let png = rep.representation(using: .png, properties: [:])
else {
  fputs("failed to render DMG background\n", stderr)
  exit(2)
}

try FileManager.default.createDirectory(
  at: output.deletingLastPathComponent(),
  withIntermediateDirectories: true
)
try png.write(to: output, options: .atomic)
