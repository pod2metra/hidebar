#!/bin/bash
# Builds the Debug app at one fixed path, signed with the local identity from
# scripts/dev_cert.sh, quits a running copy and launches the new one. One path and
# one signature mean macOS keeps the granted permissions across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${HIDEBAR_SIGN_IDENTITY:-Hidebar Local Signing}"
APP="build/dd/Build/Products/Debug/Hidebar.app"

if ! security find-identity -v -p codesigning | grep -qF "\"$NAME\""; then
    echo "No signing identity \"$NAME\". Run scripts/dev_cert.sh once first." >&2
    exit 1
fi

xcodebuild -project Hidebar.xcodeproj -scheme Hidebar -configuration Debug \
    -derivedDataPath build/dd -quiet \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$NAME" DEVELOPMENT_TEAM= \
    ENABLE_HARDENED_RUNTIME=NO build
# The hardened runtime's library validation rejects Hidebar.debug.dylib: a self-signed
# identity has no Team ID. Ad-hoc builds run without the hardened runtime as well.

# Any other copy (for example one built by Xcode into DerivedData) would hold a
# different signature and look ungranted.
pkill -x Hidebar || true
open "$APP"
codesign -dr - "$APP" 2>&1 | grep designated
