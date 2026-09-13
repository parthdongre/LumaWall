#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.3.5}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
BUNDLE_ID="${BUNDLE_ID:-dev.parthdongre.LumaWall}"
DIST="$ROOT/dist"
APP="$DIST/LumaWall.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$DIST"
mkdir -p "$MACOS" "$RESOURCES"

echo "==> Building LumaWall release"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BIN_DIR/LumaWall"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Release executable not found at $EXECUTABLE" >&2
  exit 1
fi

cp "$EXECUTABLE" "$MACOS/LumaWall"
chmod +x "$MACOS/LumaWall"

RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 2 -type d -name 'LumaWall_LumaWall.bundle' -print -quit)"
if [[ -n "$RESOURCE_BUNDLE" ]]; then
  ditto "$RESOURCE_BUNDLE" "$RESOURCES/LumaWall_LumaWall.bundle"
else
  echo "SwiftPM resource bundle was not found." >&2
  exit 1
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>LumaWall</string>
  <key>CFBundleExecutable</key>
  <string>LumaWall</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>LumaWall</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMultipleInstancesProhibited</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
  <key>NSScreenCaptureUsageDescription</key>
  <string>LumaWall uses screen capture only when you enable system-audio reactive wallpapers.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>LumaWall may support creator wallpapers that explicitly request microphone input.</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>LumaWall Wallpaper Package</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>dev.parthdongre.lumawall.wallpaper</string>
      </array>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>dev.parthdongre.lumawall.wallpaper</string>
      <key>UTTypeDescription</key>
      <string>LumaWall Wallpaper Package</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.zip-archive</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>wall</string>
        </array>
        <key>public.mime-type</key>
        <string>application/x-lumawall-wallpaper</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS/PkgInfo"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "==> Applying ad-hoc code signature"
  codesign --force --deep --sign - "$APP"
else
  echo "==> Signing with $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi

codesign --verify --deep --strict "$APP"

ZIP="$DIST/LumaWall-$VERSION-macOS.zip"
DMG="$DIST/LumaWall-$VERSION.dmg"
PKG="$DIST/LumaWall-$VERSION.pkg"

echo "==> Creating ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Creating styled DMG"
DMG_ROOT="$(mktemp -d)"
RW_DMG="$DIST/LumaWall-$VERSION-rw.dmg"
VOLUME_NAME="LumaWall $VERSION"
MOUNT_DIR="/Volumes/$VOLUME_NAME"

cleanup() {
  if mount | grep -Fq "$MOUNT_DIR"; then
    hdiutil detach "$MOUNT_DIR" -quiet || true
  fi
  rm -rf "$DMG_ROOT"
  rm -f "$RW_DMG"
}
trap cleanup EXIT

ditto "$APP" "$DMG_ROOT/LumaWall.app"
ln -s /Applications "$DMG_ROOT/Applications"

mkdir -p "$DMG_ROOT/.background"
swift "$ROOT/scripts/make-dmg-background.swift" "$DMG_ROOT/.background/background.png"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDRW \
  "$RW_DMG" >/dev/null

hdiutil attach \
  "$RW_DMG" \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$MOUNT_DIR" >/dev/null

osascript <<APPLESCRIPT
tell application "Finder"
  repeat 40 times
    if exists disk "$VOLUME_NAME" then exit repeat
    delay 0.25
  end repeat

  if not (exists disk "$VOLUME_NAME") then
    error "Mounted LumaWall DMG did not become visible to Finder."
  end if

  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set bounds of container window to {200, 200, 860, 620}

    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.png"

    set position of item "LumaWall.app" of container window to {180, 220}
    set position of item "Applications" of container window to {480, 220}

    update without registering applications
    delay 2
    close container window
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert \
  "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG" >/dev/null

rm -f "$RW_DMG"

echo "==> Creating PKG"
pkgbuild   --component "$APP"   --install-location /Applications   --identifier "$BUNDLE_ID"   --version "$VERSION"   "$PKG" >/dev/null

(
  cd "$DIST"
  shasum -a 256     "$(basename "$ZIP")"     "$(basename "$DMG")"     "$(basename "$PKG")"     > SHA256SUMS.txt
)

echo
echo "LumaWall $VERSION packaged successfully:"
echo "  $APP"
echo "  $ZIP"
echo "  $DMG"
echo "  $PKG"
echo "  $DIST/SHA256SUMS.txt"
