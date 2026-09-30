#!/bin/bash
set -euo pipefail

osascript -e 'tell application "Finder" to close every window' 2>/dev/null || true

cd "$(dirname "$0")"

APP="./build/NetworkToggle.app"

if [ ! -d "$APP" ]; then
  echo "$APP is not found" >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
OUTPUT="NetworkToggle-${VERSION}.dmg"

rm -f "$OUTPUT"

create-dmg \
  --volname "Network Toggle App" \
  --background "./background.png" \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "NetworkToggle.app" 150 150 \
  --app-drop-link 450 150 \
  --hide-extension "NetworkToggle.app" \
  "$OUTPUT" \
  "$APP"

echo "Done: $OUTPUT"
open ./
osascript -e 'tell application "Terminal" to quit' &
exit
