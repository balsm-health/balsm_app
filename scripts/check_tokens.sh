#!/usr/bin/env bash
# Fails when a design value is written outside its token home. See CODING_STANDARDS.md §13.
#
# Every token type lives in packages/core/lib/src/kit/ (AppColors, AppRadii, FontSizes, Motion, …).
# A bare colour, corner radius, font size or animation duration at a call site is an error. A value used by
# one file only may be a private top-level `const _name = …;` with a comment saying why.
set -euo pipefail
cd "$(dirname "$0")/.."

SCOPE=(--include=*.dart app modules packages)
SKIP='/(build|\.dart_tool|test)/|\.g\.dart|\.i69n\.dart'
fail=0

report() { # title, hits
  if [ -n "$2" ]; then echo "$1:"; echo "$2"; echo; fail=1; fi
}

# Colour: only the palette files may hold a literal.
COLOR_HOMES='/kit/app_colors\.dart|/kit/accent\.dart|/kit/app_shadows\.dart|/dev/dev_console_colors\.dart|/maintenance/maintenance_tokens\.dart|/widgets/badges\.dart|/screens/walkthrough_screen\.dart'
report "Colours outside AppColors" "$(grep -rnE "Color\(0x[0-9A-Fa-f]{8}\)|(^|[^A-Za-z_])Colors\.[a-zA-Z0-9]+" "${SCOPE[@]}" \
  | grep -vE "$SKIP|Colors\.transparent" | grep -vE "^[^:]*($COLOR_HOMES):" || true)"

# Radius, font size, animation duration: no number at the call site (private consts excepted).
SCALE_HOMES='/kit/app_radii\.dart|/kit/font_sizes\.dart|/kit/motion\.dart|/kit/typo\.dart'
report "Bare corner radii (use AppRadii)" "$(grep -rnE "(BorderRadius|Radius)\.circular\([0-9.]+\)" "${SCOPE[@]}" \
  | grep -vE "$SKIP" | grep -vE "^[^:]*($SCALE_HOMES):" || true)"
report "Bare font sizes (use FontSizes)" "$(grep -rnE "fontSize: ?[0-9.]+" "${SCOPE[@]}" \
  | grep -vE "$SKIP" | grep -vE "^[^:]*($SCALE_HOMES):" || true)"
report "Bare animation durations (use Motion)" "$(grep -rnE "(d|D)uration: (const )?Duration\(milliseconds: ?[0-9]+\)|AnimationController\([^)]*Duration\(" "${SCOPE[@]}" \
  | grep -vE "$SKIP" | grep -vE "^[^:]*($SCALE_HOMES):" || true)"

if [ "$fail" -ne 0 ]; then
  echo "Add or reuse a token in packages/core/lib/src/kit/ (see CODING_STANDARDS.md §13)."
  exit 1
fi
echo "tokens ok: colours, radii, font sizes and animation durations all come from their token home"
