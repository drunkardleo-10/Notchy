# Changelog

Versions follow [Semantic Versioning](https://semver.org). The version lives in the `VERSION` file;
release tags are `v<version>`. To release: bump `VERSION`, add an entry here, commit, then
`git tag v<version>`, run `./package.sh` and attach the release artifacts.

## 1.0.2 — 2026-10-09

- Calendar redesigned with a month grid on the left and a day agenda with the next day on the right
- Larger calendar text, and the calendar returns to today every time the notch opens
- Settings button replaces the device icon on the idle "Not Playing" screen

## 1.0.1 — 2026-10-09

- Automatic updates via Sparkle and GitHub Releases, with a version row and "Check for Updates" in Settings
- Agents tab: installed AI agents detected automatically with usage rings and limits for Codex, Claude, Devin and OpenCode
- Album art dims and shrinks when paused, click it to open the playing app, and a song-title peek on hover and track change
- Redesigned idle "Not Playing" media screen
- Timer pill widens for times over 99 minutes

## 1.0.0 — 2026-10-09

First official major release.

- Dynamic Notch & Island overlay with hover-to-open, smooth spring animations, and multi-display support
- Dynamic Glass visual material system with custom glass tint, blur, and HUD styling
- Shelf with drag-and-drop file staging, floating basket controller, AirDrop, zip, and image conversion
- Clipboard Manager with thumbnail previews, favorites pinning, Vision OCR text extraction, and dissolve animations
- Real-time Audio Visualizer and Media Controller for Apple Music, Spotify, and browser media tabs with seek, shuffle, repeat, and lyrics support
- System HUD overlays replacing native macOS HUDs for volume, display brightness, keyboard backlight, lock screen, and Bluetooth/AirPods battery status
- Pomodoro timer with duration ruler, phase indicator, and high alert notifications
- Calendar integration with upcoming events timeline, week strip, and one-click meeting launcher
- Live Claude Code AI background task monitor
- Quick camera mirror dropdown for pre-meeting video checks
- Settings panel with per-module customization, hotkeys, and appearance controls
