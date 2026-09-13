# LumaWall implementation decisions — through milestone 15

## Foundation

LumaWall uses Swift/AppKit for desktop-window behavior and SwiftUI for controls. Each monitor owns a `WallpaperWindowController`; each wallpaper technology implements `WallpaperRenderer`. This avoids coupling display management to video, WebKit or Metal.

## 1. Per-monitor assignments

`WallpaperEngine` keeps one controller per `CGDirectDisplayID`. Applying a wallpaper only replaces the requested displays rather than stopping every renderer. Assignments are persisted in `UserDefaults` and restored at launch.

## 2. Local wallpaper library

Imported assets are copied under `~/Library/Application Support/LumaWall/Wallpapers/<UUID>/`. `StoredWallpaper` persists metadata in a Codable JSON index. We do not keep fragile references to arbitrary source files that can be moved or deleted.

## 3. Fullscreen/game auto-pause

`FullscreenMonitor` inspects the frontmost application's layer-0 windows and compares them with display bounds. This is a public-API heuristic because macOS does not expose a universal "this other app is presenting fullscreen video/gameplay" flag. App category metadata is also used when available to identify games.

## 4. ScreenCaptureKit system audio

`AudioReactiveController` captures system audio with `SCStream`, excludes the current process, and publishes analysis frames. Capture is opt-in from Settings and still depends on macOS user permission.

## 5. FFT audio features

`FFTAnalyzer` performs a 2048-point radix-2 FFT and produces RMS level, bass, mids, treble and a 32-bin spectrum. The FFT implementation is kept independent of renderers so creator APIs can evolve without capture-code changes.

## 6. JavaScript bridge

Every web wallpaper receives `window.LumaWall`. Native state is dispatched as `lumawall:<event>` DOM events and can also be observed through `LumaWall.on(type, callback)`. Current event types include mouse, audio, properties, pause/resume, FPS and render scale.

## 7. Metal uniform/property bridge

Metal wallpapers receive a stable `LumaWallUniforms` buffer containing time, resolution, normalized mouse position, audio level/bands and creator-property slots. Properties are flattened predictably by manifest order. We chose a fixed uniform ABI for v0.2 rather than recompiling shader interfaces dynamically.

## 8. Creator controls

The manifest supports `slider`, `toggle`, `color` and `dropdown`. SwiftUI builds controls from the schema, updates the renderer immediately, and uses the same property values for web and Metal backends.

## 9. Playlist runner

`WallpaperAutomationController` runs sequential or shuffled playlists. The active index is persisted, while playlist definitions are encoded to `UserDefaults` for this milestone.

## 10. Time/date/sunrise switching

Schedules support daily clock time, one-off dates, sunrise and sunset with offsets. Solar times are calculated locally from user-supplied latitude/longitude so basic scheduling does not require location permission or a network service.

## 11. `.wall` ZIP import/export

`.wall` is a ZIP archive containing `wallpaper.json` and local assets. Import checks archive paths for absolute/`..` traversal before extraction, validates manifest entry paths, and copies the result into LumaWall-owned storage. Export reconstructs a portable package.

## 12. Preview generation

Images are resized, video uses `AVAssetImageGenerator`, web wallpapers use a sandboxed `WKWebView` snapshot, and Metal shaders are rendered offscreen into an `MTLTexture` and converted through Core Image.

## 13. macOS-native library UI

The app now has library cards, wallpaper details, display assignment controls, creator controls, automation views, settings, and menu-bar quick controls. The UI stays SwiftUI while desktop rendering remains AppKit.

## 14. Untrusted web security

Web wallpapers use a non-persistent WebKit data store. Remote HTTP/HTTPS subresources are blocked unless the package requests network access and the user grants it. Top-level navigation away from the local wallpaper remains blocked. Mouse and system-audio streams are also permission-gated per active wallpaper.

## 15. Launch at login

`LaunchAtLoginController` uses `SMAppService.mainApp`. This is intentionally the modern ServiceManagement route rather than legacy login-item APIs. It becomes fully meaningful in the signed app-bundle distribution build.

## Why these libraries

