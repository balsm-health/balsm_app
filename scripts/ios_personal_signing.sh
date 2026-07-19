#!/usr/bin/env bash
# Toggle iOS entitlements so a FREE personal-team can sign & run the app on your
# own iPhone (no paid Apple Developer account). The prod entitlements declare
# associated-domains + App Groups, which free signing rejects.
#
#   scripts/ios_personal_signing.sh on    # strip paid-only entitlements
#   scripts/ios_personal_signing.sh off   # restore prod entitlements
#
# After `on`: in Xcode → Runner → Signing & Capabilities, set Team = your Apple
# ID (Personal Team). Then `dart run tool/build.dart run balsm dev -d <iphone>`
# (or flutter run). Deep links + App Groups are inert in this build.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/../app/ios/Runner" && pwd)"
PROD="$DIR/Runner.entitlements"
PERSONAL="$DIR/Runner-Personal.entitlements"
BAK="$DIR/Runner.entitlements.prod.bak"

case "${1:-}" in
  on)
    if [ -f "$BAK" ]; then echo "already on (backup at $BAK)"; exit 0; fi
    cp "$PROD" "$BAK"
    cp "$PERSONAL" "$PROD"
    echo "✓ personal-team entitlements active — paid capabilities stripped."
    echo "  Set Team=your Apple ID in Xcode, then build/run on your iPhone."
    echo "  Deep links + App Groups are disabled in this build."
    ;;
  off)
    if [ ! -f "$BAK" ]; then echo "already off (no backup)"; exit 0; fi
    mv "$BAK" "$PROD"
    echo "✓ prod entitlements restored."
    ;;
  *)
    echo "usage: scripts/ios_personal_signing.sh on|off" >&2; exit 2 ;;
esac
