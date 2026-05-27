#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP="Buttons.app"
DMG="Buttons.dmg"
VOLNAME="Buttons"
STAGING=".dmg-staging"

if [[ ! -d "$APP" ]]; then
    echo "✗ $APP not found. Run ./make-app.sh first."
    exit 1
fi

echo "→ Preparing DMG staging…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "→ Building ${DMG}…"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGING"

# Sign the DMG itself when Developer ID is configured (required for notarization).
SIGN_ID="${DEVELOPER_ID_APP:-}"
if [[ -n "$SIGN_ID" ]]; then
    echo "→ Signing DMG with: $SIGN_ID"
    codesign --force --sign "$SIGN_ID" --timestamp "$DMG"
fi

echo "✓ Built $DMG"
