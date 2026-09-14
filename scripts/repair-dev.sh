#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Clearing stale SwiftPM build state"
rm -rf .build
swift package reset

echo
echo "SwiftPM repair complete."

echo
echo "==> Re-checking LumaWall development environment"
set +e
bash scripts/doctor.sh
DOCTOR_STATUS=$?
set -e

if [[ "$DOCTOR_STATUS" -ne 0 ]]; then
  echo
  echo "Repair succeeded, but the development environment still needs attention."
  echo "Fix the doctor findings, then run: make doctor"
  exit 0
fi

echo
echo "Environment is healthy. Run: make run"
