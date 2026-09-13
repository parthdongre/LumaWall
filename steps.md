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


## v0.3 productization: library state and controls

Favorites, recent usage, sort order, quality preferences and creator-property values are persisted with `UserDefaults`/Codable because these are small user preferences rather than owned wallpaper assets. The wallpaper library itself remains a JSON index under Application Support.

The sidebar no longer lists every wallpaper. That approach stops scaling once the built-in collection grows. Instead, the sidebar exposes library scopes (All, Favorites, Recent) and the gallery handles renderer-type filters, search and sorting.

Creator controls persist per wallpaper UUID. Applying a wallpaper records it in a bounded recent-history list so the menu bar can provide quick switching without scanning the entire library.

## v0.3 productization: performance presets

Manual FPS/render-scale preferences are now inputs to `PerformanceGovernor`. Previously the governor's two-second evaluation could overwrite a user's 30/120 FPS choice with its default 60 FPS policy. The governor now treats the selected targets as preferred ceilings, reducing them only when adaptive thermal/battery policy requires it. Eco/Balanced/Ultra are convenience presets over the same inputs.

## v0.3 productization: recovery and diagnostics

Safe Mode is intentionally simple: `--safe-mode` or the one-shot next-launch flag skips assignment restoration. It does not disable the UI or library, so users can still diagnose a broken wallpaper, export a report, revoke permissions, or choose a known-good wallpaper.

Diagnostics are generated from runtime state rather than collecting private user data. The report includes LumaWall version, rendering policy, power/thermal state, display assignments, library counts and the last surfaced error.

## v0.3 productization: installable macOS bundle

SwiftPM remains the source build system, while `scripts/package-macos.sh` assembles the release executable and SwiftPM resource bundle into a conventional `.app` layout. The app is ad-hoc signed when no Developer ID is supplied, then packaged into ZIP, DMG and PKG outputs with checksums.

The app bundle registers the `.wall` document type, and AppKit's application delegate forwards Finder-opened wallpaper packages into the existing importer. GitHub Actions performs packaging on macOS after build/tests so distribution errors are caught separately from source compilation.


## App-bundle resource sealing fix

The first v0.3 packaging run exposed a macOS code-signing rule: arbitrary files or symlinks at the root of an `.app` bundle are considered unsealed contents. The SwiftPM resource-bundle compatibility symlink was therefore removed.

Packaged builds now keep `LumaWall_LumaWall.bundle` exclusively under `Contents/Resources`, and `WallpaperLibrary` resolves that nested bundle explicitly when `Bundle.main` is an installed app. Development runs still use `Bundle.module`. This preserves Command Line Tools development while producing a standards-compliant signed app bundle.


## App-only macOS user experience

LumaWall is now treated explicitly as a macOS application rather than a CLI-assisted project. Shell scripts and SwiftPM commands remain developer/build infrastructure only; they are not part of the normal user journey.

First launch is handled by a native SwiftUI onboarding sheet backed by `AppModel` state rather than `@State`, preserving compatibility with the lightweight Command Line Tools configuration used during development. The onboarding explains supported wallpaper technologies, performance presets, optional audio permissions, and recovery tools.

Settings now exposes all operational controls through macOS UI tabs: General, Performance, Audio, Updates, Recovery and About. The previous user-facing Terminal Safe Mode instruction was removed; users can request Safe Mode for the next launch from the Recovery tab.

## In-app update flow

`UpdateService` checks the repository's GitHub Releases endpoint using `URLSession`. When a newer release exists, it selects the DMG first (PKG as fallback), downloads it to the user's Downloads directory with a collision-safe filename, and opens the installer using `NSWorkspace`.

This is intentionally not a silent self-replacement updater yet. Opening a signed/notarized DMG or PKG keeps installation behavior aligned with standard macOS distribution while still allowing the entire update discovery/download workflow to happen inside LumaWall.


## v0.3.2 hardware-aware native-resolution rendering

