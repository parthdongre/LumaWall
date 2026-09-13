import AVFoundation
import AppKit
import CoreImage
import Metal
import WebKit

private struct PreviewMetalUniforms {
  var time: Float
  var resolutionX: Float
  var resolutionY: Float
  var mouseX: Float
  var mouseY: Float
  var audioLevel: Float
  var audioBass: Float
  var audioMid: Float
  var audioTreble: Float
  var property0: SIMD4<Float>
  var property1: SIMD4<Float>
  var property2: SIMD4<Float>
  var property3: SIMD4<Float>
}

@MainActor
final class PreviewGenerator: NSObject {
  private let size = CGSize(width: 640, height: 360)

  func generate(for wallpaper: Wallpaper, destination: URL) async throws {
    let image: NSImage
    switch wallpaper.type {
    case .image:
      guard let loaded = NSImage(contentsOf: wallpaper.entryURL) else {
        throw WallpaperError.unreadableAsset(wallpaper.entryURL)
      }
      image = loaded
    case .video:
      image = try videoPreview(url: wallpaper.entryURL)
    case .web:
      image = try await webPreview(
        url: wallpaper.entryURL,
        allowNetwork: wallpaper.grantedPermissions.contains(.network)
      )
    case .metal:
      image = try metalPreview(wallpaper: wallpaper)
    }
    try writeJPEG(image, to: destination)
  }

  private func videoPreview(url: URL) throws -> NSImage {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    let cg = try generator.copyCGImage(
      at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil)
    return NSImage(cgImage: cg, size: .zero)
  }

  private func webPreview(url: URL, allowNetwork: Bool) async throws -> NSImage {
    let config = WebSecurityPolicy.baseConfiguration()
    if !allowNetwork {
      let ok = await withCheckedContinuation { continuation in
        WebSecurityPolicy.installNetworkBlocker(on: config.userContentController) {
          continuation.resume(returning: $0)
        }
      }
      guard ok else {
        throw WallpaperError.permissionDenied("Could not initialize web network sandbox")
      }
    }
    let webView = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: config)
    let delegate = SnapshotNavigationDelegate()
    webView.navigationDelegate = delegate
    webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    try await delegate.waitUntilFinished()
    try await Task.sleep(nanoseconds: 250_000_000)
    return try await webView.takeSnapshot(configuration: nil)
  }

  private func metalPreview(wallpaper: Wallpaper) throws -> NSImage {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      throw WallpaperError.packageOperationFailed("Metal is unavailable")
    }
    let fragmentSource = try String(contentsOf: wallpaper.entryURL, encoding: .utf8)
    let library = try device.makeLibrary(
      source: Self.previewVertexSource + "\n" + fragmentSource, options: nil)
    guard let vertex = library.makeFunction(name: "lumawall_vertex"),
      let fragment = library.makeFunction(name: "lumawall_fragment")
    else {
      throw WallpaperError.invalidMetalShader
    }

    let width = Int(size.width)
    let height = Int(size.height)
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm,
      width: width,
      height: height,
      mipmapped: false
    )
    textureDescriptor.usage = [.renderTarget, .shaderRead]
    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
      throw WallpaperError.packageOperationFailed("Could not create Metal preview texture")
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertex
    pipelineDescriptor.fragmentFunction = fragment
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    let pipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

    guard let command = queue.makeCommandBuffer(),
      let encoder = command.makeRenderCommandEncoder(descriptor: pass)
    else {
      throw WallpaperError.packageOperationFailed("Could not create Metal preview encoder")
    }

    let slots = propertySlots(for: wallpaper.properties)
    var uniforms = PreviewMetalUniforms(
      time: 1.4,
      resolutionX: Float(width),
      resolutionY: Float(height),
      mouseX: 0.5,
      mouseY: 0.5,
      audioLevel: 0.25,
      audioBass: 0.2,
      audioMid: 0.15,
      audioTreble: 0.1,
      property0: slots[0],
      property1: slots[1],
      property2: slots[2],
      property3: slots[3]
    )
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<PreviewMetalUniforms>.stride, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()

    guard
      let ciImage = CIImage(
        mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()])
    else {
      throw WallpaperError.packageOperationFailed("Could not read Metal preview texture")
    }
    let context = CIContext(mtlDevice: device)
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
      throw WallpaperError.packageOperationFailed("Could not render Metal preview image")
    }
    return NSImage(cgImage: cgImage, size: size)
  }

  private func propertySlots(for definitions: [WallpaperProperty]) -> [SIMD4<Float>] {
    var flat = [Float](repeating: 0, count: 16)
    var cursor = 0
    for definition in definitions where cursor < flat.count {
      switch definition.defaultValue {
      case .number(let value):
        flat[cursor] = Float(value)
        cursor += 1
      case .bool(let value):
        flat[cursor] = value ? 1 : 0
        cursor += 1
      case .string(let value):
        if definition.kind == .color, let rgb = parseHex(value), cursor + 2 < flat.count {
          flat[cursor] = rgb.0
          flat[cursor + 1] = rgb.1
          flat[cursor + 2] = rgb.2
          cursor += 3
        } else if definition.kind == .dropdown {
          flat[cursor] = Float(definition.options?.firstIndex(of: value) ?? 0)
          cursor += 1
        } else {
          cursor += 1
        }
      }
    }
    return stride(from: 0, to: 16, by: 4).map {
      SIMD4(flat[$0], flat[$0 + 1], flat[$0 + 2], flat[$0 + 3])
    }
  }

  private func parseHex(_ string: String) -> (Float, Float, Float)? {
    var hex = string
    if hex.hasPrefix("#") { hex.removeFirst() }
    guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
    return (
      Float((value >> 16) & 255) / 255,
      Float((value >> 8) & 255) / 255,
      Float(value & 255) / 255
    )
  }

  private func writeJPEG(_ image: NSImage, to url: URL) throws {
    let target = NSImage(size: size)
    target.lockFocus()
    NSColor.black.setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
    image.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
    target.unlockFocus()
    guard
      let data = target.tiffRepresentation.flatMap({
        NSBitmapImageRep(data: $0)?.representation(
          using: .jpeg,
          properties: [.compressionFactor: 0.86]
        )
      })
    else {
      throw WallpaperError.packageOperationFailed("Could not encode preview")
    }
    try data.write(to: url, options: .atomic)
  }

  private static let previewVertexSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VOut { float4 position [[position]]; float2 uv; };
    vertex VOut lumawall_vertex(uint id [[vertex_id]]) {
      float2 p[3] = { float2(-1,-1), float2(3,-1), float2(-1,3) };
      VOut o;
      o.position = float4(p[id], 0, 1);
      o.uv = p[id] * .5 + .5;
      return o;
    }
    """
}

private final class SnapshotNavigationDelegate: NSObject, WKNavigationDelegate {
  private var continuation: CheckedContinuation<Void, Error>?
  func waitUntilFinished() async throws {
    try await withCheckedThrowingContinuation { continuation = $0 }
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    continuation?.resume()
    continuation = nil
  }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
}
