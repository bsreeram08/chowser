# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Direct-download build (unsandboxed, includes Sparkle)
xcodebuild -project Chowser.xcodeproj -scheme Chowser-osp -configuration Release build

# Unit tests
xcodebuild test -project Chowser.xcodeproj -scheme Chowser-osp -destination 'platform=macOS' -only-testing:ChowserTests

# UI tests
xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS'

# App Store build (uses the sandboxed ChowserAppStore target)
xcodebuild archive -project Chowser.xcodeproj -scheme Chowser-appstore -configuration Release \
  -archivePath release/Chowser-appstore.xcarchive
```

### CI/CD Pipelines

- **`.github/workflows/deploy-docs.yml`** — Verifies signed hosted catalogs, builds the docs site, and deploys to GitHub Pages on eligible `main` pushes.
- **`.github/workflows/release-macos.yml`** — Tag-driven direct-download release. Requires all signing, notarization, and Sparkle secrets; publishes a verified DMG and signed appcast.

## Architecture

**Chowser** is a macOS menu-bar-only app (`LSUIElement`) that intercepts HTTP/HTTPS links and routes them to configured browsers.

### Flow

1. On first launch, `AppDelegate` checks `OnboardingManager.hasCompletedOnboarding` — if false, shows the onboarding wizard before setting up the status bar
2. Apple Event handler (`handleGetURLEvent`) is registered in `applicationWillFinishLaunching` (before Cocoa's default handler) — extracts source app via `keyAddressAttr` → PID → bundle ID
3. macOS calls `application(_:open:)` in `AppDelegate` when a link is clicked anywhere
4. Chowser applies enabled URL rewrites, optional shortlink resolution, and tracking cleanup before deciding where to open the link
5. Destination precedence is Shift-forced picker → explicit/focus browser route → approved native app → configured browser fallback → picker; private-mode requests skip native apps
6. Native-app routing uses the verified signed directory, exact per-app behavior approval, and a handler bundle-ID check immediately before launch
7. Picker (`ContentView`) lets user choose; keyboard shortcuts `1`-`9`, initials, `P` for private mode, `R` for quick rule creation, or arrow keys work
8. User can also open clipboard URLs or create routing rules directly from the picker

### Key files

- **`AppDelegate.swift`** — Menu bar setup, Apple Event handler (registered in `applicationWillFinishLaunching`), URL interception with source-app tracking, picker/settings/onboarding window lifecycle, clipboard URL handling, `chowser://import` URL scheme handler, MCP server toggle. The picker is a `ChowserPanel` (custom `NSPanel` subclass) so it appears over full-screen apps without a Space switch.
- **`BrowserManager.swift`** — `@MainActor @Observable` singleton. Owns `[BrowserConfig]` and `[BrowserRoutingRule]`, persisted via `UserDefaults` with debounced writes. Handles routing resolution (host + path + source app matching), browser launching (uses `/usr/bin/open -n` for profile-aware Chromium/Firefox launches), private/incognito mode, import/export JSON (with merge-on-import for both rules and browsers), installed browser detection, domain frequency tracking, and picker layout preferences.
- **`MCPServer.swift`** — `@MainActor @Observable` lightweight local HTTP API server (localhost-only, port 24245) for AI-driven management of browsers and routing rules. Provides REST endpoints: `GET/POST/DELETE /browsers`, `GET/POST/DELETE /rules`, `GET /status`. Start/stop from the menu bar.
- **`AppEnvironment.swift`** — Process argument flags for UI testing (e.g. `-UITesting`, `-UITesting_MockInstalledBrowsers`). All test isolation goes here.
- **`ContentView.swift`** — Picker UI (SwiftUI, hosted in the NSPanel). Supports two layout modes: "icons" (horizontal icon bar) and "list" (vertical list with full names and profiles). Includes private mode toggle, in-picker rule creation, clipboard URL display.
- **`SettingsView.swift`** — Settings container with `NavigationSplitView` sidebar. Decomposed into extensions: `SettingsView+Browsers.swift` (browser list), `SettingsView+Rules.swift` (rule list), `SettingsView+General.swift` (general settings, picker appearance, hidden apps, about). Row views: `BrowserConfigRow.swift`, `RuleRowView.swift`. Sheets: `AddBrowserSheet.swift`, `AddRuleSheet.swift`.
- **`BrowserProfileDetector.swift`** — Reads Chromium `Local State` JSON and Firefox `profiles.ini` to discover profiles. Cached per process; cleared when Settings opens.
- **`AppMetadataCache.swift`** — Process-lifetime cache for app icons, display names, and URLs (avoids repeated NSWorkspace/Bundle I/O).
- **`DomainFrequencyTracker.swift`** — Records domain→browser click frequency; suggests auto-routing rules when a domain reaches 30 clicks.
- **`PickerViewModifiers.swift`** — Three-tier picker background: macOS 26+ glass effect → `ultraThinMaterial` fallback → solid for reduced-transparency.
- **`ConfigureRuleView.swift`** — Compact in-picker rule creation sheet; auto-prefills host from intercepted URL.
- **`AppUpdateProviding.swift` / `AppUpdateController.swift`** — Direct-only app-owned update interface, Sparkle controller, and stable/beta policy. **`AppStoreUpdateProvider.swift`** is compiled only for the App Store handoff and contains no Sparkle behavior.
- **`HostedCatalogTrust.swift`** — Common pinned-key Ed25519 verification, bounded transport, rollback protection, and reverified last-known-good cache for hosted catalogs.
- **`NativeAppDirectory.swift` / `NativeAppDirectoryService.swift`** — Generic declarative native deep-link schema, semantic validation, per-app approval resolution, and macOS handler verification.
- **`UI/Onboarding/OnboardingManager.swift`** — Manages onboarding state and activation policy switching (`.accessory` ↔ `.regular`) for the onboarding window.
- **`UI/Onboarding/OnboardingView.swift`** — Multi-step onboarding wizard (Welcome → Default Browser → Browsers → Rules → Finish).
- **`Chowser.entitlements`** — Entitlements for direct download build (hardened runtime, no sandbox).
- **`ChowserAppStore.entitlements`** — Entitlements for App Store build (sandbox enabled, network client, user-selected file read-write).

