#!/usr/bin/env bash
# Single source of truth for Flutter build/run/test commands across brands,
# environments, and platforms. Consumed by melos scripts, VS Code tasks, and
# CI/CD — so the flavor/target/dart-define wiring lives in ONE place.
#
# Usage: scripts/flutter.sh <action> [brand] [env] [-- extra flutter args...]
#   action : run | apk | aab | ios | web | test | integration
#   brand  : balsm (default)            — Android flavor == brand
#   env    : dev (default) | staging | prod
#
# Conventions (per brand/env):
#   entrypoint : lib/brands/<brand>/main_<brand>.dart
#   flavor     : <brand>   (NOT the env — Android/iOS flavor is the brand)
#   defines    : env/<brand>/<env>.json + env/shared.json
#   web        : no --flavor (Flutter web has no flavor concept)
#
# Examples:
#   scripts/flutter.sh run balsm dev -d <device-id>
#   scripts/flutter.sh apk balsm prod
#   scripts/flutter.sh web balsm prod
set -euo pipefail

ACTION="${1:?action required: run|apk|aab|ios|web|test|integration}"; shift || true
BRAND="${1:-balsm}"; [ "$#" -gt 0 ] && shift || true
ENVN="${1:-dev}";   [ "$#" -gt 0 ] && shift || true
EXTRA=("$@")

# Run from the app package regardless of caller cwd (melos/CI/tasks).
cd "$(dirname "$0")/../app"

TARGET="lib/brands/$BRAND/main_$BRAND.dart"
DEFINES=(--dart-define-from-file="env/$BRAND/$ENVN.json" --dart-define-from-file=env/shared.json)
FLAVOR=(--flavor "$BRAND")

case "$ACTION" in
  run)         set -x; flutter run "${FLAVOR[@]}" -t "$TARGET" "${DEFINES[@]}" "${EXTRA[@]}" ;;
  apk)         set -x; flutter build apk --release "${FLAVOR[@]}" -t "$TARGET" "${DEFINES[@]}" "${EXTRA[@]}" ;;
  aab)         set -x; flutter build appbundle --release "${FLAVOR[@]}" -t "$TARGET" "${DEFINES[@]}" "${EXTRA[@]}" ;;
  ios)         set -x; flutter build ios --release --no-codesign "${FLAVOR[@]}" -t "$TARGET" "${DEFINES[@]}" "${EXTRA[@]}" ;;
  web)         set -x; flutter build web --release -t "$TARGET" "${DEFINES[@]}" "${EXTRA[@]}" ;;
  test)        set -x; flutter test "${EXTRA[@]}" ;;
  integration) set -x; flutter test integration_test "${FLAVOR[@]}" "${EXTRA[@]}" ;;
  *) echo "flutter.sh: unknown action '$ACTION' (run|apk|aab|ios|web|test|integration)" >&2; exit 2 ;;
esac
