# Changelog

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
