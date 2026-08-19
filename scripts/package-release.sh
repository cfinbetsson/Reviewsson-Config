#!/bin/bash
set -euo pipefail

# Packages a notarized + stapled Reviewsson.app into docs/releases/ and regenerates
# the signed appcast. Run this AFTER Xcode's Direct Distribution has exported the app.
#
# Usage: ./scripts/package-release.sh <version> <path-to-Reviewsson.app>
#   e.g. ./scripts/package-release.sh 1.0 ~/Desktop/Export/Reviewsson.app

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <version> <path-to-Reviewsson.app>" >&2
  exit 1
fi

VERSION="$1"
APP_PATH="$2"

if [ ! -d "$APP_PATH" ]; then
  echo "error: app bundle not found: $APP_PATH" >&2
  exit 1
fi

DEST="$ROOT/docs/releases/Reviewsson-$VERSION.dmg"
echo "Building DMG -> $DEST"
# make-dmg.sh notarizes & staples the DMG (unless SKIP_NOTARIZE=1), which covers
# the app inside, so the app itself does not need to be pre-stapled.
"$ROOT/scripts/make-dmg.sh" "$VERSION" "$APP_PATH" "$DEST"

echo "Regenerating appcast..."
"$ROOT/scripts/publish.sh"

echo
echo "Done. Review, then publish:"
echo "  cd \"$ROOT\" && git add docs && git commit -m \"Release $VERSION\" && git push"
