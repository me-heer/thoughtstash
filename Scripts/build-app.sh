#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
APP="$ROOT/dist/Thought Stash.app"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/.build/release/ThoughtStash" "$CONTENTS/MacOS/ThoughtStash"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ { print $2; exit }')
if [ -n "$IDENTITY" ]; then
    codesign --force --deep --sign "$IDENTITY" --timestamp=none "$APP"
else
    codesign --force --deep --sign - "$APP"
fi

echo "Built $APP"
