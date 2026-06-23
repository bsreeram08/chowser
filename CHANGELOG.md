# Changelog

All notable changes to Chowser are documented here.

## [3.7.0] - 2026-06-23

### Added
- **Appearance settings page** — a dedicated Appearance section in Settings gathers all picker-look controls in one place with a **live preview that embeds the real picker** (clicking a browser in the preview opens a sample URL for real).
- Picker customization: **tint color**, **transparency**, **corner radius**, and an **accent color override**, plus the existing layout / icon-size / label controls. A backdrop switcher (Light / Dark / Color / Checker) shows how the picker looks over different backgrounds.
- **Clickable picker footer actions** — the P / H / R / Esc / ↵ hints are now real buttons, not just labels.
- **Browser engine badge** — browser rows show whether each browser is Chromium- or Firefox-based.
- Expanded browser detection to current-market browsers (Comet, Thorium, Helium, Wavebox, Sidekick, Whale, Yandex, Floorp, Mullvad, Basilisk, Pale Moon, Tor, and more).

### Fixed
- **Browsers settings page renders reliably** — it used a SwiftUI `List` that mis-laid-out inside `NavigationSplitView` (blank rows / collapsed sidebar until a window resize). Now uses the same `ScrollView` scaffold as the other settings pages.

### Notes
- **Browser profiles remain a direct-download-build feature.** macOS silently strips launch arguments (including `--profile-directory`) from sandboxed apps, so the App Store build cannot route to a specific browser profile. The Edit Browser sheet now states this clearly instead of failing silently. Per-profile routing works in the direct-download build.
- Accent-colored picker text (Launch, suggestions) stays legible — a brightness-aware accent prevents dark/black-on-dark.

### Changed
- Accent color across the picker now follows the user's accent override.
