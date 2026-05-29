#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${1:-FinderPasteFix Local Code Signing}"
KEYCHAIN="$(security default-keychain -d user | tr -d '"')"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if security find-identity -v -p codesigning | grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
  echo "Code signing identity already exists: $IDENTITY_NAME"
  exit 0
fi

openssl req \
  -x509 \
  -newkey rsa:2048 \
  -sha256 \
  -nodes \
  -days 3650 \
  -subj "/CN=$IDENTITY_NAME/" \
  -addext "keyUsage=digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" \
  -keyout "$TMP_DIR/key.pem" \
  -out "$TMP_DIR/cert.pem"

openssl pkcs12 \
  -export \
  -inkey "$TMP_DIR/key.pem" \
  -in "$TMP_DIR/cert.pem" \
  -name "$IDENTITY_NAME" \
  -out "$TMP_DIR/identity.p12" \
  -passout pass:

security import "$TMP_DIR/identity.p12" \
  -k "$KEYCHAIN" \
  -P "" \
  -T /usr/bin/codesign

security add-trusted-cert \
  -r trustRoot \
  -p codeSign \
  -k "$KEYCHAIN" \
  "$TMP_DIR/cert.pem"

echo
echo "Created and trusted code signing identity: $IDENTITY_NAME"
echo "If codesign prompts for keychain access during builds, choose Always Allow."
echo
security find-identity -v -p codesigning | sed -n '1,20p'
