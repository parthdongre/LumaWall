#!/usr/bin/env bash
set -euo pipefail

failures=0

ok() {
  printf '✓ %s\\n' "$1"
}

fail() {
  printf '✗ %s\\n' "$1" >&2
  failures=$((failures + 1))
}

note() {
  printf '  %s\\n' "$1"
}

printf 'LumaWall development environment\\n'
printf '===============================\\n\\n'

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "LumaWall development requires macOS."
else
  version="$(sw_vers -productVersion)"
  major="${version%%.*}"

  if [[ "$major" -ge 14 ]]; then
    ok "macOS $version"
  else
    fail "macOS 14 Sonoma or newer is required (found $version)."
  fi
fi

developer_dir="$(xcode-select -p 2>/dev/null || true)"

if [[ -z "$developer_dir" ]]; then
  fail "No active Apple developer directory."
  note "Install Xcode, then run:"
  note "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
elif [[ "$developer_dir" == *"/CommandLineTools"* ]]; then
  fail "Command Line Tools are selected instead of full Xcode."
  note "LumaWall uses SwiftUI/AppKit plus runtime Metal shader compilation."
  note "Switch to full Xcode:"
  note "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
else
  ok "Developer directory: $developer_dir"
fi

if command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1; then
  xcode_version="$(xcodebuild -version | head -n 1)"
  ok "$xcode_version"
else
  fail "xcodebuild is unavailable."
fi

if command -v swift >/dev/null 2>&1; then
  swift_version="$(swift --version | head -n 1)"
  ok "$swift_version"
else
  fail "Swift is unavailable."
fi

if xcrun --sdk macosx --find metal >/dev/null 2>&1; then
  metal_path="$(xcrun --sdk macosx --find metal)"
  ok "Metal compiler: $metal_path"
else
  fail "Metal compiler is unavailable."
  note "This is the cause of: unable to spawn process metal."
fi

if xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
  sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
  ok "macOS SDK: $sdk_path"
else
  fail "macOS SDK could not be resolved."
fi

printf '\\n'

if [[ "$failures" -ne 0 ]]; then
  printf 'Environment check failed with %d problem(s).\\n' "$failures" >&2
  printf 'Fix the items above, then run: make doctor\\n' >&2
  exit 1
fi

printf 'Environment looks ready. Run: make run\\n'
