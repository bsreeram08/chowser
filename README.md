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
- **URL Unshortening** — Automatically strips tracking parameters and resolves shortlinks before routing. Press `H` to manually resolve unknown shortlinks
- **Private / Incognito Mode** — Open any link in private mode via keyboard shortcut (`P`) or per-rule toggle
- **App-Based Routing** — Route links based on the source app that opened them (e.g., Slack links → Chrome Work)
- **Quick Rule Creation** — Press `R` in the picker to instantly build a routing rule
- **Domain Frequency Tracking** — Suggests auto-routing rules after you repeatedly open a domain in the same browser
- **Clipboard URL** — Open URLs from your clipboard via the menu bar
- **Rule Portability** — Import/Export both browser configs and routing rules as JSON
- **Hidden Apps** — Hide non-browser apps that register as web handlers
- **Menu Bar App** — Runs silently in the background, no Dock icon
- **Launch at Login** — Start automatically when you log in

## Installation

### Mac App Store

[Download from the Mac App Store](https://apps.apple.com/app/chowser/id6741527291)

### Build from Source

Requirements: Xcode 15+ and macOS 14+

```bash
git clone https://github.com/bsreeram08/chowser.git
cd chowser
open Chowser.xcodeproj
```

Then in Xcode:
1. Select the **Chowser** scheme and **My Mac** as the destination
2. Press **Cmd+R** to build and run
3. The app will appear in your menu bar

Or build from the command line:

```bash
xcodebuild -project Chowser.xcodeproj \
  -scheme Chowser \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO

# App is at build/Build/Products/Release/Chowser.app
open build/Build/Products/Release/Chowser.app
```

> Note: Builds from source run without sandbox restrictions, enabling full browser profile support.

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
