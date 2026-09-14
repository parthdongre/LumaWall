#!/usr/bin/env bash
set -euo pipefail

failures=0
warnings=0

ok() {
  printf '✓ %s\n' "$1"
}

warn() {
  printf '⚠ %s\n' "$1"
  warnings=$((warnings + 1))
}

fail() {
  printf '✗ %s\n' "$1" >&2
  failures=$((failures + 1))
}

note() {
  printf '  %s\n' "$1"
}

printf 'LumaWall development environment\n'
printf '===============================\n\n'

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
  note "Install Apple Command Line Tools with: xcode-select --install"
elif [[ "$developer_dir" == *"/CommandLineTools"* ]]; then
  ok "Apple Command Line Tools: $developer_dir"
  note "Full Xcode is optional for normal build/run/test."
else
  ok "Full Xcode developer directory: $developer_dir"
fi

if command -v swift >/dev/null 2>&1; then
  swift_version="$(swift --version | head -n 1)"
  ok "$swift_version"
else
  fail "Swift is unavailable."
fi

if command -v swiftc >/dev/null 2>&1; then
  ok "Swift compiler: $(command -v swiftc)"
else
  fail "swiftc is unavailable."
fi

if xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
  sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
  ok "macOS SDK: $sdk_path"
else
  fail "macOS SDK could not be resolved."
fi

if xcrun --sdk macosx --find metal >/dev/null 2>&1; then
  metal_path="$(xcrun --sdk macosx --find metal)"
  ok "Standalone Metal compiler: $metal_path"
else
  warn "Standalone Metal compiler is not installed."
  note "This is expected with Command Line Tools and is not required for LumaWall."
  note "Bundled shader sources are copied as resources; Metal wallpapers compile source at runtime."
fi

if command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1; then
  xcode_version="$(xcodebuild -version | head -n 1)"
  ok "$xcode_version"
else
  warn "xcodebuild is unavailable."
  note "Normal make run/build/test uses SwiftPM and does not require xcodebuild."
fi

if swift package dump-package >/dev/null 2>&1; then
  ok "Swift package manifest resolves"
else
  fail "SwiftPM could not resolve Package.swift."
fi

printf '\n'

if [[ "$failures" -ne 0 ]]; then
  printf 'Environment check failed with %d problem(s).\n' "$failures" >&2
  printf 'Fix the items above, then run: make doctor\n' >&2
  exit 1
fi

if [[ "$warnings" -ne 0 ]]; then
  printf 'Environment is ready with %d optional warning(s).\n' "$warnings"
else
  printf 'Environment looks ready.\n'
fi

printf 'Run: make run\n'
