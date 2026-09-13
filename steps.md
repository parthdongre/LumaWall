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