### Patterns

- Settings window is **not** a SwiftUI `Settings` scene — it's an `NSWindowController` wrapping `NSHostingController<SettingsView>`. This avoids SwiftUI auto-presenting the window on app activation.
- `applicationShouldHandleReopen` may only schedule the cancellable deferred reopen in `AppDelegate`; URL-open handling must cancel it before routing.
- Browser launching with profiles uses `Process` + `/usr/bin/open -n -a` rather than `NSWorkspace.openApplication`, because Chromium hands off to existing processes and drops `--profile-directory` in the handoff path.
- `UserDefaults` suite is overridden to `in.sreerams.Chowser.UITests` during UI tests to isolate state.
- UserDefaults writes for browsers and rules are **debounced at 0.3s** via `DispatchWorkItem` to avoid I/O stutter during drag-to-reorder.
- `AppMetadataCache` provides process-lifetime caching of app icons, names, and URLs to avoid repeated NSWorkspace/Bundle filesystem lookups.
- Onboarding temporarily switches activation policy from `.accessory` to `.regular` (showing a Dock icon) so the onboarding window gets proper focus, then switches back to `.accessory`.
- `PickerViewModifiers` uses a three-tier rendering strategy: macOS 26+ `.glassEffect` → `ultraThinMaterial` fallback → solid background for reduced-transparency accessibility.
- Row views (`BrowserConfigRow`, `RuleRowView`) use local `@State` with commit-on-blur to avoid full-list re-renders during typing.

### Distribution & Updates

- **Direct download**: The `Chowser` target is unsandboxed, defines `DIRECT_DISTRIBUTION`, links Sparkle, and is published as a signed/notarized GitHub Release DMG.
- **App Store**: The `ChowserAppStore` target is sandboxed, defines `APP_STORE`, excludes Sparkle entirely, and receives updates only through the App Store/TestFlight.
- **Conditional compilation**: `#if APP_STORE` guards sandbox-incompatible browser launching. `#if DIRECT_DISTRIBUTION` guards Sparkle code and updater UI.
- **Release trigger**: Only an explicit `v<version>` or `v<version>-beta.<n>` tag starts the GitHub binary release workflow. A normal `main` push never publishes a release.
- **Version bumping**: Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Chowser.xcodeproj/project.pbxproj` before archiving.
- **Promo codes**: Generated in App Store Connect → Marketing → Promo Codes (up to 100 per version) for free distribution passes.
