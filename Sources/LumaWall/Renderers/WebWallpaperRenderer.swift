import AppKit
import WebKit

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  weak var delegate: WKScriptMessageHandler?
  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    delegate?.userContentController(userContentController, didReceive: message)
  }
}

@MainActor
final class WebWallpaperRenderer: NSObject, WallpaperRenderer, WKScriptMessageHandler,
  WKNavigationDelegate
{
  private let webView: WKWebView
  private let messageProxy: WeakScriptMessageHandler
  private var loaded = false
  private var allowNetwork = false
  private var paused = false
  private var fps = 60
  private var renderScale = 1.0
  private var interaction = InteractionState(normalizedMouse: CGPoint(x: 0.5, y: 0.5))
  private var audio = AudioFrame.zero
  private var properties: [String: WallpaperPropertyValue] = [:]

  var view: NSView { webView }

  override init() {
    let config = WebSecurityPolicy.baseConfiguration()
    let proxy = WeakScriptMessageHandler()
    config.userContentController.add(proxy, name: "lumawall")
    messageProxy = proxy
    webView = WKWebView(frame: .zero, configuration: config)
    webView.setValue(false, forKey: "drawsBackground")
    super.init()
    proxy.delegate = self
    webView.navigationDelegate = self
  }

  func load(_ wallpaper: Wallpaper) throws {
    loaded = false
    allowNetwork = wallpaper.grantedPermissions.contains(.network)
    let access = wallpaper.entryURL.deletingLastPathComponent()
    if allowNetwork {
      webView.loadFileURL(wallpaper.entryURL, allowingReadAccessTo: access)
    } else {
      WebSecurityPolicy.installNetworkBlocker(on: webView.configuration.userContentController) {
        [weak self] ok in
        Task { @MainActor in
          guard let self else { return }
          if ok {
            self.webView.loadFileURL(wallpaper.entryURL, allowingReadAccessTo: access)
          } else {
            self.webView.loadHTMLString(
              "<h3>LumaWall blocked this wallpaper because its network sandbox could not be initialized.</h3>",
              baseURL: nil
            )
          }
        }
      }
    }
  }

  func play() {
    paused = false
    send("resume", payload: NSNull())
  }
  func pause() {
    paused = true
    send("pause", payload: NSNull())
  }
  func stop() {
    loaded = false
    webView.stopLoading()
    webView.loadHTMLString("", baseURL: nil)
  }
  func setFPS(_ fps: Int) {
    self.fps = fps
    send("fps", payload: fps)
  }
  func setRenderScale(_ scale: Double) {
    renderScale = scale
    send("scale", payload: scale)
  }
  func updateInteraction(_ state: InteractionState) {
    interaction = state
    send(
      "mouse",
      payload: [
        "x": state.normalizedMouse.x,
        "y": state.normalizedMouse.y,
        "primaryDown": state.primaryDown,
        "secondaryDown": state.secondaryDown,
      ]
    )
  }
  func updateAudio(_ frame: AudioFrame) {
    audio = frame
    send("audio", payload: frame.jsonObject)
  }
  func setProperties(_ properties: [String: WallpaperPropertyValue]) {
    self.properties = properties
    send("properties", payload: properties.mapValues(\.jsonObject))
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    loaded = true
    flushState()
  }

  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    // Deliberately no privileged creator actions in v0.2. The channel exists for future
    // allow-listed commands such as logging and creator diagnostics.
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    guard let url = navigationAction.request.url else {
      decisionHandler(.cancel)
      return
    }
    if url.isFileURL || url.scheme == "about" {
      decisionHandler(.allow)
      return
    }
    // Remote subresources may be allowed by the package permission, but top-level
    // navigation away from the local wallpaper is never allowed.
    decisionHandler(.cancel)
  }

  private func flushState() {
    send("fps", payload: fps)
    send("scale", payload: renderScale)
    send(
      "mouse", payload: ["x": interaction.normalizedMouse.x, "y": interaction.normalizedMouse.y])
    send("audio", payload: audio.jsonObject)
    send("properties", payload: properties.mapValues(\.jsonObject))
    send(paused ? "pause" : "resume", payload: NSNull())
  }

  private func send(_ type: String, payload: Any) {
    guard loaded else { return }
    let object: [String: Any] = ["type": type, "payload": payload]
    guard let data = try? JSONSerialization.data(withJSONObject: object),
      let json = String(data: data, encoding: .utf8)
    else { return }
    webView.evaluateJavaScript("window.LumaWall?._receive(\(json).type, \(json).payload)")
  }
}

extension WallpaperPropertyValue {
  fileprivate var jsonObject: Any {
    switch self {
    case .number(let value): return value
    case .bool(let value): return value
    case .string(let value): return value
    }
  }
}
