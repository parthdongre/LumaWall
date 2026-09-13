# LumaWall Architecture

LumaWall separates **wallpaper orchestration** from **rendering**.

- `WallpaperEngine` owns one `WallpaperWindowController` per active display.
- Every wallpaper backend implements `WallpaperRenderer`.
- The renderer receives playback, FPS, render-scale, and interaction events through the same interface.
- `PerformanceGovernor` changes rendering policy based on low-power and thermal state.
- `WallpaperLibrary` imports loose assets or `.wall` package directories.

## Renderer backends

1. Image → `NSImageView`
2. Video → `AVQueuePlayer` + `AVPlayerLooper` + `AVPlayerLayer`
3. Web → `WKWebView`
4. Metal → `MTKView` with runtime-compiled Metal fragment shaders

## Interaction contract

Mouse coordinates are sampled globally and normalized per display. This works even when the wallpaper window ignores mouse events so Finder remains usable. Web wallpapers receive calls through `window.LumaWall`, while Metal shaders receive the mouse coordinates as uniforms.

## Next architectural modules

- ScreenCaptureKit system-audio analyzer
- Fullscreen/game detector
- Playlist and scheduler service
- Persistent SwiftData library
- Wallpaper property bridge
- `.wall` zip importer/exporter
- Workshop metadata/index API
- Signing, sandboxing, and untrusted-content policy
