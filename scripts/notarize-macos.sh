#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.4.0}"
DIST="$ROOT/dist"
DMG="$DIST/LumaWall-$VERSION.dmg"
PKG="$DIST/LumaWall-$VERSION.pkg"
ZIP="$DIST/LumaWall-$VERSION-macOS.zip"
CHECKSUMS="$DIST/SHA256SUMS.txt"

for artifact in "$DMG" "$PKG" "$ZIP"; do
  if [[ ! -f "$artifact" ]]; then
    echo "Required release artifact not found: $artifact" >&2
    exit 1
  fi
done

notary_submit() {
  local artifact="$1"

  if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    xcrun notarytool submit "$artifact"       --keychain-profile "$NOTARY_KEYCHAIN_PROFILE"       --wait
    return
  fi

  if [[ -n "${NOTARY_KEY_FILE:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]]; then
    xcrun notarytool submit "$artifact"       --key "$NOTARY_KEY_FILE"       --key-id "$NOTARY_KEY_ID"       --issuer "$NOTARY_ISSUER_ID"       --wait
    return
  fi

  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$artifact"       --apple-id "$APPLE_ID"       --team-id "$APPLE_TEAM_ID"       --password "$APPLE_APP_PASSWORD"       --wait
    return
  fi

  echo "No notarization credentials configured." >&2
  echo "Use NOTARY_KEYCHAIN_PROFILE, App Store Connect API key variables, or Apple ID credentials." >&2
  exit 1
}

echo "==> Notarizing DMG"
notary_submit "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Notarizing PKG"
notary_submit "$PKG"
xcrun stapler staple "$PKG"
xcrun stapler validate "$PKG"

echo "==> Regenerating checksums after stapling"
(
  cd "$DIST"
  shasum -a 256     "$(basename "$ZIP")"     "$(basename "$DMG")"     "$(basename "$PKG")"     > "$(basename "$CHECKSUMS")"
)

echo "LumaWall $VERSION notarization complete."
