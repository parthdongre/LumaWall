import AppKit
import MetalKit
import QuartzCore

private struct MetalUniforms {
  var time: Float
  var resolutionX: Float
  var resolutionY: Float
  var mouseX: Float
  var mouseY: Float
  var audioLevel: Float
  var audioBass: Float
  var audioMid: Float
  var audioTreble: Float
  var property0:
    SIMD4<Float>
  var property1:
    SIMD4<Float>
  var property2:
    SIMD4<Float>
  var property3:
    SIMD4<Float>
}

@MainActor
final class MetalWallpaperRenderer:
  NSObject,
  WallpaperRenderer,
  MTKViewDelegate
{
  private let metalView:
    MTKView

  private let device:
    MTLDevice

  private var commandQueue:
    MTLCommandQueue

  private var pipeline:
    MTLRenderPipelineState?

  private var lastCommandBuffer:
    MTLCommandBuffer?

  private var startTime =
    CACurrentMediaTime()

  private var mouse =
    CGPoint(
      x: 0.5,
      y: 0.5
    )

  private var audio =
    AudioFrame.zero

  private var propertyDefinitions:
    [WallpaperProperty] = []

  private var propertyValues:
    [String:
      WallpaperPropertyValue] = [:]

  private var targetNativePixelSize =
    CGSize(
      width: 1920,
      height: 1080
    )

  private var renderScale =
    1.0

  private var preferredFPS =
    60

  private var edrEnabled =
    false

  var view: NSView {
    metalView
  }

  var diagnostics:
    RendererDiagnostics
  {
    RendererDiagnostics(
      rendererName:
        edrEnabled
        ? "Metal / EDR"
        : "Metal",
      preferredFPS:
        preferredFPS,
      renderScale:
        renderScale,
      pixelWidth:
        Int(
          targetNativePixelSize
            .width
            * renderScale
        ),
      pixelHeight:
        Int(
          targetNativePixelSize
            .height
            * renderScale
        ),
      playbackRate: nil,
      muted: nil
    )
  }

  override init() {
    guard
      let device =
        MTLCreateSystemDefaultDevice(),
      let queue =
        device
          .makeCommandQueue()
    else {
      fatalError(
        "Metal is not available on this Mac"
      )
    }

    self.device = device
    self.commandQueue =
      queue

    self.metalView =
      MTKView(
        frame: .zero,
        device: device
      )

    super.init()

    metalView.delegate =
      self

    metalView
      .preferredFramesPerSecond =
      60

    metalView
      .enableSetNeedsDisplay =
      false

    metalView.isPaused =
      false

    metalView.framebufferOnly =
      false

    metalView
      .autoResizeDrawable =
      false
  }

  func configure(
    for display:
      DisplayDescriptor
  ) {
    targetNativePixelSize =
      display.nativePixelSize

    preferredFPS =
      min(
        preferredFPS,
        display.maximumFPS
      )

    edrEnabled =
      display.supportsEDR

    if edrEnabled {
      metalView
        .colorPixelFormat =
        .rgba16Float

      (metalView.layer
        as? CAMetalLayer)?
        .wantsExtendedDynamicRangeContent =
        true
    } else {
      metalView
        .colorPixelFormat =
        .bgra8Unorm

      (metalView.layer
        as? CAMetalLayer)?
        .wantsExtendedDynamicRangeContent =
        false
    }

    updateDrawableSize()
  }

  func load(
    _ wallpaper:
      Wallpaper
  ) throws {
    propertyDefinitions =
      wallpaper.properties

    propertyValues =
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

    let fragmentSource =
      try String(
        contentsOf:
          wallpaper.entryURL,
        encoding:
          .utf8
      )

    let library =
      try device
        .makeLibrary(
          source:
            Self.vertexSource
            + "\n"
            + fragmentSource,
          options: nil
        )

    guard
      let vertex =
        library
          .makeFunction(
            name:
              "lumawall_vertex"
          ),
      let fragment =
        library
          .makeFunction(
            name:
              "lumawall_fragment"
          )
    else {
      throw
        WallpaperError
          .invalidMetalShader
    }

    let descriptor =
      MTLRenderPipelineDescriptor()

    descriptor
      .vertexFunction =
      vertex

    descriptor
      .fragmentFunction =
      fragment

    descriptor
      .colorAttachments[0]
      .pixelFormat =
      metalView
        .colorPixelFormat

    pipeline =
      try device
        .makeRenderPipelineState(
          descriptor:
            descriptor
        )

    startTime =
      CACurrentMediaTime()
  }

  func play() {
    metalView.isPaused =
      false
  }

  func pause() {
    metalView.isPaused =
      true
  }

  func stop() {
    metalView.isPaused =
      true

    metalView.delegate =
      nil

    lastCommandBuffer?
      .waitUntilCompleted()

    lastCommandBuffer =
      nil

    pipeline = nil

    metalView.device =
      nil
  }

  func setFPS(
    _ fps: Int
  ) {
    preferredFPS =
      max(
        1,
        fps
      )

    metalView
      .preferredFramesPerSecond =
      preferredFPS
  }

  func setRenderScale(
    _ scale: Double
  ) {
    renderScale =
      max(
        0.25,
        min(
          1,
          scale
        )
      )

    updateDrawableSize()
  }

  func updateInteraction(
    _ state:
      InteractionState
  ) {
    mouse =
      state
        .normalizedMouse
  }

  func updateAudio(
    _ frame:
      AudioFrame
  ) {
    audio = frame
  }

  func setProperties(
    _ properties:
      [String:
        WallpaperPropertyValue]
  ) {
    propertyValues
      .merge(
        properties
      ) {
        _,
        new in
        new
      }
  }

  func mtkView(
    _ view: MTKView,
    drawableSizeWillChange
      size: CGSize
  ) {}

  private func updateDrawableSize() {
    metalView.drawableSize =
      CGSize(
        width:
          max(
            1,
            targetNativePixelSize
              .width
              * renderScale
          ),
        height:
          max(
            1,
            targetNativePixelSize
              .height
              * renderScale
          )
      )
  }

  func draw(
    in view: MTKView
  ) {
    guard
      let pipeline,
      let descriptor =
        view
          .currentRenderPassDescriptor,
      let drawable =
        view.currentDrawable,
      let buffer =
        commandQueue
          .makeCommandBuffer(),
      let encoder =
        buffer
          .makeRenderCommandEncoder(
            descriptor:
              descriptor
          )
    else {
      return
    }

    let slots =
      makePropertySlots()

    var uniforms =
      MetalUniforms(
        time:
          Float(
            CACurrentMediaTime()
              - startTime
          ),
        resolutionX:
          Float(
            view
              .drawableSize
              .width
          ),
        resolutionY:
          Float(
            view
              .drawableSize
              .height
          ),
        mouseX:
          Float(
            mouse.x
          ),
        mouseY:
          Float(
            mouse.y
          ),
        audioLevel:
          audio.level,
        audioBass:
          audio.bass,
        audioMid:
          audio.mid,
        audioTreble:
          audio.treble,
        property0:
          slots[0],
        property1:
          slots[1],
        property2:
          slots[2],
        property3:
          slots[3]
      )

    encoder
      .setRenderPipelineState(
        pipeline
      )

    encoder
      .setFragmentBytes(
        &uniforms,
        length:
          MemoryLayout<
            MetalUniforms
          >.stride,
        index: 0
      )

    encoder
      .drawPrimitives(
        type: .triangle,
        vertexStart: 0,
        vertexCount: 3
      )

    encoder
      .endEncoding()

    buffer.present(
      drawable
    )

    lastCommandBuffer =
      buffer

    buffer.commit()
  }

  private func makePropertySlots()
    -> [SIMD4<Float>]
  {
    var flat =
      [Float](
        repeating: 0,
        count: 16
      )

    var cursor = 0

    for definition
      in propertyDefinitions
      where cursor
        < flat.count
    {
      let value =
        propertyValues[
          definition.id
        ]
        ?? definition
          .defaultValue

      switch value {
      case .number(
        let number
      ):
        flat[cursor] =
          Float(number)
        cursor += 1

      case .bool(
        let bool
      ):
        flat[cursor] =
          bool ? 1 : 0
        cursor += 1

      case .string(
        let string
      ):
        if definition.kind
          == .color,
          let rgb =
            parseHex(
              string
            ),
          cursor + 2
            < flat.count
        {
          flat[cursor] =
            rgb.0
          flat[cursor + 1] =
            rgb.1
          flat[cursor + 2] =
            rgb.2
          cursor += 3
        } else if
          definition.kind
            == .dropdown
        {
          flat[cursor] =
            Float(
              definition
                .options?
                .firstIndex(
                  of: string
                )
              ?? 0
            )
          cursor += 1
        } else {
          cursor += 1
        }
      }
    }

    return stride(
      from: 0,
      to: 16,
      by: 4
    ).map {
      SIMD4(
        flat[$0],
        flat[$0 + 1],
        flat[$0 + 2],
        flat[$0 + 3]
      )
    }
  }

  private func parseHex(
    _ string: String
  ) -> (
    Float,
    Float,
    Float
  )? {
    var hex =
      string
        .trimmingCharacters(
          in:
            .whitespacesAndNewlines
        )

    if hex.hasPrefix("#") {
      hex.removeFirst()
    }

    guard
      hex.count == 6,
      let value =
        UInt32(
          hex,
          radix: 16
        )
    else {
      return nil
    }

    return (
      Float(
        (value >> 16)
          & 255
      ) / 255,
      Float(
        (value >> 8)
          & 255
      ) / 255,
      Float(
        value
          & 255
      ) / 255
    )
  }

  private static let vertexSource =
    """
    #include <metal_stdlib>
    using namespace metal;

    struct VOut {
      float4 position [[position]];
      float2 uv;
    };

    vertex VOut lumawall_vertex(uint id [[vertex_id]]) {
      float2 p[3]={
        float2(-1,-1),
        float2(3,-1),
        float2(-1,3)
      };

      VOut o;
      o.position=float4(p[id],0,1);
      o.uv=p[id]*.5+.5;
      return o;
    }
    """
}
