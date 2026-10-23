#!/usr/bin/env bash
# Checks that this checkout raised `version:` in app/pubspec.yaml above a base
# commit, when it changed shipped code (CODING_STANDARDS.md §9).
#
#   check-version-bump.sh <base-sha>
#
# Exit 0: no shipped code changed, or the version was raised.
# Exit 1: shipped code changed and the name or build number did not rise.
# Used by version-bump.yml (the gate) and claude-version-bump.yml (the fixer),
# so the two can never disagree about what "raised" means.
set -euo pipefail

base_sha=${1:?usage: check-version-bump.sh <base-sha>}

# What ships: everything under app/, packages/ and modules/ except tests and
# docs. A change outside these (CI, docs, tooling) needs no version.
changed=$(git diff --name-only "$base_sha"...HEAD -- app packages modules \
  ':(exclude)**/test/**' ':(exclude)**/integration_test/**' ':(exclude)**/*.md')
if [ -z "$changed" ]; then
  echo "No shipped code changed; no version needed."
  exit 0
fi

read_version() { sed -n 's/^version: *\([0-9][0-9.]*+[0-9][0-9]*\).*/\1/p'; }
base=$(git show "$base_sha:app/pubspec.yaml" | read_version)
head=$(read_version < app/pubspec.yaml)
if [ -z "$base" ] || [ -z "$head" ]; then
  echo "::error::Cannot read version: base='$base' head='$head'"
  exit 1
fi
echo "Base $base → this change $head"

base_name=${base%+*}; base_build=${base#*+}
head_name=${head%+*}; head_build=${head#*+}

fail=0
# The name must rise: fix → PATCH, feature → MINOR, breaking → MAJOR.
if [ "$head_name" = "$base_name" ] || \
   [ "$(printf '%s\n%s\n' "$base_name" "$head_name" | sort -V | tail -1)" != "$head_name" ]; then
  echo "::error file=app/pubspec.yaml::Version name $head_name must be above $base_name (fix → PATCH, feature → MINOR, breaking → MAJOR)."
  fail=1
fi
# Stores reject a build number they have already seen.
if [ "$head_build" -le "$base_build" ]; then
  echo "::error file=app/pubspec.yaml::Build number +$head_build must be above +$base_build."
  fail=1
fi
if [ "$fail" = 1 ]; then
  echo "Changed shipped files:"; echo "$changed" | head -20
  echo "If another PR raised the version first, merge the base branch and raise it again."
  exit 1
fi
echo "Version raised."
