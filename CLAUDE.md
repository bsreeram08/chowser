# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build
xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build

# Unit tests
xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests

# UI tests
xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS'

# Release (bumps version, builds, creates DMG, tags git)
./scripts/release.sh 2.6.0
```

CI runs on `v*` tag push via `.github/workflows/release.yml` (unsigned build, auto-publishes DMG to GitHub Releases).

## Architecture

**Chowser** is a macOS menu-bar-only app (`LSUIElement`) that intercepts HTTP/HTTPS links and routes them to configured browsers.

### Flow
1. macOS calls `application(_:open:)` in `AppDelegate` when a link is clicked anywhere
2. `BrowserManager.resolvedRoute(for:)` checks routing rules (host pattern + path prefix matching)
3. If a rule matches → opens directly via `BrowserManager.open()`; otherwise → shows the picker panel
4. Picker (`ContentView`) lets user choose; keyboard shortcuts `1`-`9`, initials, or arrow keys work

### Key files
- **`AppDelegate.swift`** — Menu bar setup, URL interception, picker/settings window lifecycle. The picker is a `ChowserPanel` (custom `NSPanel` subclass) so it appears over full-screen apps without a Space switch.
- **`BrowserManager.swift`** — `@MainActor @Observable` singleton. Owns `[BrowserConfig]` and `[BrowserRoutingRule]`, persisted via `UserDefaults`. Handles browser launching (uses `/usr/bin/open -n` for profile-aware Chromium/Firefox launches), import/export JSON, and installed browser detection.
- **`AppEnvironment.swift`** — Process argument flags for UI testing (e.g. `-UITesting`, `-UITesting_MockInstalledBrowsers`). All test isolation goes here.
- **`ContentView.swift`** — Picker UI (SwiftUI, hosted in the NSPanel).
- **`SettingsView.swift`** — Settings UI (SwiftUI, hosted in a plain `NSWindow` managed by AppDelegate).
- **`BrowserProfileDetector.swift`** — Reads Chromium `Local State` JSON and Firefox `profiles.ini` to discover profiles.

### Patterns
- Settings window is **not** a SwiftUI `Settings` scene — it's an `NSWindowController` wrapping `NSHostingController<SettingsView>`. This avoids SwiftUI auto-presenting the window on app activation.
- `AppDelegate` intentionally does **not** implement `applicationShouldHandleReopen` (would race with URL-open events).
- Browser launching with profiles uses `Process` + `/usr/bin/open -n -a` rather than `NSWorkspace.openApplication`, because Chromium hands off to existing processes and drops `--profile-directory` in the handoff path.
- `UserDefaults` suite is overridden to `in.sreerams.Chowser.UITests` during UI tests to isolate state.
