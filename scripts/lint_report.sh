#!/usr/bin/env bash
# Lint baseline: runs `dart analyze` in every package and writes a per-package
# and per-rule summary of errors, warnings and infos.
#
#   scripts/lint_report.sh            # from the repo root
#   scripts/lint_report.sh --format   # run `dart format .` first (rewrites files), then analyze
#   scripts/lint_report.sh --fix --format   # also `dart fix --apply` in every package (rewrites files)
#
# Output: build/lint-report/summary.txt (+ one machine-format file per package).
# Never fails on lint issues — it measures, CI enforces. See CODING_STANDARDS.md §10.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

if command -v fvm >/dev/null 2>&1; then FLUTTER="fvm flutter"; DART="fvm dart"; else FLUTTER="flutter"; DART="dart"; fi
OUT=build/lint-report
rm -rf "$OUT"; mkdir -p "$OUT"

DO_FORMAT=0; DO_FIX=0
for a in "$@"; do
  case "$a" in --format) DO_FORMAT=1;; --fix) DO_FIX=1;; esac
done

PKGS=(packages/core packages/balsm_api)
for m in modules/*/; do PKGS+=("${m%/}"); done
PKGS+=(app .)

ROOT=$(pwd)
# Pass 1: resolve packages and apply fixes; pass 2 (below) analyzes.
for p in "${PKGS[@]}"; do
  name=$( [ "$p" = "." ] && echo root || echo "${p//\//_}" )
  echo "▶ $p"
  if ! (cd "$p" && $FLUTTER pub get >"$ROOT/$OUT/$name.pubget.log" 2>&1); then
    echo "  pub get failed in $p — see $OUT/$name.pubget.log"; continue
  fi
  if [ "$DO_FIX" = 1 ]; then
    (cd "$p" && $DART fix --apply >"$ROOT/$OUT/$name.fix.log" 2>&1) && echo "  fix: $(tail -1 "$ROOT/$OUT/$name.fix.log")"
  fi
done

if [ "$DO_FORMAT" = 1 ]; then
  echo "▶ dart format ."
  # page_width comes from each package's analysis_options.yaml (120).
  $DART format . >"$OUT/format.log" 2>&1
  tail -1 "$OUT/format.log"
fi

for p in "${PKGS[@]}"; do
  name=$( [ "$p" = "." ] && echo root || echo "${p//\//_}" )
  echo "▶ analyze $p"
  targets=(.); [ "$p" = "." ] && targets=(test tool)
  # Capture both streams; the summary below keeps only SEVERITY|… machine lines.
  (cd "$p" && $DART analyze --format=machine "${targets[@]}" >"$ROOT/$OUT/$name.txt" 2>&1)
done

{
  echo "Lint report — $(date '+%Y-%m-%d %H:%M')  ($($DART --version 2>&1 | head -1))"
  [ -f "$OUT/format.log" ] && echo "Format: $(tail -1 "$OUT/format.log")"
  echo
  echo "== pub get failures"
  for l in "$OUT"/*.pubget.log; do grep -qiE '^(Because|error|Could not)' "$l" && echo "$(basename "$l" .pubget.log): $(grep -iE '^(Because|error|Could not)' "$l" | head -2)"; done
  echo
  echo "== Totals"
  cat "$OUT"/*.txt | grep -E '^(ERROR|WARNING|INFO)\|' | cut -d'|' -f1 | sort | uniq -c | sort -rn
  echo
  echo "== Per package (errors / warnings / infos)"
  for f in "$OUT"/*.txt; do
    case "$f" in *.pubget.log) continue;; esac
    e=$(grep -c '^ERROR|' "$f"); w=$(grep -c '^WARNING|' "$f"); i=$(grep -c '^INFO|' "$f")
    printf "%-28s %6s %6s %6s\n" "$(basename "$f" .txt)" "$e" "$w" "$i"
  done
  echo
  echo "== All errors"
  grep -h '^ERROR|' "$OUT"/*.txt | awk -F'|' '{print $3" — "$4":"$5" — "$8}' | head -200
  echo
  echo "== By rule (severity, rule, count)"
  cat "$OUT"/*.txt | grep -E '^(ERROR|WARNING|INFO)\|' | awk -F'|' '{print $1" "$3}' | sort | uniq -c | sort -rn
} > "$OUT/summary.txt"

echo
head -40 "$OUT/summary.txt"
echo "…full report: $OUT/summary.txt"
