#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

TARGET=14.0
for arch in arm64 x86_64; do
  echo "==> Building $arch"
  swift build -c release --triple "$arch-apple-macosx$TARGET"
done

mkdir -p build
lipo -create \
  ".build/arm64-apple-macosx/release/notchy" \
  ".build/x86_64-apple-macosx/release/notchy" \
  -output build/notchy-universal
lipo -info build/notchy-universal

BIN=build/notchy-universal ./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/notchy.app/Contents/Info.plist)
ZIP="build/notchy-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent build/notchy.app "$ZIP"
echo
echo "Created $ZIP"
shasum -a 256 "$ZIP"
