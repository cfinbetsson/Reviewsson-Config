#!/bin/bash
set -euo pipefail

# Regenerates docs/appcast.xml from the .zip releases in docs/releases/.
#
# The EdDSA private key is read automatically from your login keychain (the one
# `generate_keys` created). It must NEVER be committed to this repo.

BASE_URL="https://cfinbetsson.github.io/Reviewsson-Config"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v generate_appcast >/dev/null 2>&1; then
  echo "error: generate_appcast not found in PATH." >&2
  echo "Install Sparkle's tools (brew install --cask sparkle) or add its bin/ to PATH." >&2
  exit 1
fi

generate_appcast \
  --download-url-prefix "${BASE_URL}/releases/" \
  -o "${ROOT}/docs/appcast.xml" \
  "${ROOT}/docs/releases"

echo "Wrote ${ROOT}/docs/appcast.xml"
echo "Next: git add docs && git commit -m 'Publish update' && git push"
