#!/bin/bash
# One-time setup: creates a self-signed local code-signing certificate and
# trusts it for code signing. This gives WordPop.app a stable signing
# identity across rebuilds, so macOS keeps remembering the Accessibility
# permission grant instead of resetting it on every `./build_app.sh`.
#
# Safe and reversible: this only touches your login keychain (not System),
# and you can remove the "WordPop Local Signing" certificate from
# Keychain Access at any time to undo it.
set -euo pipefail

CERT_NAME="WordPop Local Signing"
WORKDIR="$(mktemp -d)"
PASS="wordpop-temp-$$"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "Certificate '$CERT_NAME' already exists. Nothing to do."
    exit 0
fi

trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes \
  -subj "/CN=${CERT_NAME}" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"

# -legacy: macOS's PKCS12 importer doesn't support OpenSSL 3's modern
# default encryption for .p12 files.
openssl pkcs12 -legacy -export -out cert.p12 -inkey key.pem -in cert.pem -passout "pass:${PASS}"

security import cert.p12 -k ~/Library/Keychains/login.keychain-db -P "${PASS}" -T /usr/bin/codesign -T /usr/bin/security
security add-trusted-cert -p codeSign -k ~/Library/Keychains/login.keychain-db cert.pem

echo "Done. Created and trusted code-signing identity: $CERT_NAME"
echo "Re-run ./build_app.sh --install to build with stable signing."
