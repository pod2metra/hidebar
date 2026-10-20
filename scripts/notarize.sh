#!/bin/bash
# Notarizes a .app (zipped first) or a .dmg with notarytool, requires the verdict "Accepted",
# then staples the ticket to the given path.
#
#   bash scripts/notarize.sh <path-to-.app-or-.dmg>
#
# Credentials come from the environment (App Store Connect API key):
#   NOTARY_KEY_ID, NOTARY_ISSUER_ID, NOTARY_KEY_P8 (the text of the .p8 file)
# The key is written to a private temporary file that is removed on exit.
set -euo pipefail

target="${1:?usage: notarize.sh <path-to-.app-or-.dmg>}"
: "${NOTARY_KEY_ID:?notarize: NOTARY_KEY_ID is not set}"
: "${NOTARY_ISSUER_ID:?notarize: NOTARY_ISSUER_ID is not set}"
: "${NOTARY_KEY_P8:?notarize: NOTARY_KEY_P8 is not set}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
key="$work/key.p8"
log="$work/submit.log"
(umask 077; printf '%s' "$NOTARY_KEY_P8" > "$key")
auth=(--key "$key" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")

upload="$target"
if [ -d "$target" ]; then
    upload="$work/$(basename "$target" .app).zip"
    ditto -c -k --keepParent "$target" "$upload"
fi

# The verdict is read from the output below, so a non-zero exit here is not fatal by itself.
xcrun notarytool submit "$upload" --wait "${auth[@]}" | tee "$log" || true

if ! grep -q 'status: Accepted' "$log"; then
    id="$(awk '/^ *id:/ { print $2; exit }' "$log")"
    if [ -n "$id" ]; then
        xcrun notarytool log "$id" "${auth[@]}" >&2
    fi
    echo "notarize: $target was not accepted" >&2
    exit 1
fi

xcrun stapler staple "$target"
xcrun stapler validate "$target"
