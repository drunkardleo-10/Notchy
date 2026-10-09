#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(tr -d '[:space:]' < VERSION)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)

if [ -z "${BIN:-}" ]; then
  swift build -c release
  BIN=.build/release/notchy
fi
APP=build/notchy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/notchy"

SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/notchy" 2>/dev/null || true

SPARKLE_KEYS=""
if [ -s SPARKLE_PUBLIC_KEY ]; then
  SPARKLE_KEYS="<key>SUFeedURL</key><string>https://github.com/drunkardleo-10/Notchy/releases/latest/download/appcast.xml</string>
  <key>SUPublicEDKey</key><string>$(tr -d '[:space:]' < SPARKLE_PUBLIC_KEY)</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SUScheduledCheckInterval</key><integer>86400</integer>"
else
  echo "warning: SPARKLE_PUBLIC_KEY missing, auto-update disabled in this build"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>notchy</string>
  <key>CFBundleIdentifier</key><string>com.rithvik.notchy</string>
  <key>CFBundleExecutable</key><string>notchy</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  $SPARKLE_KEYS
  <key>NSCalendarsFullAccessUsageDescription</key><string>notchy shows your upcoming events and meeting links in the notch.</string>
  <key>NSCalendarsUsageDescription</key><string>notchy shows your upcoming events and meeting links in the notch.</string>
  <key>NSCameraUsageDescription</key><string>notchy can show a quick camera mirror in the notch.</string>
  <key>NSBluetoothAlwaysUsageDescription</key><string>notchy shows a HUD when AirPods and other Bluetooth audio devices connect.</string>
  <key>NSAudioCaptureUsageDescription</key><string>notchy analyzes audio from the current media app to draw a real-time visualizer. Audio is processed locally and never leaves your Mac.</string>
  <key>NSAppleEventsUsageDescription</key><string>notchy reads the current track from Music and Spotify and controls playback.</string>
</dict></plist>
PLIST

SPARKLE_B="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for item in "$SPARKLE_B"/XPCServices/*.xpc "$SPARKLE_B/Updater.app" "$SPARKLE_B/Autoupdate"; do
  [ -e "$item" ] && codesign --force --sign - "$item"
done
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP"
echo "Built $APP — run: open $APP"
