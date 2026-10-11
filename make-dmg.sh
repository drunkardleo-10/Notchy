#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="${1:?usage: make-dmg.sh <app> <out.dmg>}"
OUT="${2:?usage: make-dmg.sh <app> <out.dmg>}"
VOLNAME="Notchy"
WORK=$(mktemp -d)
RW="$WORK/rw.dmg"

swiftc -O dmg-background.swift -o "$WORK/dmg-background"
"$WORK/dmg-background" "$WORK/background.png"

hdiutil detach "/Volumes/$VOLNAME" -force >/dev/null 2>&1 || true
hdiutil create -size 64m -fs HFS+ -volname "$VOLNAME" -ov "$RW" >/dev/null
hdiutil attach "$RW" -readwrite -noverify -noautoopen -mountpoint "/Volumes/$VOLNAME" >/dev/null

cp -R "$APP" "/Volumes/$VOLNAME/Notchy.app"
ln -s /Applications "/Volumes/$VOLNAME/Applications"
mkdir "/Volumes/$VOLNAME/.background"
cp "$WORK/background.png" "/Volumes/$VOLNAME/.background/background.png"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLNAME"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 568}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.png"
    set position of item "Notchy.app" of container window to {190, 215}
    set position of item "Applications" of container window to {470, 215}
    set the bounds of container window to {200, 120, 860, 568}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
chmod -Rf go-w "/Volumes/$VOLNAME" || true
hdiutil detach "/Volumes/$VOLNAME" >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -rf "$WORK"
