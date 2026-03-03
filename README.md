# Chowser 🧭

A lightweight macOS browser chooser with **profiles support**, **smart routing**, and **rule portability**. Intercept links anywhere and open them in the right browser, every time.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

🌐 **[chowser.sreerams.in](https://chowser.sreerams.in)** — Landing page with setup guide & AI-powered configuration

## How It Works

1. Set Chowser as your default browser
2. Click any link in any app
3. A sleek picker appears — choose your browser
4. The link opens, Chowser disappears

Chowser lives in your menu bar and uses zero resources when idle.

## Features

- **Browser Picker** — Choose from your configured browsers with a single click
- **Keyboard Shortcuts** — Press `1` through `9`, type a browser initial, or use `↑/↓` + Return for instant selection
- **Browser Profiles** — Full support for Chrome, Brave, Edge, Vivaldi, Arc, Dia, Firefox, Zen, LibreWolf, and Waterfox profiles
- **Advanced Routing Rules** — Auto-open matching domains/paths (wildcard support) in a specific browser, bypassing the picker
- **Focus Mode (Temporary Default)** — Route all links to a specific browser for 1 Hour or Until Tomorrow from the menu bar
- **URL Unshortening** — Automatically strips tracking parameters and resolves shortlinks (`shorturl.at`, `bit.ly`, etc.) before routing. Press `H` to manually resolve unknown shortlinks
- **Private / Incognito Mode** — Open any link in private mode via keyboard shortcut (`P`) or per-rule toggle
- **App-Based Routing** — Route links based on the source app that opened them (e.g., Slack links → Chrome Work)
- **Quick Rule Creation** — Option-click (⌥) any Recent URL in the menu bar, or press `R` in the picker to instantly build a routing rule
- **Rule Tester Simulator** — Instantly test and debug URLs against your active rules inside the Settings window
- **Domain Frequency Tracking** — Suggests auto-routing rules after you repeatedly open a domain in the same browser
- **Clipboard URL** — Open URLs from your clipboard via the menu bar
- **Interactive Onboarding** — Smart setup flow that detects if Chowser is already the default browser and guides you through configuration
- **Rule Portability** — Import/Export both browser configs and routing rules as JSON
- **Hidden Apps** — Hide non-browser apps (VLC, IINA, MX Player, etc.) that register as web handlers
- **Menu Bar App** — Runs silently in the background, no Dock icon
- **Launch at Login** — Start automatically when you log in
- **Fully Configurable** — Add, remove, reorder browsers, and set custom launch arguments in Settings

## Installation

### From DMG (Recommended)

1. Download the latest `.dmg` from [Releases](https://github.com/bsreeram08/chowser/releases)
2. Open the DMG and drag Chowser to Applications
3. Launch Chowser — it appears in the menu bar
4. Right-click → Open if macOS shows a security warning (first time only)
5. Click the menu bar icon → **Set as Default Browser**

### 🤖 AI-Powered Auto-Setup

Skip manual configuration. Copy the prompt below, paste it into **Claude, ChatGPT, or Cursor**, and your AI agent will scan your Mac, find every browser and profile, generate routing rules, and give you ready-to-import JSON files.

<details>
<summary><strong>📋 Click to expand the full AI prompt</strong></summary>

```
I have installed Chowser (bundle ID: in.sreerams.Chowser) on my Mac.
It's a browser chooser app that intercepts links. I need you to:

## Step 1: Discover my browsers and profiles

Scan my Mac for all installed browsers and their profiles:

- Chromium browsers (Chrome, Brave, Edge, Vivaldi, Arc, Opera):
  Check ~/Library/Application Support/{BrowserName}/Local State
  Parse the JSON → profile.info_cache → each key is a profile directory name
  (e.g. "Default", "Profile 1", "Profile 2")

- Firefox-based (Firefox, Zen, LibreWolf, Waterfox):
  Check ~/Library/Application Support/{BrowserName}/profiles.ini
  Parse the INI → each [Profile*] section → Name= is the profile name

- Safari: No profiles, just add it as-is.

For each browser+profile combo, produce a JSON object:
{ "name": "Chrome - Work", "bundleId": "com.google.Chrome", "shortcutKey": "1", "profile": "Profile 1" }

Save ALL of them as a JSON array in a file called ~/Documents/ChowserBrowsers.json.

## Step 2: Generate routing rules

Based on my needs: [EDIT THIS — e.g. "work stuff in Chrome Work profile, personal browsing in Safari, dev docs in Firefox"]

For each rule, produce a JSON object:
{ "name": "Work GitHub", "hostPattern": "*.github.com", "pathPrefix": "/my-company", "browserBundleId": "com.google.Chrome", "profile": "Profile 1", "isEnabled": true }

hostPattern supports exact match (github.com) or wildcard (*.github.com).
pathPrefix is optional — only set it if you need path-level routing.

Save ALL rules as a JSON array in a file called ~/Documents/ChowserRules.json.

## Step 3: Review before importing

Before importing, show me:
1. A summary table of all discovered browsers and profiles
2. A summary table of all generated routing rules
3. Ask for my confirmation before proceeding to import

Only proceed to Step 4 after I confirm.

## Step 4: Import into Chowser

Use CLI flags to import directly (no manual UI steps needed):

open -a Chowser --args --browsers=~/Documents/ChowserBrowsers.json --rules=~/Documents/ChowserRules.json

Alternatively, I can import manually:
- Open Chowser → Menu Bar Icon → Settings
- Browsers tab → click ⋯ menu → Import Browsers → select ChowserBrowsers.json
- Rules tab → click ⋯ menu → Import Rules → select ChowserRules.json
```

</details>

---

### From Source

```bash
git clone https://github.com/bsreeram08/chowser.git
cd chowser
xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build
```

## Creating a Release

```bash
# Build and create a styled DMG (bumps version, tags, generates background)
./scripts/release.sh 2.9.0

# This will:
# 1. Update the version in Xcode project
# 2. Build a Release archive
# 3. Generate a styled DMG background
# 4. Create a DMG with icon positioning
# 5. Create a git tag v2.7.1
# 6. Output the DMG to release/Chowser-2.9.0.dmg
```

Releases are also automated via GitHub Actions — push a `v*` tag and it builds + publishes the release.

## Testing

```bash
# Unit tests
xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests

# UI end-to-end tests
xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS'
```

## Tech Stack

- **SwiftUI** — Native macOS UI
- **AppKit** — Menu bar integration, browser launching
- **ServiceManagement** — Launch at Login

## License

MIT — see [LICENSE](LICENSE) for details.
