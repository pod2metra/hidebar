#!/bin/bash
# Creates the ONE self-signed code-signing certificate that signs every Hidebar release, once.
#
#   bash scripts/release_cert.sh <output.p12>
#
# The password of the .p12 is read from the terminal, or from RELEASE_P12_PASSWORD.
# Every release signed with this certificate has the same designated requirement, so macOS keeps
# the Accessibility grant across updates. BACK UP THE .p12: losing it means a new certificate, a
# new signature, and every user has to grant Accessibility again.
# Nothing is written inside the repository, and nothing is imported into your keychain.
set -euo pipefail

NAME="Hidebar Release Signing"
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

cat <<EOF

Created $out  ("$NAME", valid 10 years)
Certificate SHA-1: $sha1

1. Back up $out and its password somewhere safe, outside this repository.
2. Store them as repository secrets (the second command asks for the password):

   base64 -i "$out" | gh secret set SIGNING_P12 --repo pod2metra/hidebar
   gh secret set SIGNING_P12_PASSWORD --repo pod2metra/hidebar

3. Do not run this script again unless you accept that every user grants Accessibility anew.
EOF
