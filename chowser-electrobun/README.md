# Chowser — Electrobun Edition

A lightweight, cross-platform browser router built with [Electrobun](https://github.com/blackboardsh/electrobun). Intercept links on **macOS**, **Windows 10+**, and **Linux** — and route them to the right browser automatically or via a quick picker UI.

![macOS](https://img.shields.io/badge/macOS-14+-blue?logo=apple)
![Windows](https://img.shields.io/badge/Windows-10+-0078d4?logo=windows)
![Linux](https://img.shields.io/badge/Linux-🐧-ff6600)
![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-3178c6?logo=typescript)
![Bun](https://img.shields.io/badge/Bun-1.0+-f471b5?logo=bun)
![License](https://img.shields.io/badge/License-MIT-green)

## How It Works

1. Set Chowser as your default browser (or handler for `http://` / `https://`)
2. Click any link in any app
3. If a routing rule matches → link opens automatically in the target browser
4. Otherwise → Chowser's picker appears — choose your browser with a single keystroke
5. Chowser disappears; your link opens

Chowser runs in the background with minimal resource overhead — tray icon on macOS/Windows, background process on Linux.

## Features

> **Full feature parity across all platforms** with platform-specific notes below.

- 🔗 **URL interception** — registers as a handler for `http://` and `https://` links on all platforms
- 🎯 **Smart routing rules** — auto-match URLs by host pattern, path prefix, and source app (macOS only)
- 🖱️ **Browser picker** — keyboard-driven modal with shortcuts: `1`–`9`, type first letter, `P` for private, `R` for quick rule creation
- 🗂️ **Browser profiles** — support for Chrome, Brave, Edge, Vivaldi, Arc, Dia, Firefox, Zen, LibreWolf, and Waterfox profiles
- 🕵️ **Private/incognito mode** — toggle via keyboard (`P`) or per-rule setting
- ⚙️ **Settings window** — manage browsers, rules, import/export JSON config
- 📊 **Domain frequency tracking** — auto-suggest routing rules after 30 clicks on the same domain
- 🌐 **URL unshortening** — automatically expand shortlinks and strip tracking parameters before routing
- 📋 **Clipboard URL support** — open URLs from clipboard via tray menu
- 🔄 **Rule portability** — import/export full browser and routing configuration as JSON
- 🚀 **Launch at login** — auto-start when you log in
- 🌍 **Set as default browser** — one-click registration (Windows via registry, Linux via xdg-settings)
- 💻 **MCP Server** — REST API for AI-driven management (localhost:24245)

## Architecture

```
chowser-electrobun/
├── electrobun.config.ts        # Electrobun build config (URL schemes, icons, platform config)
├── package.json
├── tsconfig.json
├── icon.iconset/               # App icons (macOS icns)
├── assets/icons/               # App icons for Windows & Linux
└── src/
    ├── bun/                    # Main Bun process (runs persistently)
    │   ├── index.ts            # Entry point: tray/menu, URL interception, window lifecycle
    │   ├── models.ts           # Data types: BrowserConfig, BrowserRoutingRule, etc.
    │   ├── routing.ts          # Routing engine + domain frequency tracking
    │   ├── domainFrequency.ts  # Domain click tracking → rule suggestions
    │   ├── browserLauncher.ts  # Launch browsers with profile/private mode support
    │   ├── browserDetector.ts  # Detect installed browsers and their profiles
    │   ├── urlUtils.ts         # URL normalization, unshortening, cleaning
    │   ├── platform.ts         # OS detection & platform-specific path resolution
    │   ├── mcpServer.ts        # REST API server for AI management
    │   ├── config.ts           # JSON persistence (debounced writes)
    │   └── *.test.ts           # Unit tests (run with `bun test`)
    └── views/                  # Svelte-based webviews
        ├── picker/             # Browser picker modal UI
        │   ├── index.html
        │   └── index.ts        # Webview TypeScript (RPC ↔ Bun backend)
        └── settings/           # Settings window UI
            ├── index.html
            └── index.ts        # Webview TypeScript (RPC ↔ Bun backend)
```

## Prerequisites

### All Platforms

- **[Bun](https://bun.sh)** runtime (v1.0+)
  - macOS/Linux: `curl -fsSL https://bun.sh/install | bash`
  - Windows: `powershell -c "irm bun.sh/install.ps1|iex"`
- **Node.js** (for `npx electrobun` CLI; optional if Bun is installed)

### macOS

- **macOS 14+** (Sonoma or later)
- Xcode Command Line Tools (for native build tools)

### Windows

- **Windows 10 Build 19041** or later (Windows 10 22H2, Windows 11)
- **WebView2 Runtime** — Chowser will prompt to install if missing
  - [Download WebView2](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)
  - Or via `winget`: `winget install Microsoft.WebView2Runtime`

### Linux

- **Ubuntu 20.04+**, **Fedora 33+**, **Arch Linux** (or any distro with GTK 3.0+)
- **WebKit2GTK** and related development libraries:
  - **Ubuntu/Debian**: `sudo apt install libwebkit2gtk-4.1-0 libgtk-3-0`
  - **Fedora**: `sudo dnf install webkit2gtk3 gtk3`
  - **Arch**: `sudo pacman -S webkit2gtk gtk3`

> **Note on `@types/three` devDependency**: Electrobun ships TypeScript source files (`.ts`) rather than pre-compiled declarations (`.d.ts`). TypeScript needs `@types/three` (a transitive dependency of Electrobun) to avoid a "Could not find a declaration file" error. This package is *only* for type checking — it has zero runtime impact.

## Getting Started

```bash
# Install dependencies
cd chowser-electrobun
npm install        # or: bun install

# Development mode (builds and runs the app)
npm run dev

# Production build
npm run build           # macOS
npm run build:windows   # Windows
npm run build:linux     # Linux

# Create installer/archive for distribution
npm run package           # macOS (.dmg)
npm run package:windows   # Windows (self-extracting .exe)
npm run package:linux     # Linux (self-extracting .tar.gz)

# Run unit tests
npm run test

# Run E2E tests (Playwright)
npm run test:e2e
```

## Setting as Default Browser

Chowser must be registered as the handler for `http://` and `https://` URLs.

### macOS

1. Launch Chowser
2. Click the tray icon → **"Set as Default Browser"** (or navigate to Settings → General)
3. macOS opens System Settings → **Desktop & Dock**
4. Change **Default web browser** to **Chowser**

### Windows

1. Launch Chowser
2. Click the tray icon → **"Set as Default Browser"** (or navigate to Settings → General)
3. Windows opens **Settings → Apps → Default apps**
4. Search for **http** or **https** → click → select **Chowser**

Chowser will also attempt to register itself in the registry automatically on first launch.

### Linux

1. Launch Chowser
2. Click the menu icon → **"Set as Default Browser"** (or navigate to Settings → General)
3. Chowser runs `xdg-settings set default-url-scheme-handler http in.sreerams.chowser-electrobun`

You can also verify/set manually:
```bash
xdg-settings set default-url-scheme-handler http in.sreerams.chowser-electrobun
xdg-settings set default-url-scheme-handler https in.sreerams.chowser-electrobun
```

## Routing Rules

Rules are evaluated **top-to-bottom** — the first match wins.

Each rule can match on:

| Field | Example | Notes |
|---|---|---|
| Host pattern (glob) | `*.github.com`, `github.com`, `**google.com` | Glob wildcards: `*` matches one segment, `**` matches multiple |
| Path prefix | `/api`, `/docs` | URL path must start with this string |
| Source app | `com.tinyspeck.slackmacgap` | macOS only; links originating from this app |

### Creating Rules

- **In the picker:** Press `R` while a URL is displayed → create a rule on-the-fly with the current URL pre-filled
- **In Settings:** Go to **Rules** → **Add Rule** → configure and save
- **Via import:** Load rules from a JSON file (Settings → General → Import)

### Example

```json
{
  "rules": [
    {
      "id": "github-work",
      "name": "GitHub → Chrome Work",
      "hostPattern": "*.github.com",
      "pathPrefix": "",
      "sourceAppBundleId": "",
      "browserAppId": "com.google.Chrome",
      "profile": "Profile 1",
      "isEnabled": true,
      "usePrivateMode": false,
      "useRegex": false
    },
    {
      "id": "hacker-news-firefox",
      "name": "Hacker News → Firefox",
      "hostPattern": "news.ycombinator.com",
      "pathPrefix": "",
      "sourceAppBundleId": "",
      "browserAppId": "org.mozilla.firefox",
      "profile": "",
      "isEnabled": true,
      "usePrivateMode": false,
      "useRegex": false
    }
  ]
}
```

## Browser Profiles

Chowser supports profiles for most modern browsers:

- **Chromium-based** (Chrome, Brave, Edge, Vivaldi, Arc, Dia): profiles are opened via `--profile-directory`
- **Firefox-based** (Firefox, Zen, LibreWolf, Waterfox): profiles are opened via `-P` or `--ProfileManager`

### Auto-Discovery

1. Go to **Settings → Browsers**
2. Click **🔍 Detect Installed Browsers**
3. All installed browsers and their profiles appear
4. Select which profiles to use in Chowser

### Manual Addition

If auto-discovery misses a browser:

1. In **Settings → Browsers** → **Add Browser**
2. Enter the app identifier (e.g., `com.google.Chrome`)
3. Enter the profile name or leave blank for the default profile

## Import / Export

Back up or restore your entire browser and routing configuration as JSON.

**Export:**
1. Settings → General → **Export Config**
2. Save the `.json` file

**Import:**
1. Settings → General → **Import Config**
2. Select a previously-exported `.json` file
3. Chowser merges the imported browsers and rules with existing config

### JSON Structure

```json
{
  "browsers": [
    {
      "id": "unique-id-1",
      "name": "Chrome Work",
      "appId": "com.google.Chrome",
      "shortcutKey": "1",
      "profile": "Profile 1"
    },
    {
      "id": "unique-id-2",
      "name": "Firefox Personal",
      "appId": "org.mozilla.firefox",
      "shortcutKey": "2",
      "profile": "Default"
    }
  ],
  "rules": [
    {
      "id": "unique-rule-id",
      "name": "Work repos → Chrome",
      "hostPattern": "*.github.company.com",
      "pathPrefix": "",
      "sourceAppBundleId": "",
      "browserAppId": "com.google.Chrome",
      "profile": "Profile 1",
      "isEnabled": true,
      "usePrivateMode": false,
      "useRegex": false
    }
  ]
}
```

## Domain Frequency Tracking

Chowser tracks which browser you open each domain in. After you click the same domain **30 times** in the same browser, Chowser suggests creating an automatic routing rule.

- Accept the suggestion → rule is created and applied immediately
- Dismiss → reminder won't appear again until the click count resets
- Suggestions appear in the Settings window

## URL Unshortening

Chowser can expand shortlinks (bit.ly, tinyurl, etc.) and strip tracking parameters before routing:

- **Automatic:** Chowser attempts to resolve known shortlink formats
- **Manual:** In the picker, press `H` to manually resolve a shortlink
- Configure in **Settings → General** whether to auto-unshorten on every URL

## Clipboard URL

Quickly open URLs stored in your clipboard:

1. Copy a URL to your clipboard
2. Click the Chowser tray icon → **"Open Clipboard URL"**
3. The picker appears with the clipboard URL pre-loaded
4. Select a browser or let routing rules handle it

## MCP Server

Chowser exposes a REST API for AI-driven management and automation (localhost:24245):

**Enable/disable:** Settings → General → **MCP Server** toggle

### API Endpoints

#### Get Status
```
GET /status
→ { "status": "running", "port": 24245 }
```

#### List Browsers
```
GET /browsers
→ [ { "id": "...", "name": "Chrome", "appId": "com.google.Chrome", ... }, ... ]
```

#### Add Browser
```
POST /browsers
Body: { "name": "Firefox", "appId": "org.mozilla.firefox", "profile": "" }
→ { "id": "...", "name": "Firefox", ... }
```

#### Delete Browser
```
DELETE /browsers/{id}
→ { "success": true }
```

#### List Rules
```
GET /rules
→ [ { "id": "...", "name": "GitHub → Chrome", ... }, ... ]
```

#### Add Rule
```
POST /rules
Body: { "name": "GitHub → Chrome", "hostPattern": "*.github.com", "browserAppId": "com.google.Chrome", ... }
→ { "id": "...", "name": "GitHub → Chrome", ... }
```

#### Delete Rule
```
DELETE /rules/{id}
→ { "success": true }
```

The MCP Server is useful for:
- Programmatic browser/rule management from external tools
- AI agents that need to configure Chowser based on user preferences
- Integration with workflow automation

## Platform-Specific Configuration Paths

Chowser stores its configuration at:

| Platform | Path |
|---|---|
| **macOS** | `~/Library/Application Support/in.sreerams.chowser-electrobun/state.json` |
| **Windows** | `%APPDATA%\in.sreerams.chowser-electrobun\state.json` |
| **Linux** | `~/.config/in.sreerams.chowser-electrobun/state.json` |

You can manually edit these JSON files (when Chowser is not running) to adjust browsers, rules, and settings.

### Launch at Login Paths

| Platform | Mechanism |
|---|---|
| **macOS** | LaunchAgent: `~/Library/LaunchAgents/in.sreerams.chowser-electrobun.plist` |
| **Windows** | Registry: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run` |
| **Linux** | Desktop file: `~/.config/autostart/in.sreerams.chowser-electrobun.desktop` |

## Known Limitations / Parity Gaps

### Cross-Platform

- **Shift-to-force-picker is unavailable** because the Electrobun `open-url` event does not expose keyboard modifier flags. You must use the picker normally or rely on routing rules.

### Windows/Linux Only

- **Source-app routing (macOS feature)** is disabled on Windows and Linux. The `sourceAppBundleId` field in rules is unused. URL interception on these platforms doesn't expose the originating app reliably at the OS level.

### All Platforms

- **Launch at login** persists the preference but may require manual verification in system settings to ensure the app launches on boot (varies by OS and security policy).

## Picker Keyboard Shortcuts

| Key | Action |
|---|---|
| `1`–`9` | Open in browser at that position |
| First letter | Open in first browser starting with that letter |
| `↑` / `↓` | Navigate between browsers |
| `Return` | Open in selected browser |
| `P` | Toggle private/incognito mode |
| `R` | Quick rule creation (pre-fills current URL) |
| `H` | Manually unshorten/resolve the current URL |
| `Esc` | Close picker without opening |

## Testing

```bash
# Unit tests (Bun)
npm run test

# Type checking
npx tsc --noEmit

# E2E tests (Playwright)
npm run test:e2e
```

## Regression Checklist

Before release, verify:

```bash
# Type safety
npx tsc --noEmit

# Build for all platforms
npm run build           # macOS
npm run build:windows   # Windows
npm run build:linux     # Linux

# Run tests
npm run test
npm run test:e2e
```

**Manual smoke test:**

- Picker opens on intercepted URL
- Keyboard shortcuts work (`1`–`9`, `P`, `R`, `H`)
- Settings CRUD works (add/edit/delete browsers and rules)
- Import/export preserves config after relaunch
- Routing rules apply correctly (first match wins)
- Domain frequency tracking suggests rules after ~30 clicks
- Clipboard URL feature works
- MCP server (if enabled) responds to requests

## Differences from the Swift & Tauri Versions

| Feature | Swift (native macOS) | Tauri (Rust) | Electrobun (this) |
|---|---|---|---|
| Language | Swift + SwiftUI | Rust + JS | TypeScript (Bun) |
| Platforms | macOS only | macOS, Windows, Linux | macOS, Windows, Linux |
| URL interception | Apple Events | System Events | Electrobun `open-url` event |
| UI toolkit | SwiftUI | HTML/Tauri | HTML/Svelte + Electrobun Webview |
| Browser profiles | Full support | Full support | Full support |
| Source-app routing | Yes (native) | Yes | macOS only (OS limitation) |
| Domain frequency | Yes | Yes | Yes |
| URL unshortening | Yes | Yes | Yes |
| Clipboard URL | Yes | Yes | Yes |
| MCP Server | Yes | No | Yes |
| Bundle size | ~5 MB | ~20 MB | ~15 MB |
| Build complexity | Medium | High | Low |
| Startup time | <100 ms | ~200 ms | ~150 ms |

## License

MIT — see [LICENSE](LICENSE) for details.

## Support & Contributing

- **Issues & Feature Requests:** [GitHub Issues](https://github.com/bsreeram08/chowser/issues)
- **Documentation & Setup:** [chowser.sreerams.in](https://chowser.sreerams.in)

