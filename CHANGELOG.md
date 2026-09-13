# Changelog

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
