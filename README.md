# Buttons

[![Latest release](https://img.shields.io/github/v/release/sgstq/buttons?display_name=tag&label=latest&sort=semver)](https://github.com/sgstq/buttons/releases/latest)
[![CI](https://github.com/sgstq/buttons/actions/workflows/ci.yml/badge.svg)](https://github.com/sgstq/buttons/actions/workflows/ci.yml)

A tiny macOS menu-bar utility that turns trackpad multi-finger gestures and
global keyboard shortcuts into keystrokes, mouse clicks, or multi-step
chains — scoped per app.

### Warning
<p align="center">
  <img src="warning.png" alt="Warning" width="400">
</p>
<p align="center">
  <b>ALL CODE AND SCRIPTS IN THIS REPOSITORY—EVEN THOSE BASED ON REAL DOCUMENTATION—ARE ENTIRELY EXPERIMENTAL. ALL LOGIC WAS HALLUCINATED BY MATRIX MULTIPLICATIONS….. HAPHAZARDLY. THE FOLLOWING REPOSITORY CONTAINS UNTESTED CODE AND DUE TO ITS CONTENT IT SHOULD NOT BE USED ANYWHERE BY ANYONE ■</b>
</p>

## What is it

Buttons binds inputs to actions, scoped per app:

- **Inputs** — global keyboard shortcuts (Carbon Hotkey API), and trackpad
  multi-finger gestures (tap or directional swipe; 2–5 fingers).
- **Outputs** — send a keystroke, send text, post a mouse click
  (left / middle / right), launch an app, or open a URL. Chained actions
  with optional delays between steps are supported: import a chain from
  BetterTouchTool and you can then edit, reorder, or extend its steps in
  the native editor (chains can't be created from scratch yet).
- **Scope** — each trigger can be limited to a specific application or fire
  globally.

The app lives in the menu bar and can be hidden from there if you prefer —
it keeps running in the background regardless.

### What's not (yet) supported

- Creating a brand-new multi-step chain in the native editor (you can edit
  imported BTT chains, but to start a new chain you currently have to
  import one from BetterTouchTool).
- Window snapping, Touch Bar, scripting actions, drawn mouse gestures.
- Apple Magic Mouse single-touch surface (uses the same private framework,
  but gesture classification is currently trackpad-tuned).

## Usage

- **Menu-bar `⌘` icon** → Pause / Resume triggers, open Preferences, Quit.
- **Preferences window** → trigger list, add/edit, per-app scope, and
  general settings (including hiding the menu-bar icon). Re-launch
  Buttons.app to reopen Preferences when the icon is hidden.
- On first launch, grant **Accessibility** permission when prompted
  (System Settings → Privacy & Security → Accessibility). This is what
  lets Buttons post keystrokes and mouse clicks.

## Build from source

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools).

```bash
git clone git@github.com:sgstq/buttons.git
cd buttons
./release.sh          # produces Buttons.app and Buttons.dmg
open Buttons.app
```
