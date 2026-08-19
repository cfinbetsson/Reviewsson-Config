#!/bin/bash
set -euo pipefail

# Regenerates docs/appcast.xml from the .zip releases in docs/releases/ and
# guarantees every enclosure is signed.
#
# generate_appcast builds the feed structure (versions, lengths, deltas, min OS),
# but in some environments it silently omits sparkle:edSignature. We therefore
# sign each archive explicitly with sign_update and inject any missing signature.
#
# The EdDSA private key is read from your login keychain (created by generate_keys)
# and must NEVER be committed to this repo.

BASE_URL="https://cfinbetsson.github.io/Reviewsson-Config"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASES="$ROOT/docs/releases"
APPCAST="$ROOT/docs/appcast.xml"

# Locate a Sparkle tool: prefer PATH, else the Homebrew cask's bin.
find_tool() {
  local name="$1" p
  p="$(command -v "$name" || true)"
  if [ -z "$p" ] && command -v brew >/dev/null 2>&1; then
    p="$(ls "$(brew --prefix)/Caskroom/sparkle/"*/bin/"$name" 2>/dev/null | sort -V | tail -1 || true)"
  fi
  if [ -n "$p" ] && [ -x "$p" ]; then echo "$p"; return 0; fi
  return 1
}

GENERATE_APPCAST="$(find_tool generate_appcast)" || {
  echo "error: generate_appcast not found. Install with: brew install --cask sparkle" >&2; exit 1; }
SIGN_UPDATE="$(find_tool sign_update)" || {
  echo "error: sign_update not found. Install with: brew install --cask sparkle" >&2; exit 1; }

"$GENERATE_APPCAST" \
  --download-url-prefix "${BASE_URL}/releases/" \
  -o "$APPCAST" \
  "$RELEASES"

# Sign every enclosure that generate_appcast left unsigned.
python3 - "$APPCAST" "$RELEASES" "$SIGN_UPDATE" <<'PY'
import os, re, subprocess, sys

appcast, releases, sign_update = sys.argv[1:4]
with open(appcast, encoding="utf-8") as f:
    xml = f.read()

def signature_for(zip_path):
    out = subprocess.run([sign_update, zip_path], capture_output=True, text=True, check=True).stdout
    m = re.search(r'sparkle:edSignature="([^"]+)"', out)
    if not m:
        sys.exit(f"error: sign_update produced no signature for {zip_path}")
    return m.group(1)

def fix(match):
    tag = match.group(0)
    if "edSignature" in tag:
        return tag
    url = re.search(r'url="([^"]+)"', tag).group(1)
    zip_path = os.path.join(releases, os.path.basename(url))
    if not os.path.isfile(zip_path):
        return tag
    sig = signature_for(zip_path)
    return tag[:-2].rstrip() + f' sparkle:edSignature="{sig}"/>'

xml = re.sub(r'<enclosure\b[^>]*/>', fix, xml)
with open(appcast, "w", encoding="utf-8") as f:
    f.write(xml)

count = xml.count("edSignature")
print(f"signed enclosures in appcast: {count}")
if count == 0:
    sys.exit("error: no signatures were written")
PY

echo "Wrote $APPCAST"
echo "Next: git add docs && git commit -m 'Publish update' && git push"
