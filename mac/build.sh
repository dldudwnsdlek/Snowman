#!/bin/bash
# Builds Snowman.app next to this script.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product Snowman
swift build -c release --product ArtPreview

APP="Snowman.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Snowman "$APP/Contents/MacOS/Snowman"
cp Resources/Info.plist "$APP/Contents/Info.plist"

ICONSET=".build/AppIcon.iconset"
rm -rf "$ICONSET"
.build/release/ArtPreview --iconset "$ICONSET" > /dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"
echo "Built $(pwd)/$APP"
