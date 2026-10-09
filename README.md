# Notchy

A fluid, contextual Dynamic Notch and Island utility for macOS.

Notchy turns the MacBook notch—and external displays—into an interactive command center. Built with SwiftUI and native AppKit APIs, Notchy floats seamlessly atop your desktop, full-screen applications, and lock screen.

---

## Features

### Dynamic Notch and Island
- **Hardware Integration**: Conforms to the physical MacBook notch or displays an adaptive floating pill on notch-less Macs and external monitors.
- **Fluid Mechanics**: Responsive hover-to-expand behavior with spring-damped physics.
- **Module Navigation**: Quickly switch between active modules using the integrated navigation pill.
- **Dynamic Glass Styling**: Native frosted glassmorphism with customizable blur, opacity, tint, and border styling.

### Media Controller and Audio Visualizer
- **Playback Control**: Integrates with Apple Music, Spotify, and major web browsers (Chrome, Safari, Arc, Brave, Edge).
- **Real-Time FFT Visualizer**: Hardware-accelerated audio spectrum visualization conforming to the notch curve.
- **Extended Controls**: Scrubbable seek bar, shuffle, repeat, track navigation, and synchronized lyrics support.
- **Live Activity**: Collapsed status indicator displaying current track details and audio metering.

### Shelf and Floating Basket
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

### Focus and Productivity
- **Pomodoro Timer**: Duration ruler selector, phase glyphs, and focus/break interval tracking.
- **High Alert**: Full-screen flash mode for urgent deadlines and reminders.
- **Emoji Picker**: Searchable emoji selection tray.

### Calendar and Meetings
- **Agenda View**: Upcoming schedule timeline with an interactive week strip.
- **One-Click Launch**: Direct join actions for Google Meet, Zoom, Microsoft Teams, and Webex calls.

### System and Agent Monitoring
- **Claude Code Monitor**: Live tracking and status updates for local Claude Code agent processes.
- **Hardware Telemetry**: Compact real-time readings for CPU, GPU, memory, disk activity, and network throughput.
- **Camera Mirror**: Instant dropdown camera preview beneath the notch for quick pre-meeting checks.

---

## Installation

### Download DMG (Recommended)

1. Download `Notchy-1.0.0.dmg` from the [Releases](https://github.com/drunkardleo-10/Notchy/releases) page.
2. Open the disk image and drag **Notchy** into your `/Applications` directory.
3. Launch **Notchy** from Applications or Spotlight.

> [!NOTE]
> As Notchy is ad-hoc signed, macOS Gatekeeper may prompt you on initial launch. Right-click the application in `/Applications` and select **Open**, or run the following command in Terminal:
> ```sh
> xattr -cr /Applications/Notchy.app
> ```

---

## Building from Source

### Requirements
- macOS 14.0 (Sonoma) or newer
- Xcode 15 or newer with Swift 5.9+

### Build Instructions

```sh
# Clone repository
git clone https://github.com/drunkardleo-10/Notchy.git
cd Notchy

# Run in development mode
swift run

# Build the release app bundle
./build.sh
open build/notchy.app

# Package universal binary DMG and ZIP
./package.sh
```

---

## Permissions and Privacy

All processing in Notchy occurs entirely on-device:
- **Audio Capture**: Reads local system audio loopback strictly for real-time FFT visualization. No audio data is recorded, persisted, or transmitted.
- **Calendar**: Accesses local Calendar events to display upcoming meetings and meeting links.
- **Camera**: Connects to the local FaceTime HD or Continuity camera exclusively for the live mirror view.
- **Accessibility and Automation**: Controls media playback in supported applications and monitors media keys.

---

## License

Released under the MIT License.
