#!/usr/bin/env bash
# Run all patient-app UI tests: widget tests + the integration_test UI walk.
# Delegates to scripts/flutter.sh (single source of truth for the wiring).
# Usage: scripts/ui_test.sh [device-id]
#   device-id defaults to a booted iOS simulator if one is found.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  DEVICE="$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '[0-9A-F-]{36}' | head -1 || true)"
fi

echo "▶ Widget tests"
"$HERE/flutter.sh" test

echo "▶ Integration tests${DEVICE:+ (device: $DEVICE)}"
if [ -n "$DEVICE" ]; then
  "$HERE/flutter.sh" integration balsm dev -d "$DEVICE"
else
  "$HERE/flutter.sh" integration balsm dev
fi

echo "✓ All UI tests passed"