LumaWall now separates macOS logical points from the actual backing-pixel framebuffer. `DisplayManager` records each display's current `CGDisplayMode.pixelWidth/pixelHeight`, AppKit logical size, backing scale, built-in status and refresh capability.

The previous Metal render-scale code derived `MTKView.drawableSize` from view bounds. On Retina Macs that can mean rendering near logical-point resolution instead of native display pixels. Metal renderers now receive a `DisplayDescriptor` from the engine and explicitly size the drawable from the display's native pixel dimensions. A 100% scale therefore means the actual display framebuffer, not the SwiftUI point size.

`MacHardwareProfile` identifies the current model through `hw.model`, reads the active Metal device name for the Apple chip/GPU, and uses physical memory, processor count and display refresh capability to choose an Automatic FPS target. Resolution remains 100% by default; on battery or thermal pressure the governor reduces FPS before reducing pixel resolution.

Maximum Resolution is a user-visible lock. While enabled, adaptive performance policies keep `renderScale = 1.0`. Users can turn it off to allow lower render scales. Active renderers are also reconfigured when macOS reports display-parameter changes, so connecting a monitor or changing scaling does not require relaunching LumaWall.


## Per-display fullscreen suppression

Fullscreen activity is now mapped to individual CoreGraphics display IDs instead of a single global boolean. The foreground application's layer-0 windows are compared with each active display's CoreGraphics bounds; a display is considered occupied when the foreground window covers essentially the whole display.

Fullscreen display IDs are passed separately from the global performance policy. WallpaperEngine pauses only the renderers assigned to those displays and suppresses audio/mouse updates for them. The wallpaper panel itself stays resident at a deterministic level below Finder icons; it is not ordered out/in during fullscreen transitions, which avoids flashing the static macOS wallpaper. Other monitors keep rendering normally.

Wallpaper panels no longer use fullScreenAuxiliary, because that collection behavior explicitly permits them to join another application's fullscreen Space. This fixes the case where a browser/YouTube fullscreen window could be visually replaced or covered by the live wallpaper.


## Styled DMG installer

The original DMG was built directly from a source folder containing LumaWall.app and an Applications symlink. That technically included the right files, but it did not create Finder icon-view metadata, so the mounted installer could appear as an empty or unhelpful window depending on Finder state.

The packaging flow now creates an editable DMG first, mounts it, writes a generated branded background plus Finder .DS_Store layout metadata, places LumaWall.app on the left and Applications on the right, then converts the result into the compressed distribution DMG. CI mounts the final compressed DMG again and verifies the visible installer contents and embedded SwiftPM resource bundle before the artifact is accepted.


## v0.3.5 fullscreen stability regression

A user screen recording exposed two problems in the fullscreen heuristic. A normal maximized browser window on a 2940×1912 Retina MacBook left only the menu-bar strip uncovered, which still exceeded the previous 97% area threshold and was incorrectly treated as fullscreen. Separately, the fullscreen poller used the default run-loop mode, so Dock/window tracking could temporarily delay state updates and leave the renderer paused after switching applications.

Fullscreen classification now ignores area percentage entirely. A foreground layer-0 window must reach all four CoreGraphics display edges within a small six-unit tolerance. This still accepts tiny coordinate drift and borderless games while rejecting ordinary maximized windows, menu-bar gaps, Dock gaps, shifted windows and windows spanning multiple monitors.

Entering fullscreen requires two consistent samples, while leaving fullscreen resumes immediately. The monitor polls every 250 ms in the common run-loop and also reacts to application activation and active-Space changes.

Fullscreen pause is now renderer-only. LumaWall keeps the desktop panel resident below Finder's icon level and never uses fullScreenAuxiliary. The renderer stops producing frames, audio-reactive updates and mouse interaction for that display, but the panel is not removed and reinserted, avoiding desktop flicker and ordering races.

The regression suite includes the exact high-coverage maximized-window case from the recording plus multi-display, edge-tolerance, spanning-window, alpha/layer, own-process and debounce-flapping cases.


