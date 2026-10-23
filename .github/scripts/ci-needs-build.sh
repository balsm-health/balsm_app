#!/usr/bin/env bash
# Decides whether CI must analyze, test and build this commit, or whether the
# last green run already covers it.
#
#   ci-needs-build.sh <last-green-sha or empty>
#
# Prints `true` or `false`, with the reason on stderr.
#
# Skipping is only safe against the last *successful* run: a skipped job counts
# as passed, so measuring from the previous push would let a docs-only commit
# turn a failed build green. Measured from the last green run, a red build
# stays red until code changes and a new run passes.
set -euo pipefail

green=${1:-}
say() { echo "$*" >&2; }

if [ -z "$green" ]; then
  say "No earlier green run on this pull request: build."
  echo true; exit 0
fi
if ! git cat-file -e "$green^{commit}" 2>/dev/null || ! git merge-base --is-ancestor "$green" HEAD; then
  say "Last green run ($green) is not in this branch's history (force-push?): build."
  echo true; exit 0
fi

# Files that cannot change what CI analyzes, tests or builds. Anything else —
# Dart, assets, native android/ios code, Gradle/Xcode/pubspec settings, env
# files, this workflow — rebuilds. Unknown files rebuild too.
not_build=(
  ':(exclude)*.md'
  ':(exclude)docs/**'
  ':(exclude).claude/**'
  ':(exclude).agents/**'
  ':(exclude).cursor/**'
  ':(exclude).vscode/**'
  ':(exclude).idea/**'
  ':(exclude).github/**'
  ':(exclude)LICENSE*'
)
changed=$(git diff --name-only "$green" HEAD -- . "${not_build[@]}")
# Excluded above but still build-relevant: ci.yml and this script decide what
# runs, and anything under app/assets/ ships in the bundle, .md files included.
changed+=$'\n'$(git diff --name-only "$green" HEAD -- .github/workflows/ci.yml .github/scripts/ci-needs-build.sh app/assets)

relevant=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # A pubspec whose only change is its `version:` line (the version raise)
  # builds the same app.
  if [[ "$f" == *pubspec.yaml ]]; then
    other=$(git diff -U0 "$green" HEAD -- "$f" | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE '^[+-]version:' || true)
    [ -z "$other" ] && continue
  fi
  relevant+=("$f")
done <<< "$changed"

if [ ${#relevant[@]} -eq 0 ]; then
  say "Nothing build-relevant changed since the last green run ($green): skip."
  echo false
else
  say "Build-relevant changes since the last green run ($green):"
  printf '  %s\n' "${relevant[@]:0:20}" >&2
  echo true
fi
