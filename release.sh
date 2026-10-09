#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -s SPARKLE_PUBLIC_KEY ]; then
  echo "SPARKLE_PUBLIC_KEY is missing. Run: .build/artifacts/sparkle/Sparkle/bin/generate_keys" >&2
  exit 1
fi

./package.sh

VERSION=$(tr -d '[:space:]' < VERSION)
TAG="v$VERSION"
STAGE=build/release
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "build/notchy-$VERSION.zip" "$STAGE/"

.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
  --download-url-prefix "https://github.com/drunkardleo-10/Notchy/releases/download/$TAG/" \
  "$STAGE"

echo
echo "Ready. Publish with:"
echo "  git tag $TAG && git push origin $TAG"
echo "  gh release create $TAG build/Notchy-$VERSION.dmg $STAGE/notchy-$VERSION.zip $STAGE/appcast.xml --title \"Notchy $VERSION\" --notes-file CHANGELOG.md"