## v0.4.0 Creator Studio

Creator Studio is intentionally built around the user's own artwork rather than expanding the random built-in wallpaper set. The first workflow targets Canva exports because images and video map cleanly onto LumaWall's native image/AVFoundation renderers.

The creator model keeps source artwork separate from LumaWall-owned storage. Creating a wallpaper copies the original asset into a generated package under Application Support, writes a v1 wallpaper.json manifest, persists the result in the existing Library index, and leaves the Canva export untouched. Image wallpapers reuse the copied artwork as their card thumbnail unless the creator supplies a separate thumbnail; video wallpapers can generate a preview after import.

Package construction runs in a detached user-initiated task because 4K/60 video files can be large. Only the final Library/model mutation returns to the main actor. This keeps Creator Studio from freezing the SwiftUI control surface during large file copies.

Creator metadata adds optional description, tags, category, version and source fields to wallpaper.json. They are optional so existing v1 packages remain backward compatible. Presentation settings such as fit, video playback and Time/Date overlay remain user-configurable engine state and are applied immediately after creation.

## v0.4.0 Overlay Studio

The Time/Date renderer remains a native AppKit overlay above the wallpaper renderer, but its product surface is now a dedicated visual editor. Users select any wallpaper, see the real wallpaper thumbnail/preview, and can drag the clock directly to a free position rather than choosing only one of nine anchors.

Free placement is stored as normalized top-left coordinates instead of pixels. ClockOverlayLayout converts the normalized preview position into AppKit's bottom-left coordinate system at runtime, clamps the overlay to the configured safe insets, and therefore preserves the intended composition across MacBook Retina displays and external monitors with different logical sizes.

The existing nine anchor positions remain available and clear the custom coordinates when selected. New custom coordinate fields are optional in Codable settings so previously persisted overlay preferences decode without migration.

Overlay Studio exposes typography, 12/24-hour/system time, seconds, date style, weekday, text color/opacity, glass strength, background opacity, corner radius, timezone and up to three additional world clocks. The same AppModel.updateTimeDateSettings path updates active desktop overlays immediately.

The native overlay timer now runs in the common run-loop mode so mouse tracking and editor interactions do not freeze clock updates. CI captures both Creator Studio and Overlay Studio as actual macOS SwiftUI/AppKit screenshots.


## v0.4.0 Lock Screen Companion

Lock Screen Companion intentionally stays on public macOS APIs and does not attempt to draw over Apple's secure authentication UI. It generates one still composition per connected display at the display's backing-pixel resolution and hands those assets off through normal Wallpaper / Screen Saver settings.

PreviewGenerator now exposes a reusable still-render path with an arbitrary target size. Image, AVFoundation video, sandboxed WebKit and Metal wallpapers therefore share the same lock-image pipeline. Metal stills preserve creator-property values and render at the requested target dimensions instead of the old 640×360 preview size.

LockScreenCompositionGeometry owns Fill/Fit/Stretch/Center math independently of AppKit drawing so it can be regression-tested. The generated image can apply Gaussian blur, dimming, saturation and vignette after the wallpaper is composed. The wallpaper's native Time & Date overlay can optionally be drawn into the final bitmap using the same positioning settings.

The default source is the currently assigned wallpaper for each display, with a fallback wallpaper when no assignment exists. Auto-refresh is optional and debounced by 1.25 seconds to avoid repeatedly rendering large 4K/5K/6K images while a user changes several controls or reconnects monitors.


## v0.4.0 Discover catalog

Discover is deliberately not populated with third-party or random wallpapers. It starts empty and accepts either a local catalog JSON or an HTTPS catalog endpoint controlled by the user/project. This keeps the product direction aligned with the custom Canva collection rather than turning the app into an uncontrolled scrape of other wallpaper libraries.

