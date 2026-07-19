#!/usr/bin/env bash
# Run all patient-app UI tests: widget tests + the integration_test UI walk.
# Delegates to tool/build.dart (single source of truth for the wiring); this
# wrapper only adds booted-simulator auto-detection.
# Usage: scripts/ui_test.sh [device-id]
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"   # repo root (so tool/build.dart resolves)

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  DEVICE="$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '[0-9A-F-]{36}' | head -1 || true)"
fi

echo "▶ Widget tests"
dart run tool/build.dart test

echo "▶ Integration tests${DEVICE:+ (device: $DEVICE)}"
if [ -n "$DEVICE" ]; then
  dart run tool/build.dart integration balsm dev -d "$DEVICE"
else
  dart run tool/build.dart integration balsm dev
fi

echo "✓ All UI tests passed"
