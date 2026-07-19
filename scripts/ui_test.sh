#!/usr/bin/env bash
# Run all patient-app UI tests: widget tests + the integration_test UI walk.
# Usage: scripts/ui_test.sh [device-id]
#   device-id defaults to a booted iOS simulator if one is found.
set -euo pipefail

cd "$(dirname "$0")/../app"

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  DEVICE="$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '[0-9A-F-]{36}' | head -1 || true)"
fi

echo "▶ Widget tests"
flutter test

echo "▶ Integration tests${DEVICE:+ (device: $DEVICE)}"
INT_ARGS=(integration_test --flavor balsm)
[ -n "$DEVICE" ] && INT_ARGS+=(-d "$DEVICE")
flutter test "${INT_ARGS[@]}"

echo "✓ All UI tests passed"
