#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/notchy

lipo -info "$BIN"

BIN="$BIN" ./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/notchy.app/Contents/Info.plist)
ZIP="build/notchy-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent build/notchy.app "$ZIP"
echo "Created $ZIP"
shasum -a 256 "$ZIP"

DMG="build/Notchy-$VERSION.dmg"
DMG_LATEST="build/Notchy.dmg"
rm -f "$DMG" "$DMG_LATEST"

DMG_STAGE=$(mktemp -d)
cp -R build/notchy.app "$DMG_STAGE/Notchy.app"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "Notchy" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG"
rm -rf "$DMG_STAGE"
cp "$DMG" "$DMG_LATEST"

echo "Created $DMG"
shasum -a 256 "$DMG"
