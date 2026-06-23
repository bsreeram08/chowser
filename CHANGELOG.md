# Changelog

All notable changes to Chowser are documented here.

## [3.7.0] - 2026-06-23

### Added
- **Appearance settings page** — a dedicated Appearance section in Settings gathers all picker-look controls in one place with a **live preview that embeds the real picker** (clicking a browser in the preview opens a sample URL for real).
- Picker customization: **tint color**, **transparency**, **corner radius**, and an **accent color override**, plus the existing layout / icon-size / label controls. A backdrop switcher (Light / Dark / Color / Checker) shows how the picker looks over different backgrounds.
- **Running-state dimming** — browsers that aren't currently open are faded in the picker so you see what's already running at a glance (toggle in Appearance).
- **Color scheme override** — force the picker to Light or Dark, or follow the system.
- **Route links to native apps** — quick-add popular apps (Slack, Zoom, Figma, Notion, Linear, Spotify, Discord, Telegram, Teams, WhatsApp…) from Add Browser; one click adds the app and a rule sending its links straight to it instead of a browser.
- **Clickable picker footer actions** — the P / H / R / Esc / ↵ hints are now real buttons, not just labels.
- **Browser engine badge** — browser rows show whether each browser is Chromium- or Firefox-based.
- Expanded browser detection to current-market browsers (Comet, Thorium, Helium, Wavebox, Sidekick, Whale, Yandex, Floorp, Mullvad, Basilisk, Pale Moon, Tor, and more).
- **Per-browser launch arguments** — set a normal-launch and a separate **private/incognito** argument template per browser (with `{profile}`/`{url}` placeholders) in Edit Browser. Works for any browser, not just the built-in Chromium/Firefox defaults.
- **MCP launch API** — the local API accepts `profile`, `customArguments`, and `privateArguments`, and a new `POST /browsers/preview` dry-run returns the exact framed launch command so an AI agent can research a browser's flags, preview the command, and confirm before saving.

### Fixed
- **Browsers settings page renders reliably** — it used a SwiftUI `List` that mis-laid-out inside `NavigationSplitView` (blank rows / collapsed sidebar until a window resize). Now uses the same `ScrollView` scaffold as the other settings pages.
- Accent-colored picker text (Launch, suggestions) stays legible — a brightness-aware accent prevents dark/black-on-dark.

### Notes
- **Profiles/launch arguments apply at launch only in the direct-download build.** macOS strips launch arguments from sandboxed apps, so the App Store build stores them (and keeps them portable) but may not pass them to the browser. The Edit Browser sheet and MCP API both say so. Auto-detecting profiles also requires the direct build.

### Changed
- Accent color across the picker now follows the user's accent override.
