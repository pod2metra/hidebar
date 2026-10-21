#!/bin/bash
# Creates the ONE self-signed code-signing certificate that signs every Hidebar release, once,
# and stores it as the repository secrets SIGNING_P12 and SIGNING_P12_PASSWORD.
#
#   bash scripts/release_cert.sh <output.p12>
#
# Needs `gh`, logged in with access to the repository. The password of the .p12 is read from
# the terminal, or from RELEASE_P12_PASSWORD; it reaches `gh` on stdin, never as an argument.
# Every release signed with this certificate has the same designated requirement, so macOS keeps
# the Accessibility grant across updates. BACK UP THE .p12: losing it means a new certificate, a
# new signature, and every user has to grant Accessibility again.
# Nothing is written inside the repository, and nothing is imported into your keychain.
set -euo pipefail

NAME="Hidebar Release Signing"
REPO="pod2metra/hidebar"
# The system LibreSSL writes a PKCS#12 that `security import` reads; OpenSSL 3 needs -legacy for that.
OPENSSL=/usr/bin/openssl

out="${1:-}"
if [ -z "$out" ]; then
    echo "usage: bash scripts/release_cert.sh <output.p12>" >&2
    exit 2
fi
if [ -e "$out" ]; then
    echo "release_cert: $out already exists; refusing to overwrite a signing certificate" >&2
    exit 1
fi

# A GITHUB_TOKEN or GH_TOKEN in the environment would win over the account `gh` is logged in with.
gh_cli() { env -u GITHUB_TOKEN -u GH_TOKEN gh "$@"; }

if ! command -v gh >/dev/null; then
    echo "release_cert: gh is not installed (brew install gh)" >&2
    exit 1
fi
if ! existing="$(gh_cli secret list --repo "$REPO" --json name --jq '.[].name')"; then
    echo "release_cert: gh cannot list the secrets of $REPO; run: gh auth login" >&2
    exit 1
fi
# Replacing the certificate breaks the Accessibility grant of every user, so never do it silently.
if printf '%s\n' "$existing" | grep -qxE 'SIGNING_P12|SIGNING_P12_PASSWORD'; then
    echo "release_cert: $REPO already has the signing secrets; delete them first if you really mean to replace the certificate" >&2
    exit 1
fi

if [ -z "${RELEASE_P12_PASSWORD:-}" ]; then
    read -rs -p "Password for the .p12: " RELEASE_P12_PASSWORD
    echo
    read -rs -p "Repeat the password: " again
    echo
    if [ "$RELEASE_P12_PASSWORD" != "$again" ]; then
        echo "release_cert: passwords differ" >&2
        exit 1
    fi
fi
if [ -z "$RELEASE_P12_PASSWORD" ]; then
    echo "release_cert: an empty password is not accepted" >&2
    exit 1
fi
export RELEASE_P12_PASSWORD

umask 077
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat >"$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$WORK/cert.cnf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
"$OPENSSL" pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -name "$NAME" -passout env:RELEASE_P12_PASSWORD -out "$out"

sha1="$("$OPENSSL" x509 -in "$WORK/cert.pem" -noout -fingerprint -sha1 | sed -e 's/^.*=//' -e 's/://g')"

echo "Created $out  (\"$NAME\", valid 10 years)"
echo "Certificate SHA-1: $sha1"

if ! base64 -i "$out" | gh_cli secret set SIGNING_P12 --repo "$REPO" ||
    ! printf '%s' "$RELEASE_P12_PASSWORD" | gh_cli secret set SIGNING_P12_PASSWORD --repo "$REPO"; then
    cat >&2 <<EOF
release_cert: storing the secrets failed; $out is kept. Store them by hand:
   base64 -i "$out" | gh secret set SIGNING_P12 --repo $REPO
   gh secret set SIGNING_P12_PASSWORD --repo $REPO
EOF
    exit 1
fi

cat <<EOF

Stored SIGNING_P12 and SIGNING_P12_PASSWORD in $REPO.

1. Back up $out and its password somewhere safe, outside this repository.
2. Do not run this script again unless you accept that every user grants Accessibility anew.
EOF
