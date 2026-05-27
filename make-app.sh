#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "→ Building release binary…"
swift build -c release

APP="Buttons.app"
BIN_NAME="Buttons"
BUILT_BIN="$(swift build -c release --show-bin-path)/${BIN_NAME}"

if [[ ! -f "$BUILT_BIN" ]]; then
    echo "✗ Build output not found at $BUILT_BIN"
    exit 1
fi

echo "→ Bundling into ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILT_BIN" "$APP/Contents/MacOS/${BIN_NAME}"
cp Resources/Info.plist "$APP/Contents/Info.plist"

SIGN_ID="${DEVELOPER_ID_APP:--}"
ENTITLEMENTS="Resources/entitlements.plist"

if [[ "$SIGN_ID" == "-" ]]; then
    echo "→ Ad-hoc signing (hardened runtime)…"
    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign - "$APP"
else
    echo "→ Signing with Developer ID: $SIGN_ID"
    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --timestamp \
        --sign "$SIGN_ID" "$APP"
fi

codesign --verify --verbose=2 "$APP" >/dev/null

echo "✓ Built $APP"
echo ""
echo "Run:    open $APP"
echo "DMG:    ./make-dmg.sh"
