#!/bin/zsh
# Host side of design_port_e2e_test.dart's screenshot handshake (iOS simulator).
#
# The test writes a PNG name to Documents/e2e_shot/request in the app's data
# container (a host folder for a simulator app); this takes the picture with
# `xcrun simctl io <udid> screenshot` and answers with done-<name>. The
# `watching` file tells the test a watcher is running.
#
# usage: simctl_shot_watcher.sh <simulator-udid> <out-dir> [bundle-id]
UDID=$1; OUT=$2; BUNDLE=${3:-app.balsm.health}
if [[ -z "$UDID" || -z "$OUT" ]]; then
  echo "usage: $0 <simulator-udid> <out-dir> [bundle-id]" >&2
  exit 2
fi
mkdir -p "$OUT"
while true; do
  # Resolved on every pass: `flutter drive` reinstalls the app.
  C=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null)
  if [[ -n "$C" ]]; then
    D="$C/Documents/e2e_shot"
    mkdir -p "$D"; touch "$D/watching"
    if [[ -f "$D/request" ]]; then
      N=$(cat "$D/request")
      xcrun simctl io "$UDID" screenshot --type=png "$OUT/$N.png" >/dev/null 2>&1
      rm -f "$D/request"; touch "$D/done-$N"
      echo "shot $N"
    fi
  fi
  sleep 0.1
done
