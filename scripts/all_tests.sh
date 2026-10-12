#!/usr/bin/env bash
# Run every Dart test in the repo: each workspace package, then the repo-root
# suites (golden, i18n, phi_leak_fuzz, web_smoke) that live outside them.
#
# Why not `melos run test`: melos 7 reads its config from pubspec.yaml, not
# melos.yaml, so this repo's melos.yaml scripts resolve to nothing —
# `melos list` reports no packages at all. Until that is migrated, iterating
# the package directories is the only thing that actually runs the suite.
#
# Runs every package even after one fails, so a single red package does not
# hide the state of the rest, and exits non-zero if any failed.
#
# Usage: scripts/all_tests.sh
set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"   # repo root

failed=()

run_pkg() {
  local dir="$1"
  # Several modules ship an empty test/ directory. Both runners exit non-zero on
  # "no tests found", which would report them as failures, so skip them.
  [ -d "$dir/test" ] || return 0
  if [ -z "$(find "$dir/test" -name '*_test.dart' -print -quit)" ]; then
    echo ""
    echo "· $dir  (no tests)"
    return 0
  fi

  # Pure-Dart packages have no flutter_test binding; `flutter test` errors there.
  local runner="flutter"
  if ! grep -q "sdk: flutter" "$dir/pubspec.yaml" 2>/dev/null; then
    runner="dart"
  fi

  echo ""
  echo "▶ $dir  (fvm $runner test)"
  if ! (cd "$dir" && fvm "$runner" test); then
    failed+=("$dir")
  fi
}

for dir in packages/* modules/* app; do
  run_pkg "$dir"
done

echo ""
echo "▶ (repo root)  fvm flutter test test"
if ! fvm flutter test test; then
  failed+=("(repo root)")
fi

echo ""
if [ ${#failed[@]} -eq 0 ]; then
  echo "✓ All tests passed"
  exit 0
fi

echo "✗ Failing packages (${#failed[@]}):"
printf '  - %s\n' "${failed[@]}"
exit 1
