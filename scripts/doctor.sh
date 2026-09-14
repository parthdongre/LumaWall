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
full_xcode_selected=0

if [[ -z "$developer_dir" ]]; then
  fail "No active Apple developer directory."
  note "Install full Xcode from the App Store or Apple Developer, then run:"
  note "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
elif [[ "$developer_dir" == *"/CommandLineTools"* ]]; then
  fail "Command Line Tools are selected instead of full Xcode."
  note "Swift 6.4 / modern SwiftUI uses compiler macro plugins such as SwiftUIMacros.StateMacro."
  note "Those plugins are not available in a Command Line Tools-only setup."
  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    note "Xcode is installed. Switch to it with:"
    note "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  else
    note "Install full Xcode first, then run:"
    note "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  fi
else
  full_xcode_selected=1
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

if [[ "$full_xcode_selected" -eq 1 ]]; then
  if command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1; then
    xcode_version="$(xcodebuild -version | head -n 1)"
    ok "$xcode_version"
  else
    fail "xcodebuild is unavailable even though full Xcode is selected."
  fi

  probe_dir="$(mktemp -d)"
  probe_file="$probe_dir/LumaWallSwiftUIProbe.swift"
  cat > "$probe_file" <<'SWIFT'
import SwiftUI

struct LumaWallSwiftUIProbe: View {
  @State private var enabled = false

  var body: some View {
    Toggle("LumaWall", isOn: $enabled)
  }
}
SWIFT

  if xcrun swiftc -typecheck "$probe_file" >/dev/null 2>"$probe_dir/error.txt"; then
    ok "SwiftUI macro plugins are available"
  else
    fail "SwiftUI macro plugins could not be loaded."
    note "This commonly appears as SwiftUIMacros.StateMacro not found."
    note "Try: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    note "Then: xcodebuild -runFirstLaunch"
    if [[ -s "$probe_dir/error.txt" ]]; then
      note "Compiler probe: $(head -n 1 "$probe_dir/error.txt")"
    fi
  fi
  rm -rf "$probe_dir"
fi

if xcrun --sdk macosx --find metal >/dev/null 2>&1; then
  metal_path="$(xcrun --sdk macosx --find metal)"
  ok "Standalone Metal compiler: $metal_path"
else
  warn "Standalone Metal compiler is not installed."
  note "Current LumaWall does not require it for bundled shaders because Resources are copied verbatim."
  note "If a future target compiles .metal files at build time under Xcode 26+, install it with:"
  note "  xcodebuild -downloadComponent MetalToolchain"
fi

if swift package dump-package >/dev/null 2>&1; then
  ok "Swift package manifest resolves"
else
  fail "SwiftPM could not resolve Package.swift."
fi

printf '\n'

if [[ "$failures" -ne 0 ]]; then
  printf 'Environment check failed with %d problem(s).\n' "$failures" >&2
  if [[ "$developer_dir" == *"/CommandLineTools"* ]]; then
    printf 'Install/select full Xcode, then run: make repair && make doctor\n' >&2
  else
    printf 'Fix the items above, then run: make doctor\n' >&2
  fi
  exit 1
fi

if [[ "$warnings" -ne 0 ]]; then
  printf 'Environment is ready with %d optional warning(s).\n' "$warnings"
else
  printf 'Environment looks ready.\n'
fi

printf 'Run: make run\n'
