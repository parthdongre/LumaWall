# Changelog

## Unreleased

- Added a macOS 26 compatibility CI lane that runs the doctor, debug build, full tests, and release build on the Tahoe-generation runner.
- Added a real SwiftUI macro compiler probe to `make doctor`; CLT-only setups now fail with the actionable `SwiftUIMacros.StateMacro` reason instead of conflating it with Metal.
- Added `make repair` to clear stale SwiftPM build state after toolchain/resource changes and `make verify` for debug build + tests + release build.
- Standalone `metal` is now treated as optional for the current copied shader resources, with Xcode 26 MetalToolchain installation guidance when build-time Metal compilation is actually needed.
- Hardened crash quarantine attribution so stopped or non-restored wallpapers are not blamed for later unrelated crashes.
- Added visible stability history, strike counts, quarantine reset, and recovery diagnostics plus isolated crash-quarantine regression tests.
- Added reason-aware rendering suspension for system sleep, display sleep, and inactive user sessions so overlapping wake events cannot resume wallpapers early.
- Serialized system-audio capture start/stop transitions to prevent duplicate or stale ScreenCaptureKit streams during rapid sleep/wake/session changes.
- Added suspension diagnostics and regression tests for overlap, duplicate notifications, and reset behavior.
- Added a generated Retina macOS app icon embedded into packaged builds and verified in CI/DMG validation.
- Onboarding and About now use the real application icon instead of a generic system symbol.
- Switched the control surface to a single native macOS window while keeping the wallpaper engine alive when that window closes.
- Stopped ordinary app activation from forcibly raising the main window, improving menu-bar-only use.
- Added menu-bar access to Settings and verified update downloads, with an update-available status icon.
- Added a repository-level VERSION source used by packaging and CI, plus a regression test that keeps the Swift fallback version in sync.
- Tagged releases now reject a version that does not match the repository VERSION file.
- Added packaged-app installation detection so copies launched from a DMG or Downloads guide users into Applications.
- Added installation status to Settings and first-run onboarding without affecting SwiftPM development runs.
- Added Developer ID Application and Developer ID Installer support to the packaging pipeline.
- Added notarization and stapling automation for public DMG/PKG releases.
- Public tag releases now fail closed when signing or notarization credentials are missing.
- Added release verification for signatures, checksums, notarization tickets, and Gatekeeper assessment.
- Checksums are regenerated after stapling so in-app update verification matches the exact published installers.
- Hardened in-app updates with SHA-256 verification against the release checksum manifest before opening a DMG or PKG.
- Added automatic update checks at most once per day, enabled by default and user-toggleable in Settings.
- Added update integrity regression tests for version comparison, checksum parsing, and chunked file hashing.
- Added native drag-and-drop importing across the Library with a clear drop-target treatment.
- Added a unified Add menu for normal wallpaper imports, Wallpaper Engine project imports, and Creator Studio.
- Added batch import handling so Finder drops and multi-select imports use the same library path.
- Added `make doctor` to validate macOS, full Xcode selection, Swift, the macOS SDK, SwiftPM, and SwiftUI macro availability before build/run/package commands.
- Improved the local Metal/toolchain troubleshooting path so Command Line Tools misconfiguration fails early with an actionable fix.


## 0.4.0 - Creator Studio

- Added safe live previews to Library cards with a hover delay, one renderer at a time, 30 FPS cap and reduced render scale.
- Live previews are disabled while macOS Low Power Mode is active and can be disabled completely from Settings.
- Added simple Wallpaper Engine compatibility import for video, web and static-image projects that expose a local project.json.
- Wallpaper Engine Scene projects and WebM video are explicitly rejected instead of being partially or incorrectly imported.
- Compatibility import resolves symlinks and blocks project entry/preview paths that escape the selected project folder.

