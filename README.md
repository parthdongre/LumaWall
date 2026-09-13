# LumaWall

LumaWall is a **macOS-only native live-wallpaper app** inspired by Steam Wallpaper Engine. Normal users do not need Terminal, Swift, Xcode, or developer tools.

## Install

Download the latest **LumaWall DMG** from GitHub Releases, open it, and drag **LumaWall.app** into **Applications**.

After installation, everything is controlled from the app:

- wallpaper library
- image / video / HTML / WebGL / Metal wallpapers
- per-display assignments
- favorites and recent wallpapers
- search and filtering
- playlists and schedules
- creator sliders, colors, toggles and dropdowns
- Mac hardware detection and automatic tuning
- native Retina/max-resolution rendering per display
- 30 / 60 / 120 FPS controls
- Automatic / Eco / Balanced / Ultra quality presets
- Maximum Resolution lock plus manual render scale
- adaptive battery / thermal performance
- fullscreen and game auto-pause
- mouse interaction
- audio-reactive wallpapers
- system-audio permission controls
- import / export of `.wall` packages
- launch at login
- software updates
- Safe Mode
- diagnostics and crash-report tools
- menu-bar controls

The first launch includes an in-app welcome guide. No command-line setup is required.

## Built-in wallpaper technologies

LumaWall currently includes native procedural wallpapers plus import support for:

- static images
- hardware-decoded video via AVFoundation
- HTML/CSS/JavaScript
- Canvas and WebGL
- native Metal fragment shaders
- mouse-reactive scenes
- system-audio-reactive scenes using FFT data

## Updates

Open:

**LumaWall → Settings → Updates**

LumaWall checks the official GitHub Releases feed. When a newer version is available, it can download the macOS DMG or PKG into Downloads and open the installer.

## Recovery

If a wallpaper causes problems, open:

**LumaWall → Settings → Recovery**

From there you can:

- start the next launch in Safe Mode
- stop all wallpapers
- clear saved display assignments
- open diagnostics
- open macOS crash reports

No Terminal recovery command is required.

## Wallpaper packages

LumaWall registers `.wall` as its wallpaper package type. An installed build can open `.wall` packages directly from Finder and import them into the local library.

A creator package contains a manifest and local assets:

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

See `docs/wallpaper-format.md`, `docs/creator-api.md`, and `docs/security.md`.

## macOS architecture

```text
SwiftUI control app + menu bar
          │
       AppModel
          │
WallpaperEngine ─── PerformanceGovernor
          │                  │
 non-activating        fullscreen / game
 panel per display     battery / thermal
          │
 WallpaperRenderer
 ├─ Image
 ├─ Video / AVFoundation
 ├─ Web / WKWebView / WebGL
 └─ Metal / MTKView
          │
 mouse + creator properties + permission-gated audio FFT
```

LumaWall targets **macOS 14 or later**.

## Developer notes

Development and release automation still use SwiftPM and shell scripts internally, but those are not part of the user experience. CI builds, tests, and produces the installable `.app`, ZIP, DMG, and PKG automatically.

See `docs/distribution.md`, `CHANGELOG.md`, and `steps.md` for implementation details.
