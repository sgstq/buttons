#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

DMG="Buttons.dmg"

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
    cat <<'EOF'
✗ NOTARY_PROFILE not set. One-time setup:

  xcrun notarytool store-credentials "buttons" \
      --apple-id "you@example.com" \
      --team-id "YOUR_TEAM_ID" \
      --password "your-app-specific-password"

App-specific passwords: https://appleid.apple.com/account/manage → Sign-In and Security
Team ID: Apple Developer portal → Membership → Team ID

Then re-run: NOTARY_PROFILE=buttons ./notarize.sh
EOF
    exit 1
fi

if [[ ! -f "$DMG" ]]; then
    echo "✗ $DMG not found. Run ./make-dmg.sh first."
    exit 1
fi

echo "→ Submitting $DMG to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$DMG" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

echo "→ Stapling notarization ticket to .dmg…"
xcrun stapler staple "$DMG"

echo "✓ Notarized + stapled. $DMG is ready for distribution."