Remote catalog and package URLs must use HTTPS. A listing may provide a SHA-256 digest; when present, the downloaded .wall archive is hashed in 1 MB chunks before import and rejected on mismatch. The archive then passes through the existing .wall traversal/path validation before being copied into LumaWall-owned storage.

The service uses URLSession download tasks so large packages are written to a temporary file rather than held in memory, with a 1 GB catalog-install ceiling. The UI exposes search, category filtering, featured/type badges and explicit install progress. Local JSON catalogs can be opened for development without requiring a server.


## v0.4.0 renderer telemetry and adaptive workload research

Metal renderers now keep a bounded rolling frame-time history. Diagnostics exposes measured FPS, average frame time, estimated dropped-frame ratio and a simple Light/Moderate/Heavy/Overloaded classification without introducing a separate profiling process.

An experimental workload controller consumes measured FPS versus the renderer target. It uses hysteresis: several weak samples are required before constraining quality, severe overload escalates faster, and multiple healthy samples are required before recovering. The feature is opt-in; the existing battery/thermal governor remains the default behavior. Maximum Resolution still wins when enabled, so workload adaptation reduces FPS before pixel scale.

## v0.4.0 Smart Rules

Automation now supports state-based wallpaper rules in addition to playlists and clock/sun schedules. Conditions include battery above/below, charging, Low Power Mode, external-display presence, dark/light appearance, weekdays and time ranges that can cross midnight.

Rules are AND-composed, ranked by integer priority and evaluated from a small context supplied by AppModel. Only the highest-priority matching rule is active, and its wallpaper is requested only when that active rule changes. This avoids multiple matching rules fighting on every polling interval.

Schedule, playlist and smart-rule timers use the common main run-loop mode so Dock/menu/window tracking cannot freeze automation state.

## v0.4.0 safe live previews

The gallery now supports delayed hover previews through a single LivePreviewCoordinator. Only one wallpaper ID may own the live-preview slot at a time. A 450 ms hover delay prevents accidental renderer churn while moving the pointer across the grid, and leaving a card cancels pending work immediately.

The preview surface uses the same renderer factory as desktop wallpapers, but caps the renderer at 30 FPS and a 0.35 render scale. NSViewRepresentable dismantling explicitly pauses/stops the renderer and detaches its view. macOS Low Power Mode disables live preview activation, and users can turn the feature off entirely in Settings.

This intentionally avoids the older burst-preview design that could create several WebKit/Metal/Core Animation surfaces during SwiftUI gallery mutation.

## v0.4.0 Wallpaper Engine compatibility importer

The first compatibility importer supports only formats that map cleanly onto existing LumaWall renderers: ordinary video projects, local HTML/web projects and static image entries. Scene/particle projects are rejected with an explicit unsupported-type error rather than being presented as compatible.

project.json entry and preview paths are standardized, symlinks are resolved, and every referenced file must remain under the selected project root. The converted project becomes a normal LumaWall v1 package and is persisted through the same library/package validation path as native imports.


## Unreleased import UX and developer preflight

The Library now accepts Finder file drops directly. SwiftUI's typed URL drop destination is used instead of custom pasteboard parsing so local files arrive as file URLs and continue through the existing AppModel and WallpaperLibrary import path. That keeps drag-and-drop behavior identical to the Import panel for .wall/.zip packages, loose image/video/web/Metal files, permission prompts, persistence, previews and selection.

Import entry points now share a small WallpaperImportMenu view. It exposes normal wallpaper import, the existing Wallpaper Engine project importer, and Creator Studio without duplicating separate buttons across ContentView and the Library toolbar.

A new `scripts/doctor.sh` preflight checks the exact toolchain pieces LumaWall needs: macOS 14+, a full Xcode developer directory, xcodebuild, Swift, the macOS SDK and `metal`. Make targets for run/build/test/package/install depend on this check. This intentionally does not try to hide a Command Line Tools-only setup because SwiftUI/AppKit builds and runtime Metal shader work require the complete Apple developer toolchain; instead it fails before opaque Swift macro or `metal` spawn errors.
