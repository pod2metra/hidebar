#!/bin/bash
# Renders docs/brand/logo.svg into the macOS app icon set (10 PNGs, 16 to 1024 px).
# Contents.json next to the PNGs is checked in; this script only rewrites the images.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

svg="docs/brand/logo.svg"
iconset="App/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$iconset"

swift scripts/render_svg.swift "$svg" \
    "16=$iconset/icon_16x16.png" \
    "32=$iconset/icon_16x16@2x.png" \
    "32=$iconset/icon_32x32.png" \
    "64=$iconset/icon_32x32@2x.png" \
    "128=$iconset/icon_128x128.png" \
    "256=$iconset/icon_128x128@2x.png" \
    "256=$iconset/icon_256x256.png" \
    "512=$iconset/icon_256x256@2x.png" \
    "512=$iconset/icon_512x512.png" \
    "1024=$iconset/icon_512x512@2x.png"
