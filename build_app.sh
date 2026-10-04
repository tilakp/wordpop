#!/bin/bash
# Builds WordPop.app: compiles the Swift package in release mode and
# assembles/signs a proper .app bundle so macOS treats Accessibility
# permission and the "no Dock icon" setting correctly.
set -euo pipefail
cd "$(dirname "$0")"

# Universal: Apple silicon and Intel. The Apple Intelligence features
# need Apple silicon; everything else runs on Intel Macs too.
swift build -c release --arch arm64 --arch x86_64
# A multi-architecture build has no .build/release link; ask for the path.
BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

APP="WordPop.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/WordPop" "$APP/Contents/MacOS/WordPop"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Sources/WordPop/Resources/wordpop.sqlite "$APP/Contents/Resources/wordpop.sqlite"

SIGN_IDENTITY="-"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "WordPop Local Signing"; then
    SIGN_IDENTITY="WordPop Local Signing"
else
    echo "WARNING: 'WordPop Local Signing' identity not found — falling back to ad-hoc signing." >&2
    echo "         This resets your Accessibility permission grant on every rebuild. Run ./setup_signing.sh once to fix it." >&2
fi
codesign --force --deep --sign "$SIGN_IDENTITY" --identifier com.tilak.wordpop "$APP"

echo "Built $APP (signed with: $SIGN_IDENTITY)"

if [ "${1:-}" = "--install" ]; then
    rm -rf "/Applications/$APP"
    cp -R "$APP" "/Applications/$APP"
    echo "Installed to /Applications/$APP"
fi
