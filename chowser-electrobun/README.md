# Chowser — Electrobun Edition

A macOS menu-bar browser router built with [Electrobun](https://github.com/blackboardsh/electrobun).

Chowser intercepts every link you click and routes it to the right browser — automatically or via a quick picker UI.

## Features

- 🔗 **URL interception** — registers as a handler for `http://` and `https://` links
- 🎯 **Smart routing rules** — match by host pattern, path prefix, and source app
- 🖱️ **Browser picker** — keyboard-driven modal (shortcuts `1`–`9`, `P` for private, `R` for quick rule)
- 🗂️ **Browser profiles** — full support for Chrome, Brave, Edge, Vivaldi, Firefox, and Zen profiles
- 🕵️ **Private/incognito mode** — per-rule or on-demand toggle
- ⚙️ **Settings window** — manage browsers, rules, import/export JSON config
- 📊 **Auto-rule suggestions** — suggests a rule after 30 clicks on the same domain
- 🖥️ **Menu bar app** — no Dock icon, lives quietly in the status bar

## Architecture

```
chowser-electrobun/
├── electrobun.config.ts        # Electrobun build config (URL schemes, icons, entitlements)
├── package.json
├── tsconfig.json
├── icon.iconset/               # App icons (PNG files)
└── src/
    ├── bun/                    # Main Bun process (runs persistently in the background)
    │   ├── index.ts            # Entry point: tray, URL event handler, window lifecycle
    │   ├── models.ts           # Data types: BrowserConfig, BrowserRoutingRule, etc.
    │   ├── routing.ts          # URL routing engine + domain frequency tracking
    │   ├── browserLauncher.ts  # Open URLs in specific browsers with profile support
    │   ├── browserDetector.ts  # Detect installed browsers and their profiles
    │   └── config.ts           # JSON persistence (debounced writes)
    └── views/
        ├── picker/             # Browser picker modal
        │   ├── index.html
        │   └── index.ts        # Webview TypeScript (RPC ↔ Bun)
        └── settings/           # Settings window
            ├── index.html
            └── index.ts        # Webview TypeScript (RPC ↔ Bun)
```

## Prerequisites

- **macOS 14+**
- **[Bun](https://bun.sh)** runtime (`curl -fsSL https://bun.sh/install | bash`)
- **Node.js** (for `npx electrobun` CLI)

> **Note on `@types/three` devDependency**: Electrobun ships its library as
> TypeScript source files (`.ts`) rather than pre-compiled declarations (`.d.ts`).
> TypeScript therefore processes Electrobun's source transitively and needs
> `@types/three` (a Three.js transitive dependency of Electrobun) to avoid a
> "Could not find a declaration file" error. This package is *only* used for type
> checking — it has no effect on the built app.

## Getting Started

```bash
# Install dependencies
cd chowser-electrobun
npm install        # installs the electrobun CLI

# Development (builds and runs the app)
npm run dev

# Production build (creates Chowser.app)
npm run build

# Package for distribution (creates .dmg)
npm run package
```

## Setting Chowser as Your Default Browser

After first launch, click **"Set as Default Browser"** in the tray menu (or the onboarding banner in Settings). This opens macOS System Settings → Desktop & Dock where you can change the default web browser to **Chowser**.

Once set, every `http://` or `https://` link you click anywhere on the system will come through Chowser first.

## Routing Rules

Rules are evaluated top-to-bottom. The first matching rule wins.

Each rule can match on:

| Field | Example |
|---|---|
| Host pattern (glob) | `*.github.com`, `github.com`, `**google.com` |
| Path prefix | `/work`, `/personal` |
| Source app | `com.tinyspeck.slackmacgap` (links from Slack) |

Use `R` in the picker or **Settings → Rules → Add Rule** to create rules.

## Browser Profiles

Chowser supports Chrome/Brave/Edge/Vivaldi profiles (via `--profile-directory`) and Firefox/Zen profiles (via `-P`). 

In Settings, click **🔍 Detect** to auto-discover installed browsers and their profiles, then add them individually.

## Import / Export

Go to **Settings → General → Export/Import** to back up or restore your browsers and rules as JSON.

```json
{
  "browsers": [
    {
      "id": "...",
      "name": "Chrome Work",
      "appId": "com.google.Chrome",
      "shortcutKey": "1",
      "profile": "Profile 1"
    }
  ],
  "rules": [
    {
      "id": "...",
      "name": "GitHub in Chrome",
      "hostPattern": "*.github.com",
      "browserAppId": "com.google.Chrome",
      "isEnabled": true,
      "usePrivateMode": false,
      "useRegex": false
    }
  ]
}
```

## Icons

Place your app icon PNGs in `icon.iconset/`. Electrobun converts them automatically.

Required sizes: `icon_16x16.png`, `icon_16x16@2x.png`, `icon_32x32.png`, `icon_32x32@2x.png`, `icon_128x128.png`, `icon_128x128@2x.png`, `icon_256x256.png`, `icon_256x256@2x.png`, `icon_512x512.png`, `icon_512x512@2x.png`.

## State Storage

Configuration is persisted as JSON at:
`~/Library/Application Support/in.sreerams.chowser-electrobun/state.json`

## Differences from the Swift / Tauri versions

| Feature | Swift (native) | Tauri (Rust) | Electrobun (this) |
|---|---|---|---|
| Language | Swift + SwiftUI | Rust + JS | TypeScript (Bun) |
| Platform | macOS only | Cross-platform | macOS · Win · Linux |
| URL interception | Apple Events | Apple Events | `open-url` Electrobun event |
| UI toolkit | SwiftUI | HTML/JS | HTML/CSS/JS |
| Browser profiles | Full | Full | Full |
| Bundle size | ~5 MB | ~20 MB | ~12 MB |
