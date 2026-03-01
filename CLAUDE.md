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
./scripts/release.sh 2.8.0
```

CI runs on `v*` tag push via `.github/workflows/release.yml` (unsigned build, auto-publishes DMG to GitHub Releases).

## Architecture

**Chowser** is a macOS menu-bar-only app (`LSUIElement`) that intercepts HTTP/HTTPS links and routes them to configured browsers.

### Flow
1. On first launch, `AppDelegate` checks `OnboardingManager.hasCompletedOnboarding` — if false, shows the onboarding wizard before setting up the status bar
2. Apple Event handler (`handleGetURLEvent`) is registered in `applicationWillFinishLaunching` (before Cocoa's default handler) — extracts source app via `keyAddressAttr` → PID → bundle ID
3. macOS calls `application(_:open:)` in `AppDelegate` when a link is clicked anywhere
4. `BrowserManager.resolvedRoute(for:)` checks routing rules top-to-bottom (host pattern + path prefix + source app matching)
5. If a rule matches → opens directly via `BrowserManager.open()` (with optional private mode); otherwise → shows the picker panel
6. Picker (`ContentView`) lets user choose; keyboard shortcuts `1`-`9`, initials, `P` for private mode, `R` for quick rule creation, or arrow keys work
7. User can also open clipboard URLs or create routing rules directly from the picker

### Key files
- **`AppDelegate.swift`** — Menu bar setup, Apple Event handler (registered in `applicationWillFinishLaunching`), URL interception with source-app tracking, picker/settings/onboarding window lifecycle, clipboard URL handling. The picker is a `ChowserPanel` (custom `NSPanel` subclass) so it appears over full-screen apps without a Space switch.
- **`BrowserManager.swift`** — `@MainActor @Observable` singleton. Owns `[BrowserConfig]` and `[BrowserRoutingRule]`, persisted via `UserDefaults` with debounced writes. Handles routing resolution (host + path + source app matching), browser launching (uses `/usr/bin/open -n` for profile-aware Chromium/Firefox launches), private/incognito mode, import/export JSON, installed browser detection, and domain frequency tracking.
- **`AppEnvironment.swift`** — Process argument flags for UI testing (e.g. `-UITesting`, `-UITesting_MockInstalledBrowsers`). All test isolation goes here.
- **`ContentView.swift`** — Picker UI (SwiftUI, hosted in the NSPanel). Includes private mode toggle, in-picker rule creation, clipboard URL display.
- **`SettingsView.swift`** — Settings container with `NavigationSplitView` sidebar. Decomposed into extensions: `SettingsView+Browsers.swift` (browser list), `SettingsView+Rules.swift` (rule list), `SettingsView+General.swift` (general settings, hidden apps, about). Row views: `BrowserConfigRow.swift`, `RuleRowView.swift`. Sheets: `AddBrowserSheet.swift`, `AddRuleSheet.swift`.
- **`BrowserProfileDetector.swift`** — Reads Chromium `Local State` JSON and Firefox `profiles.ini` to discover profiles. Cached per process; cleared when Settings opens.
- **`AppMetadataCache.swift`** — Process-lifetime cache for app icons, display names, and URLs (avoids repeated NSWorkspace/Bundle I/O).
- **`DomainFrequencyTracker.swift`** — Records domain→browser click frequency; suggests auto-routing rules when a domain reaches 30 clicks.
- **`PickerViewModifiers.swift`** — Three-tier picker background: macOS 26+ glass effect → `ultraThinMaterial` fallback → solid for reduced-transparency.
- **`ConfigureRuleView.swift`** — Compact in-picker rule creation sheet; auto-prefills host from intercepted URL.
- **`UI/Onboarding/OnboardingManager.swift`** — Manages onboarding state and activation policy switching (`.accessory` ↔ `.regular`) for the onboarding window.
- **`UI/Onboarding/OnboardingView.swift`** — Multi-step onboarding wizard (Welcome → Default Browser → Browsers → Rules → Finish).

### Patterns
- Settings window is **not** a SwiftUI `Settings` scene — it's an `NSWindowController` wrapping `NSHostingController<SettingsView>`. This avoids SwiftUI auto-presenting the window on app activation.
- `AppDelegate` intentionally does **not** implement `applicationShouldHandleReopen` (would race with URL-open events).
- Browser launching with profiles uses `Process` + `/usr/bin/open -n -a` rather than `NSWorkspace.openApplication`, because Chromium hands off to existing processes and drops `--profile-directory` in the handoff path.
- `UserDefaults` suite is overridden to `in.sreerams.Chowser.UITests` during UI tests to isolate state.
- UserDefaults writes for browsers and rules are **debounced at 0.3s** via `DispatchWorkItem` to avoid I/O stutter during drag-to-reorder.
- `AppMetadataCache` provides process-lifetime caching of app icons, names, and URLs to avoid repeated NSWorkspace/Bundle filesystem lookups.
- Onboarding temporarily switches activation policy from `.accessory` to `.regular` (showing a Dock icon) so the onboarding window gets proper focus, then switches back to `.accessory`.
- `PickerViewModifiers` uses a three-tier rendering strategy: macOS 26+ `.glassEffect` → `ultraThinMaterial` fallback → solid background for reduced-transparency accessibility.
- Row views (`BrowserConfigRow`, `RuleRowView`) use local `@State` with commit-on-blur to avoid full-list re-renders during typing.
