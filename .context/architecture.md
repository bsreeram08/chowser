<!-- Last verified: 2026-02-28 against commit 892fcaf -->

# Architecture

Chowser is a macOS menu-bar-only app (`LSUIElement`) that intercepts HTTP/HTTPS links system-wide and routes them to user-configured browsers. It has no Dock icon and uses zero resources when idle.

## Component Overview

```
┌─────────────────────────────────────────────────────┐
│                     macOS                            │
│  (Link clicked in any app → Apple Event)            │
└──────────────────┬──────────────────────────────────┘
                   │ kInternetEventClass / kAEGetURL
                   ▼
┌──────────────────────────────────────────────────────┐
│  AppDelegate                                         │
│  ├─ Apple Event handler (registered in               │
│  │   applicationWillFinishLaunching)                  │
│  ├─ Source app extraction (keyAddressAttr → PID)      │
│  ├─ Status bar menu management                        │
│  ├─ Window lifecycle (picker panel, settings window)  │
│  └─ Onboarding check on first launch (OnboardingManager)│
└──────────┬──────────────┬────────────────────────────┘
           │              │
           ▼              ▼
┌──────────────┐  ┌────────────────────┐
│ Picker Panel │  │  Settings Window   │
│ (ChowserPanel│  │ (NSWindowController│
│  = NSPanel)  │  │  + NSHostingCtrl)  │
│              │  │                    │
│ ContentView  │  │ SettingsView       │
│  + Configure │  │  +Browsers         │
│    RuleView  │  │  +Rules            │
│              │  │  +General          │
└──────┬───────┘  └────────┬───────────┘
       │                   │
       ▼                   ▼
┌──────────────────────────────────────────────────────┐
│  BrowserManager (@MainActor @Observable singleton)    │
│  ├─ configuredBrowsers: [BrowserConfig]               │
│  ├─ routingRules: [BrowserRoutingRule]                 │
│  ├─ resolvedRoute(for:) → rule matching               │
│  ├─ open() → browser launch via Process + /usr/bin/open│
│  ├─ import/export JSON                                │
│  └─ debounced UserDefaults persistence                │
└──────────┬──────────────┬────────────────────────────┘
           │              │
           ▼              ▼
┌────────────────┐  ┌─────────────────────┐
│ BrowserProfile │  │ DomainFrequency     │
│ Detector       │  │ Tracker             │
│ (Chromium JSON │  │ (domain→browser     │
│  + Firefox INI)│  │  click counting)    │
└────────────────┘  └─────────────────────┘
```

## URL Handling Flow (Detail)

1. **Apple Event registration** — `AppDelegate.applicationWillFinishLaunching` registers `handleGetURLEvent` for `kInternetEventClass`/`kAEGetURL` before Cocoa's default handler
2. **Event received** — `handleGetURLEvent` extracts URL string from `keyDirectObject` and source app PID from `keyAddressAttr`, converts to `NSRunningApplication.bundleIdentifier`
3. **URL dispatch** — `application(_:open:)` is called with the URLs
4. **`isHandlingURL` flag** set to `true`, reset after 1.0s delay (prevents recursive open calls)
5. **Route check** — `BrowserManager.resolvedRoute(for:)` evaluates rules top-to-bottom: enabled → host pattern → path prefix → source app → browser exists
6. **Match found** → `BrowserManager.open()` launches browser directly (no picker shown)
7. **No match** → Picker panel (`ChowserPanel`) appears with browser list
8. **User chooses** → browser launches; `DomainFrequencyTracker.record()` logs the choice
9. **Panel dismissed** — auto-closes after launch or on Escape

## File Map

### Core Application

| File | Responsibility |
|------|---------------|
| `ChowserApp.swift` | `@main` entry point; `NSApplicationDelegateAdaptor` bridge; placeholder `Settings` scene |
| `AppDelegate.swift` | Menu bar setup, Apple Event handler, picker/settings window lifecycle, clipboard URL, onboarding gate |
| `BrowserManager.swift` | Observable singleton; browser/rule CRUD, routing resolution, browser launch, import/export, UserDefaults persistence |
| `AppEnvironment.swift` | Process argument flags for UI test isolation (`-UITesting`, `-UITesting_MockInstalledBrowsers`, etc.) |
| `BrowserProfileDetector.swift` | Detects profiles for Chromium (Chrome, Brave, Edge, Vivaldi, Arc, Dia) and Firefox-based (Firefox, Zen) browsers by reading application support data. |
| `AppMetadataCache.swift` | Process-lifetime cache for app icons, display names, and URLs (avoids repeated NSWorkspace/Bundle I/O) |
| `DomainFrequencyTracker.swift` | Records domain→browser click frequency; suggests auto-routing rules at threshold (30 clicks) |

### Picker UI

