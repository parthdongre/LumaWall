# LumaWall

LumaWall is a native macOS live-wallpaper engine inspired by Steam Wallpaper Engine. The project is designed around an extensible renderer boundary so image, video, HTML/JS/WebGL and native Metal wallpapers can share the same display, performance, interaction, audio and creator-property systems.

## v0.3 feature set

Implemented in the current source tree:

- static image wallpapers
- hardware-decoded looping video wallpapers via AVFoundation
- HTML/CSS/JavaScript and WebGL wallpapers via WKWebView
- runtime-compiled Metal fragment-shader wallpapers
- permission-gated mouse interaction
- ScreenCaptureKit system-audio capture
- FFT analysis with level, bass, mids, treble and a 32-bin spectrum
- per-display wallpaper assignments and assignment restoration
- playlists
- daily, one-date, sunrise and sunset schedule primitives
- Low Power Mode + thermal-aware quality governor
- fullscreen auto-pause heuristic and game-category auto-pause
- 30 / 60 / 120 FPS controls
- render-scale controls
- creator slider, toggle, color and dropdown properties
- portable `.wall` ZIP packages with import/export
- image/video/web preview generation
- menu-bar controls
- Codable JSON-backed wallpaper library (works with Command Line Tools-only Swift installs)
- launch-at-login helper via ServiceManagement
- local web-wallpaper sandbox with explicit network permission

Additional v0.3 product features include searchable/filterable library views, favorites, recents, persistent creator controls, quality presets, Safe Mode, diagnostics, keyboard/menu-bar workflows, and installable macOS package generation.

The community gallery / Workshop remains a later milestone. The local package/security model is intentionally being stabilized before public third-party uploads are accepted.

## Install

Requirements: macOS 14+.

For a normal user build, use the DMG or PKG produced by GitHub Actions. For a local install from source:

```bash
git clone https://github.com/parthdongre/LumaWall.git
cd LumaWall
make install
```

For development, full Xcode is optional; Apple Command Line Tools are sufficient for `swift run LumaWall`.

## Quick start

1. Launch the installed app, or run `swift run LumaWall` from the repository.
3. Pick from the built-in wallpaper collection (Aurora plus Metal, WebGL, Canvas and audio-reactive designs) and choose **Set Wallpaper**.
4. Enable system audio in Settings if you want audio-reactive data.
5. The built-in collection already exercises Metal, WebGL/Canvas, mouse interaction and FFT data; `Examples/WebSpectrum.wall` remains available as an importable creator example.

ScreenCaptureKit requires the user's screen-recording/capture permission. Launch-at-login is intended for the signed app-bundle distribution build rather than an arbitrary command-line location. Apple recommends requesting screen-capture permission before capturing content.

## Creator package

A wallpaper package is a ZIP archive with the `.wall` extension, or an unpacked development directory:

```text
MyWallpaper.wall/
├── wallpaper.json
├── thumbnail.jpg        # optional
├── preview.mp4          # optional
└── assets/
    ├── index.html
    ├── wallpaper.mp4
    └── shader.metal
```

See `docs/wallpaper-format.md`, `docs/creator-api.md`, `docs/security.md`, and `steps.md`.

## Distribution

Run `make package` to build `LumaWall.app`, ZIP, DMG, PKG, and SHA-256 checksums. See `docs/distribution.md` for signing and notarization details.

## Validation

`.github/workflows/macos-build.yml` runs `swift build`, `swift test`, and the installable packaging pipeline on a macOS runner because Linux cannot link the Apple-only frameworks used by the engine.

## Architecture

```text
SwiftUI / Menu Bar
       │
    AppModel
       │
WallpaperEngine ── PerformanceGovernor
       │                 │
  one window        fullscreen / game
  per display       battery / thermal
       │
WallpaperRenderer
 ├─ Image
 ├─ Video / AVFoundation
 ├─ Web / WKWebView / WebGL
 └─ Metal / MTKView
       │
 mouse + creator properties + permission-gated audio FFT
```
