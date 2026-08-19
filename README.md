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
  index.html         # simple landing page
  releases/          # notarized app .zip archives go here
scripts/
  publish.sh         # regenerates docs/appcast.xml from docs/releases/
```

GitHub Pages serves the contents of `docs/` at the site root, so
`docs/appcast.xml` is reachable at `/appcast.xml` (no `docs` in the URL).

## One-time setup

1. Push this repo to `https://github.com/cfinbetsson/Reviewsson-Config` (must be **public** for free Pages).
2. In **Settings → Pages**, set **Source = Deploy from a branch**, then **Branch = `main` / `/docs`**.
3. Confirm the feed resolves: open `https://cfinbetsson.github.io/Reviewsson-Config/appcast.xml`.

## Publishing an update

1. Archive & notarize Reviewsson, then export the app and zip it (bump
   `CFBundleVersion` / `CFBundleShortVersionString` first).
2. Copy the `.zip` into `docs/releases/`.
3. Run `./scripts/publish.sh` — this signs each archive with your EdDSA private
   key (read from the login keychain) and rewrites `docs/appcast.xml`.
4. Commit and push. GitHub Pages redeploys the feed automatically.

## Security

- The **private** EdDSA key must never be committed here; it stays in your login
  keychain (or a CI secret). `.gitignore` blocks common key file names as a backstop.
- Only the **public** key is embedded in the app (`SUPublicEDKey`).
