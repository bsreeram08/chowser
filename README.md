# Chowser 🧭

A lightweight macOS browser chooser. When you click a link anywhere on your Mac, Chowser intercepts it and lets you pick which browser to open it in.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

## How It Works

1. Set Chowser as your default browser
2. Click any link in any app
3. A sleek picker appears — choose your browser
4. The link opens, Chowser disappears

Chowser lives in your menu bar and uses zero resources when idle.

## Features

- **Browser Picker** — Choose from your configured browsers with a single click
- **Keyboard Shortcuts** — ⌘⇧1 through ⌘⇧9 for instant selection
- **Menu Bar App** — Runs silently in the background, no Dock icon
- **Launch at Login** — Start automatically when you log in
- **Configurable** — Add, remove, and reorder browsers in Settings

## Installation

### From DMG (Recommended)

1. Download the latest `.dmg` from [Releases](https://github.com/bsreeram08/chowser/releases)
2. Open the DMG and drag Chowser to Applications
3. Launch Chowser — it appears in the menu bar
4. Right-click → Open if macOS shows a security warning (first time only)
5. Click the menu bar icon → **Set as Default Browser**

### From Source

```bash
git clone https://github.com/bsreeram08/chowser.git
cd chowser
xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build
```

## Creating a Release

```bash
# Build and create a DMG (bumps version automatically)
./scripts/release.sh 1.0.5

# This will:
# 1. Update the version in Xcode project
# 2. Build a Release archive
# 3. Create a DMG with create-dmg
# 4. Create a git tag v1.0.5
# 5. Output the DMG to release/Chowser-1.0.5.dmg
```

## Tech Stack

- **SwiftUI** — Native macOS UI
- **AppKit** — Menu bar integration, browser launching
- **ServiceManagement** — Launch at Login

## License

MIT — see [LICENSE](LICENSE) for details.
