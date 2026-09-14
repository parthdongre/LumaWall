#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Clearing stale SwiftPM build state"
rm -rf .build
swift package reset

echo "==> Re-checking LumaWall development environment"
bash scripts/doctor.sh

echo
echo "Repair complete. Run: make run"
