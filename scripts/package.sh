#!/bin/bash
# Packaging: builds Hidebar in Release and wraps it in a DMG.
#
#   bash scripts/package.sh              ad-hoc build for this machine: build/Hidebar.dmg
#   bash scripts/package.sh release-app  build of Hidebar.app signed with the release certificate
#   bash scripts/package.sh release-dmg  build/Hidebar-$VERSION.dmg from that app
#
# The default build is signed ad hoc, which is enough to run it on the machine that built it.
# The release phases sign with the persistent self-signed certificate from scripts/release_cert.sh,
# with the hardened runtime but no notarization: every version then has the same designated requirement,
# so the Accessibility grant survives updates. .github/workflows/release.yml runs both phases.
#
# The release phases are driven by the environment:
#   SIGN_IDENTITY  codesign identity (name or SHA-1 hash) of that certificate, reachable from
#                  the keychain search list; a self-signed one is not "valid", so pass the hash
#   VERSION        marketing version, MAJOR.MINOR.PATCH
#   BUILD_NUMBER   build number (CFBundleVersion), digits only; release-app only
set -euo pipefail

mode="${1:-adhoc}"

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

build="$root/build"
derived="$build/dd"
stage="$build/dmg-stage"
app="$derived/Build/Products/Release/Hidebar.app"
dmg="$build/Hidebar.dmg"
settings=()

case "$mode" in
adhoc) ;;
release-app | release-dmg)
    : "${SIGN_IDENTITY:?package: $mode needs SIGN_IDENTITY}"
    : "${VERSION:?package: $mode needs VERSION}"
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "package: VERSION must be MAJOR.MINOR.PATCH, got '$VERSION'" >&2
        exit 1
    fi
    dmg="$build/Hidebar-$VERSION.dmg"
    ;;
*)
    echo "usage: package.sh [release-app | release-dmg]" >&2
    exit 2
    ;;
esac

if [ "$mode" != release-dmg ]; then
    if [ "$mode" = release-app ]; then
        : "${BUILD_NUMBER:?package: release-app needs BUILD_NUMBER}"
        if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
            echo "package: BUILD_NUMBER must be digits only, got '$BUILD_NUMBER'" >&2
            exit 1
        fi
        # The project does not name the app icon set yet; pass it so the released app has its icon.
        settings=("MARKETING_VERSION=$VERSION" "CURRENT_PROJECT_VERSION=$BUILD_NUMBER"
            "ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon")
    fi
    xcodebuild -project Hidebar.xcodeproj -scheme Hidebar -configuration Release \
        -derivedDataPath "$derived" build ${settings[@]+"${settings[@]}"} >&2
fi

if [ ! -d "$app" ]; then
    echo "package: $app was not produced" >&2
    exit 1
fi

if [ "$mode" = release-app ]; then
    # Re-sign the ad-hoc build. The hardened runtime stays on (--force would drop it otherwise):
    # it makes the app ignore DYLD_INSERT_LIBRARIES, which would inherit its Accessibility grant.
    codesign --force --options runtime --timestamp=none \
        --entitlements "$root/App/Hidebar.entitlements" \
        --sign "$SIGN_IDENTITY" "$app" >&2
    details="$(codesign -dv "$app" 2>&1)"
    if [[ "$details" != *flags=*runtime* ]]; then
        echo "package: $app is missing the hardened runtime flag" >&2
        exit 1
    fi
    built="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
    if [ "$built" != "$VERSION" ]; then
        echo "package: app reports version '$built', expected '$VERSION'" >&2
        exit 1
    fi
fi
codesign --verify --deep --strict "$app"

if [ "$mode" = release-app ]; then
    echo "package: $app"
    exit 0
fi

rm -rf "$stage" "$dmg"
mkdir -p "$stage"
cp -R "$app" "$stage/Hidebar.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Hidebar -srcfolder "$stage" -ov -format UDZO "$dmg" >&2
rm -rf "$stage"

if [ "$mode" = release-dmg ]; then
    codesign --force --timestamp=none --sign "$SIGN_IDENTITY" "$dmg" >&2
    codesign --verify --strict "$dmg"
fi

echo "package: $dmg"
if [ "$mode" = adhoc ]; then
    cat >&2 <<'NOTE'

NOTE: this build is signed ad hoc. macOS Gatekeeper will refuse it on other machines, and
its Accessibility grant does not survive an update. To distribute it,
use the release-app and release-dmg phases with the release certificate; see docs/RELEASING.md.
NOTE
fi
