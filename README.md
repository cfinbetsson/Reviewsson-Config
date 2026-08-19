# Reviewsson-Config

Public repository that hosts the [Sparkle](https://sparkle-project.org) auto-update
feed for the **Reviewsson** macOS app. Only the appcast and release archives live
here — the app's source code stays in its own (private) repository.

Feed URL (wired into the app's `Info.plist` as `SUFeedURL`):

```
https://cfinbetsson.github.io/Reviewsson-Config/appcast.xml
```

## Layout

```
docs/
  appcast.xml        # generated update feed (served at the site root)
  index.html         # landing page (auto-links the latest release)
  appicon.png        # app icon used on the landing page
  releases/          # notarized app .dmg releases go here
assets/
  dmg-background.png # DMG window background (arrow -> Applications)
scripts/
  make-dmg-background.swift  # regenerates assets/dmg-background.png
  make-dmg.sh                # builds a styled drag-to-Applications DMG (optional notarize)
  package-release.sh         # make-dmg + publish in one step
  publish.sh                 # regenerates & signs docs/appcast.xml from docs/releases/
```

GitHub Pages serves the contents of `docs/` at the site root, so
`docs/appcast.xml` is reachable at `/appcast.xml` (no `docs` in the URL).

## One-time setup

1. Push this repo to `https://github.com/cfinbetsson/Reviewsson-Config` (must be **public** for free Pages).
2. In **Settings → Pages**, set **Source = Deploy from a branch**, then **Branch = `main` / `/docs`**.
3. Confirm the feed resolves: open `https://cfinbetsson.github.io/Reviewsson-Config/appcast.xml`.

## Publishing an update

1. Archive & export Reviewsson from Xcode (Direct Distribution notarizes & staples
   the app). Bump `CFBundleVersion` / `CFBundleShortVersionString` first.
2. Run the one-step release from this repo:

   ```
   ./scripts/package-release.sh <version> /path/to/Reviewsson.app
   ```

   This builds a styled drag-to-Applications `.dmg` into `docs/releases/`, signs it
   with your EdDSA key, and rewrites `docs/appcast.xml`.
3. Commit and push. GitHub Pages redeploys the feed and download page automatically.

### DMG options

- **Notarize the DMG** (recommended for a clean first-run): configure once with
  `xcrun notarytool store-credentials "Reviewsson-Notary" --apple-id <you> --team-id C799AMZVK8`.
  `make-dmg.sh` then notarizes + staples automatically. Skip with `SKIP_NOTARIZE=1`,
  or use a different profile via `NOTARY_PROFILE=<name>`.
- **DMG background**: edit `scripts/make-dmg-background.swift` and re-run it to
  regenerate `assets/dmg-background.png`; `make-dmg.sh` picks it up automatically.

## Security

- The **private** EdDSA key must never be committed here; it stays in your login
  keychain (or a CI secret). `.gitignore` blocks common key file names as a backstop.
- Only the **public** key is embedded in the app (`SUPublicEDKey`).
