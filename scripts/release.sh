#!/usr/bin/env bash
# Builds a universal Upright.app, zips it, and publishes a GitHub release.
# Usage: scripts/release.sh 0.2.0 ["Release notes"]
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version> [notes]}"
NOTES="${2:-Upright $VERSION}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

[[ -z "$(git status --porcelain)" ]] || { echo "Commit or stash your changes first." >&2; exit 1; }

UNIVERSAL=1 VERSION="$VERSION" scripts/bundle.sh release
rm -f build/Upright.zip
ditto -c -k --keepParent build/Upright.app build/Upright.zip
echo "Built build/Upright.zip ($(du -h build/Upright.zip | cut -f1))"

gh release create "v$VERSION" build/Upright.zip --title "Upright $VERSION" --notes "$NOTES"
