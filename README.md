<p align="center">
  <img src="https://chowser.sreerams.in/icon.png" alt="Chowser" width="128" height="128" />
</p>

# Chowser 🧭

A native macOS browser chooser with **profiles**, **smart routing**, **URL rewrites**, and **AI-assisted setup**. Intercept links anywhere and open them in the right browser, every time.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

🌐 **[chowser.sreerams.in](https://chowser.sreerams.in)** — Product tour, [setup guide](https://chowser.sreerams.in/guide), [hosted rewrite catalog](https://chowser.sreerams.in/rewrites), and AI-powered configuration

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
- **URL Rewrites** — Clean or transform links before routing, with host, path, scheme, and source-app matching
- **Hosted Rewrite Catalog** — Review and selectively add maintained HTTPS and tracking-cleanup rules; catalog checks are explicit, never automatic
- **Native App Deep Links** — Optionally open supported web links in installed native apps using a signed, app-agnostic directory; each app is disabled until you approve its exact behavior
- **Focus Mode (Temporary Default)** — Route all links to a specific browser for 1 Hour or Until Tomorrow from the menu bar
- **URL Unshortening** — Automatically strips tracking parameters and resolves shortlinks before routing. Press `H` to manually resolve unknown shortlinks
- **Private / Incognito Mode** — Open any link in private mode via keyboard shortcut (`P`) or per-rule toggle
- **App-Based Routing** — Route links based on the source app that opened them (e.g., Slack links → Chrome Work)
- **Quick Rule Creation** — Press `R` in the picker to instantly build a routing rule
- **Domain Frequency Tracking** — Suggests auto-routing rules after you repeatedly open a domain in the same browser
- **Clipboard URL** — Open URLs from your clipboard via the menu bar
- **Send to Phone** — Transfer the current link by AirDrop, QR code, or copy, with best-effort Handoff support
- **Rule Portability** — Import/Export both browser configs and routing rules as JSON
- **App or Menu Bar Mode** — Choose a Dock/Cmd-Tab app or a menu-bar-only experience, and switch safely at any time
- **Privacy-Safe Diagnostics** — Inspect lifecycle events and copy, export, or attach a support report without browsing data or local paths
- **Local MCP API** — Let an AI agent inspect and update browsers, routing rules, rewrites, picker preferences, and App Mode after you enable the localhost server
- **Hidden Apps** — Hide non-browser apps that register as web handlers
- **Menu Bar App** — Runs silently in the background, no Dock icon
- **Launch at Login** — Start automatically when you log in
- **Secure Direct Updates** — Signed GitHub releases update through Sparkle, with automatic checks and an opt-in beta channel

Hosted rewrite and native-app catalogs use detached Ed25519 signatures, a public key pinned in the app, bounded typed schemas, rollback-resistant last-known-good caching, and explicit consent. Chowser fetches only the catalog artifacts; clicked URLs are never sent to the catalog host. See [Signed hosted catalog security](docs/adr/0005-signed-hosted-catalogs.md).

## Installation

### Direct Download

Direct-download builds are published on [GitHub Releases](https://github.com/bsreeram08/chowser/releases) after signing and notarization. A valid binary release includes a `Chowser-<version>.dmg` asset; source-only entries are not installable releases.

### Mac App Store

[Download from the Mac App Store](https://apps.apple.com/in/app/chowser/id6760034779)

### Build from Source

Requirements: Xcode 15+ and macOS 14+

```bash
git clone https://github.com/bsreeram08/chowser.git
cd chowser
open Chowser.xcodeproj
```

Then in Xcode:
1. Select the **Chowser-osp** scheme and **My Mac** as the destination
2. Press **Cmd+R** to build and run
3. The app will appear in your menu bar

Or build from the command line:

```bash
xcodebuild -project Chowser.xcodeproj \
  -scheme Chowser-osp \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO

# App is at build/Build/Products/Release/Chowser.app
open build/Build/Products/Release/Chowser.app
```

> Note: Builds from source run without sandbox restrictions, enabling full browser profile support.
> The in-app updater stays disabled in local builds unless `SPARKLE_PUBLIC_ED_KEY` is supplied at build time.

## Testing

```bash
# Unit tests
xcodebuild test -project Chowser.xcodeproj -scheme Chowser-osp -destination 'platform=macOS' -only-testing:ChowserTests

# UI end-to-end tests
xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS'
```

## Tech Stack

- **SwiftUI** — Native macOS UI
- **AppKit** — Menu bar integration, browser launching
- **ServiceManagement** — Launch at Login
- **Network.framework** — Localhost-only MCP HTTP API

## License

MIT — see [LICENSE](LICENSE) for details.
