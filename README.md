# Buttons

[![Latest release](https://img.shields.io/github/v/release/sgstq/buttons?display_name=tag&label=latest&sort=semver)](https://github.com/sgstq/buttons/releases/latest)
[![CI](https://github.com/sgstq/buttons/actions/workflows/ci.yml/badge.svg)](https://github.com/sgstq/buttons/actions/workflows/ci.yml)

A minimal, open-source clone of [BetterTouchTool](https://folivora.ai) for macOS.
Trackpad multi-finger gestures and global keyboard shortcuts that fire keystrokes,
mouse clicks, or multi-step chains — scoped per app. Imports your existing BTT
config so you don't have to rebuild from scratch.

### Warning
<p align="center">
  <img src="warning.png" alt="Warning" width="400">
</p>
<p align="center">
  <b>ALL CODE AND SCRIPTS IN THIS REPOSITORY—EVEN THOSE BASED ON REAL DOCUMENTATION—ARE ENTIRELY EXPERIMENTAL. ALL LOGIC WAS HALLUCINATED BY MATRIX MULTIPLICATIONS….. HAPHAZARDLY. THE FOLLOWING REPOSITORY CONTAINS UNTESTED CODE AND DUE TO ITS CONTENT IT SHOULD NOT BE USED ANYWHERE BY ANYONE ■</b>
</p>

## Install

**Download the latest DMG:** [Buttons.dmg](https://github.com/sgstq/buttons/releases/latest/download/Buttons.dmg)
([all releases](https://github.com/sgstq/buttons/releases))

### First run

1. Mount the DMG and drag **Buttons** to **Applications**.
2. Launch it. Until the app is notarized you'll see a Gatekeeper warning —
   open **System Settings → Privacy & Security**, scroll to the bottom,
   click **Open Anyway** next to Buttons.
3. Grant **Accessibility** permission when prompted
   (System Settings → Privacy & Security → Accessibility).
   This is what lets Buttons post keystrokes and mouse clicks.
4. The preferences window opens automatically on first launch.
   Either click **+ Add Trigger** to make one by hand, or
   **Import → From BetterTouchTool database** / **From BTT JSON file…**
   to bring your existing setup over.

### Usage

- **Menu-bar `⌘` icon** → Pause / Resume triggers, open Preferences, Quit.
- **Preferences window** → trigger list, add/edit, import from BTT, per-app scope.
- Two input types: **global keyboard shortcuts** (Carbon Hotkey API) and
  **trackpad multi-finger gestures** (tap or directional swipe; finger count 2–5).
- Three output actions: **send keystroke**, **send text**, **mouse click**
  (left / middle / right). Chains (sequences with optional delays) are supported
  on import.

### What's not (yet) supported

- Editing chained / multi-step triggers in the UI (read-only after import).
- Window snapping, Touch Bar, scripting actions, drawn mouse gestures.
- Apple Magic Mouse single-touch surface (uses the same private framework,
  but gesture classification is currently trackpad-tuned).

## Build from source

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools).

```bash
git clone git@github.com:sgstq/buttons.git
cd buttons
./release.sh          # produces Buttons.app and Buttons.dmg
open Buttons.app
```

For a notarized build (requires an Apple Developer ID, $99/yr):

```bash
xcrun notarytool store-credentials "buttons" \
    --apple-id "you@example.com" \
    --team-id  "YOUR_TEAM_ID" \
    --password "app-specific-password"

export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="buttons"
./release.sh
```

## Releases

Releases are cut **automatically** when a PR is merged to `main`. The version
is bumped according to the PR's labels:

| Label         | Result                |
|---------------|-----------------------|
| _(none)_      | Patch bump (default)  |
| `bump:minor`  | Minor bump            |
| `bump:major`  | Major bump            |
| `bump:skip`   | No release            |

The workflow computes the next version from the latest `v*` tag, builds the
DMG, and uploads it to a fresh GitHub Release with auto-generated notes.

Manual triggers:

- **Push a tag** (`git tag v0.2.0 && git push --tags`) — releases that exact version.
- **Actions → Release → Run workflow** — manual run with a bump-kind selector.

### Configuring notarized releases in CI

When you have an Apple Developer ID, add these repo secrets
([settings/secrets/actions](https://github.com/sgstq/buttons/settings/secrets/actions)):

| Secret                                | Value                                                    |
|---------------------------------------|----------------------------------------------------------|
| `DEVELOPER_ID_APP_CERT_P12_BASE64`    | `base64 -i cert.p12` of the .p12 exported from Keychain  |
| `DEVELOPER_ID_APP_CERT_PASSWORD`      | Password used when exporting that .p12                   |
| `DEVELOPER_ID_APP_IDENTITY`           | `Developer ID Application: Your Name (TEAMID)`           |
| `APPLE_ID`                            | Your Apple ID email                                      |
| `APPLE_TEAM_ID`                       | 10-character Team ID                                     |
| `APPLE_APP_SPECIFIC_PASSWORD`         | From [appleid.apple.com](https://appleid.apple.com)      |

The workflow detects them automatically — no edits needed. From the next
release onward, the DMG is notarized and installs without Gatekeeper warnings.
