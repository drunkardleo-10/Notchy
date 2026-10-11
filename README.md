<div align="center">
  <img src="logo/notchy-mascot.png" width="128" height="128" alt="Notchy logo" />
  <h1>Notchy</h1>

  <p><strong>A fluid, contextual Dynamic Notch and Island utility for macOS.</strong></p>

  <p>
    <a href="#features">Features</a>
    ·
    <a href="#install">Install</a>
    ·
    <a href="#build-from-source">Build from Source</a>
    ·
    <a href="#tech-stack">Tech Stack</a>
    ·
    <a href="#permissions-and-privacy">Permissions & Privacy</a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-000000?style=flat&logo=apple&logoColor=white" alt="Platform: macOS 14+" />
    <img src="https://img.shields.io/badge/Swift-5.9%2B-FA7343?style=flat&logo=swift&logoColor=white" alt="Swift 5.9+" />
    <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-007AFF?style=flat" alt="SwiftUI + AppKit" />
    <img src="https://img.shields.io/badge/License-MIT-green?style=flat" alt="MIT License" />
    <img src="https://img.shields.io/badge/Telemetry-Zero-lightgrey?style=flat" alt="No Telemetry" />
  </p>
</div>

---

**Notchy** turns the MacBook notch—and external displays—into an interactive command center. Built natively for macOS using SwiftUI and AppKit APIs, Notchy floats seamlessly atop your desktop, full-screen applications, and lock screen with spring physics, hardware telemetry, media playback, dynamic HUDs, and agent monitoring.

No accounts. No telemetry. No background bloat. Just fluid, native macOS notch magic.

---

## Features

### Dynamic Notch & Island
- **Hardware Integration**: Conforms to the physical MacBook notch or displays an adaptive floating pill on notch-less Macs and external monitors.
- **Fluid Mechanics**: Responsive hover-to-expand behavior with spring-damped physics.
- **Module Navigation**: Quickly switch between active modules using the integrated navigation pill.
- **Dynamic Glass Styling**: Native frosted glassmorphism with customizable blur, opacity, tint, and border styling.

### Media Controller & Audio Visualizer
- **Playback Control**: Integrates with Apple Music, Spotify, and major web browsers (Chrome, Safari, Arc, Brave, Edge).
- **Real-Time FFT Visualizer**: Hardware-accelerated audio spectrum visualization conforming to the notch curve.
- **Extended Controls**: Scrubbable seek bar, shuffle, repeat, track navigation, and synchronized lyrics support.
- **Live Activity**: Collapsed status indicator displaying current track details and audio metering.

### Shelf & Detachable Basket
- **Quick File Staging**: Drag files, photos, links, or text directly into the notch to stash them temporarily.
- **Detachable Basket**: Detach the shelf into a floating desktop basket that stays accessible across macOS Spaces.
- **Batch Actions**: Quick AirDrop dispatch, zip archiving, and image format conversion.

### Clipboard Manager
- **Visual Card History**: Card-based history for text, colors, rich text, and copied images.
- **Search and Pinning**: Instant keyword filtering and favorites pinning.
- **Vision OCR**: Built-in optical character recognition to extract text directly from copied images.
- **Dissolve Transitions**: Particle dissolve animations when clearing or deleting clips.

### System HUD Overlays
Replaces standard macOS system overlays with compact notch HUDs:
- Volume and Mute
- Display Brightness
- Keyboard Backlight
- Bluetooth and AirPods connection alerts with battery percentages
- Lock, Unlock, and Caps Lock status indicators

### Focus & Productivity
- **Pomodoro Timer**: Duration ruler selector, phase glyphs, and focus/break interval tracking.
- **High Alert**: Full-screen flash mode for urgent deadlines and reminders.
- **Emoji Picker**: Searchable emoji selection tray.

### Calendar & Meetings
- **Agenda View**: Upcoming schedule timeline with an interactive week strip.
- **One-Click Launch**: Direct join actions for Google Meet, Zoom, Microsoft Teams, and Webex calls.

### System & Agent Monitoring
- **AI Agent Monitoring**: Live tracking and status updates for local coding agents (Claude Code, OpenCode, Devin, Antigravity).
- **Hardware Telemetry**: Compact real-time readings for CPU, GPU, memory, disk activity, and network throughput.
- **Camera Mirror**: Instant dropdown camera preview beneath the notch for quick pre-meeting checks.

---

## Install

### Download Pre-Built DMG

1. Download the latest version from the [Releases](https://github.com/drunkardleo-10/Notchy/releases) page.
2. Open the disk image and drag **Notchy** into your `/Applications` directory.
3. Launch **Notchy** from Applications or Spotlight.

> [!NOTE]
> As Notchy is ad-hoc signed, macOS Gatekeeper may prompt you on initial launch. Right-click the application in `/Applications` and select **Open**, or run the following command in Terminal:
> ```sh
> xattr -cr /Applications/Notchy.app
> ```

### Requirements
- **macOS Sonoma (14.0)** or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac

---

## Build from Source

### Prerequisites
- macOS 14.0+
- Xcode 15.0+ with Swift 5.9+ or Command Line Tools

### 1. Clone the repository
```bash
git clone https://github.com/drunkardleo-10/Notchy.git
cd Notchy
```

### 2. Run in Development Mode
```bash
swift run
```

### 3. Build Release Application Bundle
```bash
./build.sh
open build/notchy.app
```

### 4. Package Universal Binary DMG
```bash
./package.sh
```
The resulting `Notchy.dmg` will be created in the `build/` directory.

---

## Tech Stack

| Component | Technology |
|---|---|
| **App Framework** | Swift 5.9+, SwiftUI, AppKit |
| **Window & Layer Management** | CoreGraphics, Private CGS Spaces APIs, NSPanel |
| **Audio & Visualizer** | Accelerate (vDSP FFT), CoreAudio, ScriptingBridge / AppleScript |
| **System Telemetry** | IOKit, libsystem, host_statistics, Mach APIs |
| **Vision & OCR** | Apple Vision Framework |
| **Updates** | Sparkle 2 |
| **Styling & Assets** | SF Symbols, Custom Vector Glyphs, Canvas-rendered glassmorphism |

---

## Permissions and Privacy

All processing in Notchy occurs entirely on-device:
- **Audio Capture**: Reads local system audio loopback strictly for real-time FFT visualization. No audio data is recorded, persisted, or transmitted.
- **Calendar**: Accesses local Calendar events to display upcoming meetings and meeting links.
- **Camera**: Connects to the local FaceTime HD or Continuity camera exclusively for the live mirror view.
- **Accessibility and Automation**: Controls media playback in supported applications and monitors media keys.

---

## Contributing

Contributions, bug reports, and suggestions are welcome!
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes thoroughly
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

---

## License

This project is licensed under the MIT License.
