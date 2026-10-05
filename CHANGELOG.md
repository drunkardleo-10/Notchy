# Changelog

Versions follow [Semantic Versioning](https://semver.org). The version lives in the `VERSION` file;
release tags are `v<version>`. To release: bump `VERSION`, add an entry here, commit, then
`git tag v<version>`, run `./package.sh` and attach the zip to the release.

## Unreleased

- Internal restructure: sources grouped into App, Notch, Features, System and Settings folders; no user-facing changes

## 0.1.0 — 2026-10-03

First release.

- Notch overlay with hover-to-open; Dynamic Island pill on Macs without a notch
- Shelf (drag in/out, AirDrop, zip, image conversion) and floating basket
- Clipboard manager with search, favorites and OCR
- Media from Music, Spotify and browser tabs, with seek, shuffle, repeat and a collapsed-notch live activity
- HUDs: volume, brightness, AirPods, battery, Caps Lock, lock/unlock
- Pomodoro timer, High Alert, emoji picker
- Calendar with meeting links, Claude Code status, Shortcuts launcher, system monitor, camera mirror
- Settings with per-feature toggles
