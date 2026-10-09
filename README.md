<p align="center">
  <img src="docs/public/icon.png" alt="Chowser icon" width="128" height="128" />
</p>

# Chowser

Chowser is a macOS app that sits between your links and your browsers. Set it as your default browser, and every link you click opens in the browser and profile you chose for it.

[![Latest release](https://img.shields.io/github/v/release/bsreeram08/chowser)](https://github.com/bsreeram08/chowser/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**[Website](https://chowser.sreerams.in)** · **[Setup guide](https://chowser.sreerams.in/guide)** · **[Mac App Store](https://apps.apple.com/in/app/chowser/id6760034779)** · **[Direct download](https://github.com/bsreeram08/chowser/releases/latest)**

## How it works

1. Click a link in any app, such as a Slack message or an email.
2. Chowser checks your rules. A matching rule opens the link straight in its browser.
3. If nothing matches, a small picker appears. Press `1`–`9`, a browser's first letter, or Return.

## Install

Requires **macOS 14.0 or later**.

| | Direct download | Mac App Store |
|---|---|---|
| Install | [GitHub Releases](https://github.com/bsreeram08/chowser/releases/latest) (signed and notarized DMG) | [App Store](https://apps.apple.com/in/app/chowser/id6760034779) |
| Updates | Automatic, via Sparkle (optional beta channel) | Through the App Store |
| Browser profile launching | Full support | Limited: the sandbox strips launch arguments |
| Profile auto-detection | Yes | No |

If you want per-profile routing, use the direct download.

## Quick start

1. Open Chowser. The onboarding wizard walks you through choosing a default browser, adding browsers, and optional rules.
2. Add your browsers in **Settings → Browsers**. Chowser detects installed browsers and their profiles.
3. Add a routing rule in **Settings → Rules**, for example `github.com` → your work browser.
4. Click a link anywhere to test it.

Chowser runs from the menu bar by default. To use a regular Dock app instead, change **Settings → General → App Mode**.

## Features

**Routing**

- **Rules by host, path, and source app.** Send `github.com` to one browser, or Slack links to a work profile. Wildcards are supported.
- **Per-profile launching** for Chromium and Firefox-family browsers (Chrome, Brave, Edge, Vivaldi, Arc, Dia, Firefox, Zen, LibreWolf, Waterfox, and more).
- **Fallback routing.** Send unmatched links to a chosen browser instead of showing the picker.
- **Focus mode.** From the menu bar, send all links to one browser for 1 hour or until tomorrow.
- **Private mode.** Press `P` in the picker, or set a per-rule private-mode toggle.
- **Suggested rules.** Chowser suggests a rule after you open the same domain in the same browser 30 times.

**Picker**

- Icon bar, list, radial, and minimal layouts. Appearance settings control size, tint, transparency, and color scheme.
- Keyboard-first: shortcuts are listed in the [table below](#picker-shortcuts).
- Link preview shows the page title and image before you choose. It is off by default because it contacts the network (see [Privacy](#privacy)).
- Edit the URL in the picker before opening it, for one-off fixes.

**Links**

- **URL rewrites.** Strip tracking parameters, force HTTPS, replace hosts, or edit query parameters. A live tester shows what changed.
- **Shortlink resolution.** Resolve shortened links to their destination before routing. Press `H` in the picker to resolve one manually.
- **Hosted rewrite catalog.** Review and add maintained starter rules from Settings → Rewrites. Nothing is installed without your review, and your own rules are never overwritten.
- **Native app links.** Open supported web links in an installed app, such as Spotify. Apps come from a signed directory, and each app is off until you approve it. Chowser checks the registered handler right before it opens the app.
- **Send to phone.** Share the current link by AirDrop, QR code, or copy. Handoff is used when available.
- **Clipboard URL.** Open a link from the clipboard via the menu bar.

**Management**

- Import and export browsers and rules as JSON. Imports merge with your existing setup.
- Hide non-browser apps that register as web handlers, and launch at login.
- Diagnostics in **Settings → General → About**. Logs record routing decisions but never visited hostnames or local file paths, so they are safe to attach to a bug report.

## Picker shortcuts

| Key | Action |
|---|---|
| `1`–`9` | Open the browser with that number |
| Browser initial | Select that browser |
| `↑` `↓` then Return | Select and open |
| `P` | Toggle private mode |
| `R` | Create a routing rule for this link |
| `E` | Edit the URL |
| `H` | Resolve a shortlink |
| `I` | Send to phone |
| `Cmd`+`C` | Copy the URL |
| `?` | Show all shortcuts |
| `Esc` | Dismiss |

Hold `Shift` when a link arrives to force the picker, even when a rule matches.

## Local API for AI agents

Chowser includes an optional HTTP API on `localhost:24245` that lets an AI assistant read and change your browsers, rules, rewrites, and settings. It is off until you start it.

- **Start or stop:** from the menu bar, or headlessly with `chowser://mcp/start` and `chowser://mcp/stop`.
- **Authentication:** every request needs the bearer token shown in **Settings → General**.
- **Endpoints:** `GET /status`, `GET` / `POST` / `DELETE` on `/browsers`, `/rules`, and `/rewrites`, `POST /browsers/preview` (dry-run a launch command), and `GET` / `POST /settings`.

```bash
curl -H "Authorization: Bearer $CHOWSER_TOKEN" http://localhost:24245/status
```

The server only listens on your Mac. It is not reachable from the network.

## Privacy

- Shortlink resolution and link preview make network requests, so both are **off by default**. Turn them on in **Settings → Behavior**.
- Rewrite catalogs and native-app directories are signed (Ed25519) and verified against a public key pinned in the app. Chowser downloads the catalog files only. The URLs you click are never sent to the catalog host.

## Build from source

Requires Xcode (CI builds with Xcode 26.3).

```bash
git clone https://github.com/bsreeram08/chowser.git
cd chowser
open Chowser.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project Chowser.xcodeproj \
  -scheme Chowser-osp \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO

open build/Build/Products/Release/Chowser.app
```

Local builds run unsandboxed, so profile launching works. The in-app updater stays disabled unless you pass `SPARKLE_PUBLIC_ED_KEY` at build time.

To build the sandboxed App Store variant, use the `Chowser-appstore` scheme.

## Testing

```bash
xcodebuild test -project Chowser.xcodeproj -scheme Chowser-osp -destination 'platform=macOS' -only-testing:ChowserTests   # unit
xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS'                           # UI
```

## Project layout

- `Chowser/`: app source. `AppDelegate.swift` handles link interception, `BrowserManager.swift` owns routing, and `ContentView.swift` is the picker.
- `CLAUDE.md`: architecture notes. `docs/` holds the website and [architecture decision records](docs/adr).
- `scripts/`: release, signing, and distribution helpers.

## Releasing (maintainers)

1. Add a `## [x.y.z] - YYYY-MM-DD` section to `CHANGELOG.md`.
2. Prepare the release. This bumps the version and build number, runs the unit tests, and builds and verifies both the direct and App Store products:

   ```bash
   SPARKLE_PUBLIC_ED_KEY=<public-key> scripts/release.sh x.y.z
   ```

3. Commit the version and changelog change, then merge it to `main`.
4. Tag the merged commit and push the tag:

   ```bash
   git tag -s vx.y.z -m "Chowser vx.y.z"
   git push origin vx.y.z
   ```

The tag starts `.github/workflows/release-macos.yml`. CI builds, signs, notarizes, and publishes the DMG to GitHub Releases, along with the signed Sparkle appcast. Use `x.y.z-beta.n` for beta builds.

## Contributing

Open an issue before starting a large change. Run the unit tests and build both `Chowser-osp` and `Chowser-appstore` before opening a pull request.

## License

MIT. See [LICENSE](LICENSE).