- Added real Metal renderer telemetry: measured FPS, average frame time, estimated drop ratio and load class.
- Added an opt-in workload-aware adaptive renderer controller with hysteresis so transient frame dips do not immediately reduce quality.
- Added Smart Rules for battery thresholds, charging state, Low Power Mode, external displays, dark/light mode, weekdays and overnight time ranges.
- Smart Rules choose one highest-priority match and fire only when the active match changes, preventing competing rules from repeatedly switching wallpapers.
- Automation and playlist timers now run in the common run-loop so window/menu tracking does not freeze scheduling.

- Added Discover as a curated catalog that is intentionally empty until the user supplies a catalog they control.
- Remote catalogs and wallpaper downloads require HTTPS.
- Discover supports optional per-package SHA-256 verification before handing the package to LumaWall's existing traversal-safe .wall importer.
- Added category/search filtering, featured/type badges, local catalog JSON loading, install progress and catalog refresh state.
- Discover downloads are capped at 1 GB and streamed through a temporary file rather than loaded into memory.

- Added Lock Screen Companion with per-display native-resolution snapshot generation.
- Lock compositions support Fill/Fit/Stretch/Center, blur, dimming, saturation and vignette.
- Lock Screen Companion can reuse each wallpaper's native Time & Date overlay and active per-display assignments.
- Optional auto-refresh is debounced after wallpaper/display changes.
- Added Wallpaper and Screen Saver System Settings handoff plus generated-file reveal.
- Extended PreviewGenerator so image/video/WebGL/Metal wallpapers can render stills at arbitrary native pixel sizes instead of only 640×360 library previews.
- Added Lock Screen geometry/settings regression tests and a macOS UI screenshot.

- Added an in-app Creator Studio for turning Canva image/video exports into LumaWall wallpapers without JSON editing or Terminal.
- Supports PNG, JPEG, HEIC, TIFF, WebP, MP4, MOV and M4V source artwork.
- Creator metadata includes title, author/studio, description, category and tags.
- Optional custom thumbnail support; image wallpapers reuse the source artwork without duplicating it.
- Creator output can be added directly to the local Library or exported as a portable .wall package.
- Per-wallpaper presentation choices include fit mode, video loop/mute/playback speed and optional Time & Date presets.
- Large Creator asset copies run away from the main actor to keep the control UI responsive.
- Added Creator package regression tests for metadata, image/video packaging, thumbnails, unsupported formats and Time/Date presets.
- Added a dedicated Overlay Studio with live wallpaper preview and free drag positioning for Time & Date.
- Free overlay placement is stored as normalized coordinates so it survives different Retina resolutions and external displays.
- Added typography, opacity, glass, corner-radius, timezone and up-to-three world-clock controls to the visual editor.
- Overlay clock timers now run in the common run-loop mode so UI tracking does not freeze clock updates.
- Added regression tests for normalized placement, coordinate conversion, safe clamping, fixed anchors and backward-compatible overlay settings.
- macOS UI capture now renders Creator Studio and Overlay Studio in addition to the existing app surfaces.

## 0.3.5 - Fullscreen stability regression fix

- Fixed normal maximized browser/app windows being misclassified as fullscreen.
- Removed the old 97% display-coverage heuristic; fullscreen now requires the foreground window to reach all four display edges within a small CoreGraphics tolerance.
- Added two-sample debounce before entering fullscreen pause and immediate resume when fullscreen ends.
- Fullscreen polling now runs in the common run-loop mode and re-evaluates immediately on app activation and Space changes.
- Pausing a display no longer orders its wallpaper window out/in, eliminating visible flashes back to the static macOS wallpaper.
- Wallpaper surfaces now use a deterministic level immediately below Finder desktop icons and are never marked as fullscreen auxiliary windows.
- Added regression coverage for maximized windows, menu-bar/Dock gaps, multi-display fullscreen, border drift, spanning windows, invisible/nonzero-layer windows, own-process windows, and pause-state flapping.

## 0.3.4 - Styled DMG installer