| File | Responsibility |
|------|---------------|
| `ContentView.swift` | Picker surface: browser grid, keyboard navigation (1-9, initials, arrows, Tab), private mode toggle, copy URL, in-picker rule creation |
| `ConfigureRuleView.swift` | Compact rule-creation sheet shown inside the picker; auto-prefills host from intercepted URL |
| `PickerViewModifiers.swift` | Three-tier background rendering: macOS 26+ glass effect → `ultraThinMaterial` fallback → solid for reduced-transparency |

### Settings UI

| File | Responsibility |
|------|---------------|
| `SettingsView.swift` | Main settings container with `NavigationSplitView` sidebar (Browsers, Rules, Apps, General tabs) |
| `SettingsView+Browsers.swift` | Browser list management: add/remove/reorder, search filter, import/export, drag-and-drop |
| `SettingsView+Rules.swift` | Routing rules list: add/remove/reorder/duplicate, enable/disable, search filter, import/export |
| `SettingsView+General.swift` | General settings: launch at login, default browser status, reset, replay onboarding, hidden apps, about |
| `AddBrowserSheet.swift` | Modal sheet: Installed Apps tab (search/filter/hidden toggle) + Custom App tab (manual entry with app picker) |
| `AddRuleSheet.swift` | Modal sheet: full rule creation form (host, path, browser, source app, private mode) |
| `BrowserConfigRow.swift` | Editable row for a single browser config; commit-on-blur editing; Equatable for list performance |
| `RuleRowView.swift` | Editable row for a single routing rule; commit-on-blur editing; Equatable; callback-driven mutations |
| `EditBrowserSheet.swift` | Modal sheet for editing an existing browser config (name, custom arguments) |
| `EditRuleSheet.swift` | Modal sheet for editing an existing routing rule (host, path, browser, source app, private mode) |

### Onboarding

| File | Responsibility |
|------|---------------|
| `UI/Onboarding/OnboardingManager.swift` | Singleton managing onboarding state, activation policy switching (.accessory ↔ .regular), window lifecycle |
| `UI/Onboarding/OnboardingView.swift` | Multi-step onboarding container with animated step transitions |
| `UI/Onboarding/OnboardingSteps.swift` | Individual step views: Welcome → Default Browser → Browsers → Rules → Finish |

### Tests

| File | Responsibility |
|------|---------------|
| `ChowserTests/BrowserManagerTests.swift` | Unit tests for BrowserManager (persistence, browser CRUD, routing, shortcut keys) |
| `ChowserTests/BrowserConfigTests.swift` | Unit tests for BrowserConfig data model |
| `ChowserTests/BrowserProfileDetectorTests.swift` | Unit tests for profile detection logic |
| `ChowserTests/BrowserLaunchTests.swift` | Unit tests for browser launching with profiles and custom arguments |
| `ChowserUITests/ChowserUITests.swift` | End-to-end UI tests for picker, settings, and onboarding flows |

### Scripts

| File | Responsibility |
|------|---------------|
| `scripts/release.sh` | Version bump, archive build, DMG creation, git tagging |
| `scripts/generate-dmg-background.swift` | Generates styled DMG background image for releases |

## Data Models

### BrowserConfig
```
id: UUID
name: String                  — display name ("Chrome - Work")
bundleId: String              — e.g. "com.google.Chrome"
shortcutKey: String           — "1" through "9"
profile: String?              — Chromium profile dir or Firefox profile name
customArguments: String?      — CLI args with {profile} and {url} placeholders
identity: String (computed)   — "\(bundleId)|\(profile ?? "")" for dedup
```

### BrowserRoutingRule
```
id: UUID
name: String                  — display name ("Work GitHub")
hostPattern: String           — exact "github.com" or wildcard "*.github.com"
pathPrefix: String?           — e.g. "/my-company"
browserBundleId: String       — target browser bundle ID
profile: String?              — target browser profile
isEnabled: Bool               — default true
sourceAppBundleId: String?    — route only from this source app
usePrivateMode: Bool          — default false
```

### BrowserProfile
```
id: String    — profile directory name (Chromium) or profile name (Firefox)
name: String  — human-readable display name from Local State or profiles.ini
```

## Persistence

All state is persisted to `UserDefaults`:

| Key | Type | Content |
|-----|------|---------|
| `configuredBrowsers` | JSON Data | Encoded `[BrowserConfig]` |
| `routingRules` | JSON Data | Encoded `[BrowserRoutingRule]` |
| `hiddenBundleIDs` | JSON Data | Encoded `Set<String>` of hidden app bundle IDs |
| `onboardingCompleted` | Bool | Whether onboarding wizard has been finished |
| `DomainFrequencyStats` | JSON Data | `[String: [String: Int]]` domain→browser→count |
| `hasCompletedOnboarding` | Bool | Read by OnboardingManager (separate from BrowserManager's key) |

- **Suite override**: During UI tests, suite switches to `in.sreerams.Chowser.UITests`
- **Debounced writes**: Browser and rule saves are debounced at 0.3s via `DispatchWorkItem` to avoid rapid I/O during drag-reorder
- **Flush**: `flushPendingSaves()` cancels pending items and writes immediately (called before import/export operations)
