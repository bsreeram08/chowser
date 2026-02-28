# Chowser Multiplatform (Tauri)

`chowser-multiplatform` is now a Tauri-based desktop app that keeps the Rust routing/import core and provides a redesigned mac-like UI.

## What is implemented

- Tauri UI shell (HTML/CSS/JS) with consistent controls and onboarding flow
- Browser picker for unmatched URLs
- Rule-based auto-routing for matched URLs
- Legacy Swift Chowser JSON import compatibility
  - `ChowserBrowsers.json`
  - `ChowserRules.json`
- Browser discovery (macOS/Linux/Windows)
- macOS default-browser onboarding checks
  - Detect current `http`/`https` handler
  - Register app with Launch Services
  - Open System Settings to default-browser screen
- macOS URL event handling (`kAEGetURL`) so default-browser clicks are processed

## Build

```bash
cd chowser-multiplatform
cargo build
```

## Run

```bash
cargo run
```

Optional URL testing from CLI:

```bash
cargo run -- --url "https://example.com"
```

## macOS bundle build/install

```bash
cd chowser-multiplatform
./scripts/build-macos-app.sh
```

Then install:

```bash
mkdir -p "/Applications/Chowser Rust.app"
ditto "./dist/Chowser Rust.app" "/Applications/Chowser Rust.app"
```

Bundle ID is `in.sreerams.chowser-test`.

## How to test picker as default browser (macOS)

1. Open app and finish onboarding setup checks.
2. In System Settings, set `Chowser Rust` as the default browser.
3. Click a URL from another app.
4. Behavior:
   - Matching rule: auto-routes immediately.
   - No match: picker UI appears.

You can also reopen onboarding from the header (`Reopen Onboarding`) at any time.

## Config location

The active config path is shown in the UI header.