- **AVFoundation** over browser video: better native decode/looping and lower overhead.
- **WKWebView** over bundling Chromium: WebGL/JS support with much smaller distribution and native sandbox primitives.
- **MetalKit** over OpenGL: current native GPU API and better Apple Silicon fit.
- **Codable JSON index** over SwiftData: it avoids compiler-plugin requirements on Command Line Tools-only Macs while keeping the local library portable and easy to inspect.
- **ScreenCaptureKit** over virtual audio devices: Apple-supported system capture without asking users to install a kernel/driver-style component.
- **ServiceManagement** over legacy login items: current public launch-at-login API.

## Known validation boundary

The source has been Swift parser-validated in the development environment. Apple-framework type checking and runtime behavior must run on macOS. The included GitHub Actions workflow is configured to build/test on `macos-15` after the repository is published.


## macOS CI / Swift 6 compatibility

The macOS CI build is treated as the source of truth for Apple-framework type checking. Swift 6 marks AppKit/WebKit UI APIs as main-actor isolated, while `Timer` callbacks are sendable/nonisolated closures. Timer callbacks therefore enter `Task { @MainActor in ... }` before touching UI-owned state, and `WebSecurityPolicy` is main-actor isolated because it constructs and mutates WebKit objects. We keep these explicit actor boundaries rather than disabling strict concurrency checking.


## Command Line Tools compatibility

SwiftPM treats processed `.metal` resources as build-time Metal sources and invokes the standalone `metal` compiler. Many Macs with only Apple Command Line Tools do not include that compiler. LumaWall's Metal renderer already compiles creator shader source at runtime with `MTLDevice.makeLibrary(source:options:)`, so the bundled `Resources` directory is copied verbatim instead of processed. This preserves shader examples while allowing `swift run LumaWall` without requiring the full Xcode app solely for resource compilation.


## Command Line Tools macro compatibility

A Command Line Tools-only Swift toolchain may provide the macOS SDK frameworks without shipping the separate `SwiftDataMacros` and `SwiftUIMacros` compiler plugins. LumaWall therefore does not require SwiftData macros for its local wallpaper index and does not use `@State` for sidebar selection. Imported wallpaper metadata is stored as Codable JSON under Application Support, and navigation selection lives in `AppModel` as ordinary Combine-published state. This keeps the app runnable with a lightweight CLT installation while preserving the same library behavior.


## Bundled resource lookup after CLT compatibility change

After changing SwiftPM resources from `.process("Resources")` to `.copy("Resources")`, the bundle keeps the top-level `Resources` directory. Built-in wallpaper lookup now checks both processed-resource and copied-resource layouts, and CI includes a regression test that verifies the bundled Aurora wallpaper is discoverable.


## Built-in wallpaper collection

Built-ins are now ordinary `.wall` package directories under `Resources/BuiltInWallpapers`, discovered at runtime from their manifests rather than hardcoded one-by-one in Swift. The first collection adds ten native Metal designs and six HTML/Canvas/WebGL designs alongside Aurora. This makes future additions data-driven: a new bundled wallpaper normally requires only a package directory, manifest, and assets.

Library cards generate missing previews lazily as they become visible. This avoids blocking launch to render every preview while still turning the collection into a visual gallery during normal browsing.


## Foreground activation and renderer lifecycle hardening

Wallpaper surfaces now use non-activating `NSPanel` windows instead of ordinary `NSWindow` instances. They remain at the desktop layer and across Spaces, but are excluded from normal window switching so Cmd-Tab/Dock activation can focus the actual LumaWall control window. The app explicitly uses regular activation policy and re-fronts its titled control window when activated or reopened.

Automatic gallery preview generation was removed from every visible card because creating multiple offscreen WebKit/Metal renderers while SwiftUI mutates the gallery can overlap Core Animation transactions. Preview generation remains available as an explicit/single-item path rather than a burst at launch.

Metal teardown now pauses the `MTKView`, detaches its delegate, waits for the latest command buffer to complete, and only then releases the pipeline/device. Web wallpaper teardown stops navigation and detaches delegates/message handlers. Wallpaper panels are ordered out and their content view detached before the panel itself is closed on the next main-run-loop turn. Assignment restoration is delayed briefly after launch, and normal termination stops active renderers first.
