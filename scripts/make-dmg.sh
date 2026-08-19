#!/bin/bash
set -euo pipefail

# Builds a styled "drag to Applications" DMG from a Reviewsson.app.
#
# Usage: ./scripts/make-dmg.sh <version> <path-to-Reviewsson.app> [output.dmg]
#   e.g. ./scripts/make-dmg.sh 1.0 ~/Desktop/Export/Reviewsson.app
#
# If assets/dmg-background.png exists it is used as the window background
# (a 640x400 @2x image with an arrow works best); otherwise create-dmg's
# default side-by-side layout is used.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <version> <path-to-Reviewsson.app> [output.dmg]" >&2
  exit 1
fi

VERSION="$1"
APP="$2"
OUT="${3:-$ROOT/docs/releases/Reviewsson-$VERSION.dmg}"

if [ ! -d "$APP" ]; then
  echo "error: app bundle not found: $APP" >&2
  exit 1
fi
if ! command -v create-dmg >/dev/null 2>&1; then
  echo "error: create-dmg not found. Install with: brew install create-dmg" >&2
  exit 1
fi

# create-dmg refuses to overwrite an existing image.
rm -f "$OUT"

# Stage a copy so the DMG source folder contains only the app.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/Reviewsson.app"

BG_ARGS=()
if [ -f "$ROOT/assets/dmg-background.png" ]; then
  BG_ARGS=(--background "$ROOT/assets/dmg-background.png")
fi

create-dmg \
  --volname "Reviewsson" \
  --window-pos 200 120 \
  --window-size 640 400 \
  --icon-size 128 \
  --icon "Reviewsson.app" 160 200 \
  --hide-extension "Reviewsson.app" \
  --app-drop-link 480 200 \
  ${BG_ARGS[@]+"${BG_ARGS[@]}"} \
  "$OUT" \
  "$STAGE"

echo "Wrote $OUT"

# Optional notarization of the DMG itself (the app inside is already notarized).
# Skipped with SKIP_NOTARIZE=1. Uses the keychain profile in NOTARY_PROFILE.
NOTARY_PROFILE="${NOTARY_PROFILE:-Reviewsson-Notary}"
if [ "${SKIP_NOTARIZE:-0}" = "1" ]; then
  echo "Skipping DMG notarization (SKIP_NOTARIZE=1)."
else
  echo "Notarizing DMG using keychain profile '$NOTARY_PROFILE'..."
  if xcrun notarytool submit "$OUT" --keychain-profile "$NOTARY_PROFILE" --wait; then
    xcrun stapler staple "$OUT"
    echo "DMG notarized and stapled."
  else
    echo "warning: notarization skipped/failed (no '$NOTARY_PROFILE' profile?)." >&2
    echo "         The app inside is already stapled, so it still runs; the DMG just" >&2
    echo "         isn't notarized. Configure once to enable it:" >&2
    echo "         xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <you> --team-id C799AMZVK8" >&2
  fi
fi
