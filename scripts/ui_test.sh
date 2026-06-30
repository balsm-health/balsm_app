#!/usr/bin/env bash
# Run all patient-app UI tests: widget tests + the Flutter Driver UI walk.
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

echo "▶ Driver UI tests${DEVICE:+ (device: $DEVICE)}"
DRIVE_ARGS=(
  --target=test_driver/main_patient_driver.dart
  --driver=test_driver/main_patient_driver_test.dart
)
[ -n "$DEVICE" ] && DRIVE_ARGS+=(-d "$DEVICE")
flutter drive "${DRIVE_ARGS[@]}"

echo "✓ All UI tests passed"
