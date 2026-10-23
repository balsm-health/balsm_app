#!/usr/bin/env bash
# Decides which CI jobs this commit needs, or whether the last green run
# already covers it.
#
#   ci-needs-build.sh <last-green-sha or empty>
#
# Prints two lines for $GITHUB_OUTPUT, with the reasons on stderr:
#   dart=true|false   analyze, tests and coverage: Dart and what it reads
#   build=true|false  the web/Android/iOS builds: all of that plus native code
# A change under a package's own platform folder (app/android/, app/ios/,
# modules/<m>/ios/, …) is native only: it rebuilds but cannot move analysis,
# tests or coverage. Dart under lib/ — even lib/src/web/ — is Dart.
#
# Skipping is only safe against the last *successful* run: a skipped job counts
# as passed, so measuring from the previous push would let a docs-only commit
# turn a failed build green. Measured from the last green run, a red build
# stays red until code changes and a new run passes.
set -euo pipefail

green=${1:-}
say() { echo "$*" >&2; }

if [ -z "$green" ]; then
  say "No earlier green run on this pull request: run everything."
  printf 'dart=true\nbuild=true\n'; exit 0
fi
if ! git cat-file -e "$green^{commit}" 2>/dev/null || ! git merge-base --is-ancestor "$green" HEAD; then
  say "Last green run ($green) is not in this branch's history (force-push?): run everything."
  printf 'dart=true\nbuild=true\n'; exit 0
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

# A Flutter platform folder directly under a package root.
native='^(app|modules/[^/]+|packages/[^/]+)/(android|ios|macos|linux|windows|web)/'

dart=(); native_only=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # A pubspec whose only change is its `version:` line (the version raise)
  # builds the same app.
  if [[ "$f" == *pubspec.yaml ]]; then
    other=$(git diff -U0 "$green" HEAD -- "$f" | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE '^[+-]version:' || true)
    [ -z "$other" ] && continue
  fi
  # ci.yml and this script decide what runs, so they count as both.
  if [[ "$f" =~ $native ]]; then native_only+=("$f"); else dart+=("$f"); fi
done <<< "$(printf '%s\n' "$changed" | sort -u)"

if [ ${#dart[@]} -gt 0 ]; then
  say "Dart-relevant changes since the last green run ($green):"
  printf '  %s\n' "${dart[@]:0:20}" >&2
fi
if [ ${#native_only[@]} -gt 0 ]; then
  say "Native-only changes since the last green run ($green):"
  printf '  %s\n' "${native_only[@]:0:20}" >&2
fi
if [ ${#dart[@]} -eq 0 ] && [ ${#native_only[@]} -eq 0 ]; then
  say "Nothing build-relevant changed since the last green run ($green): skip."
fi

has_dart=false; [ ${#dart[@]} -gt 0 ] && has_dart=true
has_build=false; [ ${#dart[@]} -gt 0 ] || [ ${#native_only[@]} -gt 0 ] && has_build=true
printf 'dart=%s\nbuild=%s\n' "$has_dart" "$has_build"
