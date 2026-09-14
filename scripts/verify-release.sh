#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION")}"
DIST="$ROOT/dist"
APP="$DIST/LumaWall.app"
ZIP="$DIST/LumaWall-$VERSION-macOS.zip"
DMG="$DIST/LumaWall-$VERSION.dmg"
PKG="$DIST/LumaWall-$VERSION.pkg"
CHECKSUMS="$DIST/SHA256SUMS.txt"
REQUIRE_DEVELOPER_ID="${REQUIRE_DEVELOPER_ID:-0}"
REQUIRE_NOTARIZED="${REQUIRE_NOTARIZED:-0}"

for artifact in "$APP" "$ZIP" "$DMG" "$PKG" "$CHECKSUMS"; do
  if [[ ! -e "$artifact" ]]; then
    echo "Required release artifact not found: $artifact" >&2
    exit 1
  fi
done

echo "==> Verifying packaged app metadata"
test -f "$APP/Contents/Resources/LumaWall.icns"
ICON_FILE="$(plutil -extract CFBundleIconFile raw "$APP/Contents/Info.plist")"
test "$ICON_FILE" = "LumaWall.icns"

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Verifying release checksums"
(
  cd "$DIST"
  shasum -a 256 -c "$(basename "$CHECKSUMS")"
)

if [[ "$REQUIRE_DEVELOPER_ID" == "1" ]]; then
  echo "==> Verifying Developer ID identities"
  APP_SIGNATURE="$(codesign -dvvv "$APP" 2>&1)"
  echo "$APP_SIGNATURE" | grep -q "Authority=Developer ID Application:"
  echo "$APP_SIGNATURE" | grep -q "runtime"

  PKG_SIGNATURE="$(pkgutil --check-signature "$PKG" 2>&1)"
  echo "$PKG_SIGNATURE" | grep -q "Developer ID Installer"

  codesign --verify --verbose=2 "$DMG"
fi

if [[ "$REQUIRE_NOTARIZED" == "1" ]]; then
  echo "==> Verifying stapled notarization tickets"
  xcrun stapler validate "$DMG"
  xcrun stapler validate "$PKG"

  echo "==> Asking Gatekeeper to assess release containers"
  spctl --assess --verbose=2 --type open --context context:primary-signature "$DMG"
  spctl --assess --verbose=2 --type install "$PKG"
fi

echo "LumaWall $VERSION release artifacts verified."
