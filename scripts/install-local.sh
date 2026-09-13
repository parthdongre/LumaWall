#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.3.5}"
VERSION="$VERSION" "$ROOT/scripts/package-macos.sh"

APP="$ROOT/dist/LumaWall.app"
TARGET="/Applications/LumaWall.app"

echo "==> Installing LumaWall to /Applications"
if [[ -w "/Applications" ]]; then
  rm -rf "$TARGET"
  ditto "$APP" "$TARGET"
else
  sudo rm -rf "$TARGET"
  sudo ditto "$APP" "$TARGET"
fi

echo "==> Launching LumaWall"
open "$TARGET"
