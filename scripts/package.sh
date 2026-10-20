#!/bin/bash
# Packaging: builds Hidebar in Release and wraps it in build/Hidebar.dmg.
#
# The app is signed ad hoc, which is enough to run it on the machine that built it. A copy
# downloaded from the internet needs Developer ID signing and notarization; see the commands
# at the end of this file.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

build="$root/build"
derived="$build/dd"
stage="$build/dmg-stage"
app="$derived/Build/Products/Release/Hidebar.app"
dmg="$build/Hidebar.dmg"

rm -rf "$stage" "$dmg"
mkdir -p "$stage"

xcodebuild -project Hidebar.xcodeproj -scheme Hidebar -configuration Release \
    -derivedDataPath "$derived" build >&2

if [ ! -d "$app" ]; then
    echo "package: $app was not produced" >&2
    exit 1
fi
codesign --verify --deep --strict "$app"

cp -R "$app" "$stage/Hidebar.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Hidebar -srcfolder "$stage" -ov -format UDZO "$dmg" >&2
rm -rf "$stage"

echo "package: $dmg"
cat >&2 <<'NOTE'

NOTE: this build is signed ad hoc. macOS Gatekeeper will refuse it on other machines, and
its Accessibility and Screen Recording grants do not survive an update. To distribute it,
sign with a Developer ID certificate and notarize (an Apple Developer account is required).
NOTE

# Distribution, run by hand with your own identity and notarytool keychain profile:
#
#   codesign --force --deep --options runtime --timestamp \
#       --sign "Developer ID Application: <NAME> (<TEAM_ID>)" \
#       build/dd/Build/Products/Release/Hidebar.app
#   (rebuild the DMG from the signed app, then:)
#   codesign --force --timestamp \
#       --sign "Developer ID Application: <NAME> (<TEAM_ID>)" build/Hidebar.dmg
#   xcrun notarytool submit build/Hidebar.dmg --keychain-profile "<PROFILE>" --wait
#   xcrun stapler staple build/Hidebar.dmg
#   spctl --assess --type open --context context:primary-signature -v build/Hidebar.dmg