- Replaced the plain source-folder DMG with a styled Finder installer window.
- LumaWall.app is positioned on the left and the Applications shortcut on the right.
- Added a branded installer background with a clear drag-to-Applications instruction.
- Added persistent Finder icon-view metadata inside the DMG.
- CI now mounts the finished DMG and verifies LumaWall.app, the Applications alias, the background asset, Finder layout metadata, and packaged resources before uploading the installer.

## 0.3.2 - Native-resolution hardware-aware rendering

### Hardware detection
- Detects the current Mac model identifier, Apple GPU/chip name, installed memory and CPU core count.
- Detects whether the machine has a built-in display and presents it as a MacBook-class portable when appropriate.
- Chooses an Automatic FPS target from the Mac and connected display capabilities.
- Re-runs display capability detection when macOS display parameters change.

### Maximum resolution
- Display descriptors now track native backing-pixel dimensions, logical point dimensions, Retina backing scale and refresh capability.
- Metal wallpaper drawables target the display's native framebuffer pixels instead of SwiftUI/AppKit logical points.
- Maximum Resolution is enabled by default and keeps native pixel density even when adaptive battery/thermal mode lowers FPS.
- Users can disable Maximum Resolution and choose a manual render scale when battery/GPU savings matter more than sharpness.
- External display or scaling changes update active renderers without restarting LumaWall.

### UI
- Displays screen shows detected Mac hardware plus each monitor's native resolution, scale factor and refresh capability.
- Performance Settings includes Optimize for This Mac and Maximum Resolution controls.
- Onboarding defaults to hardware-aware Automatic quality.
- Diagnostics include model, chip/GPU, memory and native render targets.

## 0.3.1 - App-only macOS UX

### Native user flow
- First-run macOS onboarding inside LumaWall.
- No Terminal instructions in the user-facing app flow.
- Welcome guide can be reopened from Settings.
- Safe Mode and recovery are fully accessible from Settings.
- Native Updates tab checks GitHub Releases and downloads/opens the DMG or PKG.
- Settings reorganized into General, Performance, Audio, Updates, Recovery and About.
- Product messaging explicitly treats LumaWall as a macOS-only app.

## 0.3.0 - Productization milestone

### Library
- Search wallpapers by name, creator, or renderer type.
- Favorites with persistent storage.
- Recent-wallpaper history and menu-bar quick switching.
- Real library scopes for Metal, Web/WebGL, video, image, and audio-reactive wallpapers.
- Sorting by name, creator, type, or recent usage.
- Active/audio/type badges on library cards.

### Wallpaper controls
- Creator-property values persist across launches.
- Reset one wallpaper or all creator controls.
- Favorite wallpapers from the detail view.
- Manual preview generation.
- Active-display indicators.
- Stop a wallpaper on one target display or everywhere.

### Performance
- Eco, Balanced, Ultra, and Custom quality presets.
- Persistent FPS and render-scale preferences.
- Adaptive thermal/battery quality can be enabled or disabled.
- User quality now acts as the governor's preferred ceiling instead of being overwritten every polling cycle.
- Fullscreen and game auto-pause preferences persist.

### Recovery and diagnostics
- Optional wallpaper restore at launch.
- One-shot Safe Mode for the next launch.
- `--safe-mode` command-line launch option.
- Stop-all-and-clear-assignment recovery action.
- Runtime diagnostics view with display assignments, power/performance state, app state, and last error.
- Copy/export diagnostic reports and open macOS crash reports.

### macOS integration
- Normal Cmd-Tab/Dock foreground behavior.
- Menu-bar quick controls.
- Application keyboard shortcuts.
- `.wall` file association and Finder-open import support.
- Launch-at-login support for installed bundles.

### Distribution
- Release app bundle packaging.
- Drag-to-Applications DMG.
- PKG installer.
- ZIP distribution artifact.
- SHA-256 checksums.
- Ad-hoc signing by default, optional Developer ID signing.
- GitHub Actions package artifacts on main.
- Tag-driven GitHub Release workflow.
