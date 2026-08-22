#!/bin/sh
# Renders Icon/AppIcon.svg into Resources/AppIcon.icns.
#
# Only needs running when the icon artwork changes; the generated .icns is
# checked in so a plain build-app.sh does not depend on librsvg.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SVG="$ROOT/Icon/AppIcon.svg"
ICNS="$ROOT/Resources/AppIcon.icns"

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "rsvg-convert not found. Install it with: brew install librsvg" >&2
    exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"

# iconutil expects exactly these names; each size is rendered from the vector
# rather than downsampled, so the hairline card edges stay crisp.
render() {
    rsvg-convert --width "$1" --height "$1" --output "$SET/$2" "$SVG"
}

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil --convert icns --output "$ICNS" "$SET"
echo "Wrote $ICNS"
