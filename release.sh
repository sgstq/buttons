#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

./make-app.sh
./make-dmg.sh

if [[ -n "${NOTARY_PROFILE:-}" && -n "${DEVELOPER_ID_APP:-}" ]]; then
    ./notarize.sh
    echo ""
    echo "✓ Frictionless distribution ready: Buttons.dmg"
    echo "  Friends double-click → drag to /Applications → done."
else
    echo ""
    echo "✓ Ad-hoc Buttons.dmg ready."
    echo ""
    echo "  Distribution caveat: friends will see a Gatekeeper warning on first launch."
    echo "  Tell them to:"
    echo "    1. Drag Buttons.app to /Applications"
    echo "    2. Right-click → Open (twice, if needed)"
    echo "       OR System Settings → Privacy & Security → 'Open Anyway'"
    echo "    3. Grant Accessibility permission when prompted"
    echo ""
    echo "  For frictionless installs, set DEVELOPER_ID_APP + NOTARY_PROFILE and re-run."
fi
