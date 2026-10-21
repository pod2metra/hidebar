#!/bin/bash
# Creates a self-signed code-signing certificate in the login keychain, once.
# Builds signed with it keep the same designated requirement, so macOS keeps the
# Accessibility grant across rebuilds. Local use only: the
# certificate is not trusted by any other Mac and cannot be notarized.
set -euo pipefail

NAME="${HIDEBAR_SIGN_IDENTITY:-Hidebar Local Signing}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -qF "\"$NAME\""; then
    echo "Signing identity \"$NAME\" already exists."
    exit 0
fi

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

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$WORK/cert.cnf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem"
# A throwaway password: macOS `security import` refuses PKCS#12 files without one.
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -name "$NAME" -passout pass:hidebar -out "$WORK/cert.p12"

security import "$WORK/cert.p12" -k "$KEYCHAIN" -P hidebar -T /usr/bin/codesign
echo "Trusting the certificate for code signing; macOS asks for your password."
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

security find-identity -v -p codesigning | grep -F "\"$NAME\""
echo "Done. Build with: make run"
