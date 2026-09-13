import AppKit
import WebKit

private final class WeakScriptMessageHandler:
  NSObject,
  WKScriptMessageHandler
{
  weak var delegate:
    WKScriptMessageHandler?

  func userContentController(
    _ userContentController:
      WKUserContentController,
    didReceive message:
      WKScriptMessage
  ) {
    delegate?
      .userContentController(
        userContentController,
        didReceive: message
      )
  }
}

@MainActor
final class WebWallpaperRenderer:
  NSObject,
  WallpaperRenderer,
  WKScriptMessageHandler,
  WKNavigationDelegate
{
  private let webView:
    WKWebView

  private let messageProxy:
    WeakScriptMessageHandler

  private var loaded = false
  private var allowNetwork = false
  private var paused = false
  private var fps = 60
  private var renderScale = 1.0
  private var fitMode:
    WallpaperFitMode = .fill

  private var interaction =
    InteractionState(
      normalizedMouse:
        CGPoint(
          x: 0.5,
          y: 0.5
        )
    )

  private var audio =
    AudioFrame.zero

  private var properties:
    [String:
      WallpaperPropertyValue] = [:]

  private var displayInfo:
    [String: Any] = [:]

  private var pixelSize =
    CGSize.zero

  var view: NSView {
    webView
  }

  var diagnostics:
    RendererDiagnostics
  {
    RendererDiagnostics(
      rendererName:
        "Web / WebGL",
      preferredFPS:
        fps,
      renderScale:
        renderScale,
      pixelWidth:
        Int(
          pixelSize.width
            * renderScale
        ),
      pixelHeight:
        Int(
          pixelSize.height
            * renderScale
        ),
      playbackRate: nil,
      muted: nil
    )
  }

  override init() {
    let config =
      WebSecurityPolicy
        .baseConfiguration()

    let proxy =
      WeakScriptMessageHandler()

    config
      .userContentController
      .add(
        proxy,
        name: "lumawall"
      )

    messageProxy = proxy

    webView =
      WKWebView(
        frame: .zero,
        configuration:
          config
      )

    webView.setValue(
      false,
      forKey:
        "drawsBackground"
    )

    super.init()

    proxy.delegate = self
    webView.navigationDelegate =
      self
  }

  func configure(
    for display:
      DisplayDescriptor
  ) {
    pixelSize =
      display.nativePixelSize

    webView.layer?
      .contentsScale =
      display.backingScaleFactor

    displayInfo = [
      "pixelWidth":
        Int(
          display
            .nativePixelSize
            .width
        ),
      "pixelHeight":
        Int(
          display
            .nativePixelSize
            .height
        ),
      "logicalWidth":
        Int(
          display
            .logicalPointSize
            .width
        ),
      "logicalHeight":
        Int(
          display
            .logicalPointSize
            .height
        ),
      "scaleFactor":
        display
          .backingScaleFactor,
      "maximumFPS":
        display.maximumFPS,
      "supportsEDR":
        display.supportsEDR,
      "maximumEDR":
        display.maximumEDR,
      "builtIn":
        display.isBuiltIn,
    ]

    send(
      "display",
      payload:
        displayInfo
    )
  }

  func load(
    _ wallpaper:
      Wallpaper
  ) throws {
    loaded = false

    allowNetwork =
      wallpaper
        .grantedPermissions
        .contains(
          .network
        )

    let access =
      wallpaper
        .entryURL
        .deletingLastPathComponent()

    if allowNetwork {
      webView.loadFileURL(
        wallpaper.entryURL,
        allowingReadAccessTo:
          access
      )
    } else {
      WebSecurityPolicy
        .installNetworkBlocker(
          on:
            webView
              .configuration
              .userContentController
        ) {
          [weak self] ok in
          Task {
            @MainActor in
            guard let self
            else {
              return
            }

            if ok {
              self.webView
                .loadFileURL(
                  wallpaper.entryURL,
                  allowingReadAccessTo:
                    access
                )
            } else {
              self.webView
                .loadHTMLString(
                  """
                  <style>
                  body{
                    font-family:-apple-system;
                    background:#090b10;
                    color:#fff;
                    padding:40px
                  }
                  </style>
                  <h3>LumaWall blocked this wallpaper</h3>
                  <p>The local network sandbox could not be initialized.</p>
                  """,
                  baseURL: nil
                )
            }
          }
        }
    }
  }

  func play() {
    paused = false
    send(
      "resume",
      payload:
        NSNull()
    )
  }

  func pause() {
    paused = true
    send(
      "pause",
      payload:
        NSNull()
    )
  }

  func stop() {
    loaded = false
    paused = true

    webView.stopLoading()

    webView.navigationDelegate =
      nil

    webView
      .configuration
      .userContentController
      .removeScriptMessageHandler(
        forName:
          "lumawall"
      )

    messageProxy.delegate =
      nil
  }

  func setFPS(
    _ fps: Int
  ) {
    self.fps =
      max(
        1,
        fps
      )

    send(
      "fps",
      payload:
        self.fps
    )
  }

  func setRenderScale(
    _ scale: Double
  ) {
    renderScale =
      min(
        max(
          scale,
          0.25
        ),
        1
      )

    send(
      "scale",
      payload:
        renderScale
    )
  }

  func setFitMode(
    _ mode:
      WallpaperFitMode
  ) {
    fitMode = mode

    send(
      "fit",
      payload:
        mode.rawValue
    )
  }

  func updateInteraction(
    _ state:
      InteractionState
  ) {
    interaction = state

    send(
      "mouse",
      payload: [
        "x":
          state
            .normalizedMouse
            .x,
        "y":
          state
            .normalizedMouse
            .y,
        "primaryDown":
          state
            .primaryDown,
        "secondaryDown":
          state
            .secondaryDown,
        "velocityX":
          state
            .mouseVelocity
            .dx,
        "velocityY":
          state
            .mouseVelocity
            .dy,
        "scrollX":
          state
            .scrollDelta
            .dx,
        "scrollY":
          state
            .scrollDelta
            .dy,
        "timestamp":
          state.timestamp,
      ]
    )

    let date = Date()

    let calendar =
      Calendar.current

    send(
      "environment",
      payload: [
        "hour":
          calendar
            .component(
              .hour,
              from: date
            ),
        "minute":
          calendar
            .component(
              .minute,
              from: date
            ),
        "weekday":
          calendar
            .component(
              .weekday,
              from: date
            ),
        "timeInterval":
          date
            .timeIntervalSince1970,
      ]
    )
  }

  func updateAudio(
    _ frame:
      AudioFrame
  ) {
    audio = frame

    send(
      "audio",
      payload:
        frame.jsonObject
    )
  }

  func setProperties(
    _ properties:
      [String:
        WallpaperPropertyValue]
  ) {
    self.properties =
      properties

    send(
      "properties",
      payload:
        properties
          .mapValues(
            \.jsonObject
          )
    )
  }

  func webView(
    _ webView: WKWebView,
    didFinish navigation:
      WKNavigation!
  ) {
    loaded = true
    flushState()
  }

  func userContentController(
    _ userContentController:
      WKUserContentController,
    didReceive message:
      WKScriptMessage
  ) {}

  func webView(
    _ webView: WKWebView,
    decidePolicyFor
      navigationAction:
        WKNavigationAction,
    decisionHandler:
      @escaping
      @MainActor
      @Sendable
      (
        WKNavigationActionPolicy
      ) -> Void
  ) {
    guard
      let url =
        navigationAction
          .request
          .url
    else {
      decisionHandler(
        .cancel
      )
      return
    }

    if url.isFileURL
      || url.scheme
        == "about"
    {
      decisionHandler(
        .allow
      )
      return
    }

    decisionHandler(
      .cancel
    )
  }

  private func flushState() {
    send(
      "display",
      payload:
        displayInfo
    )

    send(
      "fps",
      payload:
        fps
    )

    send(
      "scale",
      payload:
        renderScale
    )

    send(
      "fit",
      payload:
        fitMode.rawValue
    )

    updateInteraction(
      interaction
    )

    send(
      "audio",
      payload:
        audio.jsonObject
    )

    send(
      "properties",
      payload:
        properties
          .mapValues(
            \.jsonObject
          )
    )

    send(
      paused
        ? "pause"
        : "resume",
      payload:
        NSNull()
    )
  }

  private func send(
    _ type: String,
    payload: Any
  ) {
    guard loaded else {
      return
    }

    let object:
      [String: Any] = [
        "type": type,
        "payload": payload,
      ]

    guard
      let data =
        try?
        JSONSerialization
          .data(
            withJSONObject:
              object
          ),
      let json =
        String(
          data: data,
          encoding:
            .utf8
        )
    else {
      return
    }

    webView
      .evaluateJavaScript(
        "window.LumaWall?._receive(\(json).type, \(json).payload)"
      )
  }
}

extension WallpaperPropertyValue {
  fileprivate var jsonObject:
    Any
  {
    switch self {
    case .number(
      let value
    ):
      return value

    case .bool(
      let value
    ):
      return value

    case .string(
      let value
    ):
      return value
    }
  }
}
