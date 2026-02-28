<!-- Last verified: 2026-02-28 against commit 892fcaf -->

# Quick Reference

Developer cheat sheet for building, testing, and navigating Chowser.

## Build & Test Commands

```bash
# Build (Release)
xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build

# Unit tests
xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests

# UI tests
xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS'

# Release (bumps version, builds, creates DMG, tags git)
./scripts/release.sh <version>
```

## Key Paths

| Path | Purpose |
|------|---------|
| `Chowser/AppDelegate.swift` | Entry point for URL handling, window lifecycle, menu bar |
| `Chowser/BrowserManager.swift` | Central data model and business logic |
| `Chowser/ContentView.swift` | Picker UI |
| `Chowser/SettingsView.swift` | Settings container (sidebar + tabs) |
| `Chowser/SettingsView+Browsers.swift` | Browser list management |
| `Chowser/SettingsView+Rules.swift` | Rule list management |
| `Chowser/SettingsView+General.swift` | General settings, hidden apps, about |
| `Chowser/AppEnvironment.swift` | UI test flags and defaults suite override |
| `Chowser/BrowserProfileDetector.swift` | Chromium/Firefox profile discovery |
| `Chowser/AppMetadataCache.swift` | Process-lifetime icon/name cache |
| `Chowser/DomainFrequencyTracker.swift` | Domain→browser frequency tracking |
| `Chowser/UI/Onboarding/` | Onboarding wizard (Manager, View, Steps) |
| `scripts/release.sh` | Release script (version bump + DMG) |
| `.github/workflows/release.yml` | CI: build + publish on tag push |

## UserDefaults Keys

| Key | Type | Owner |
|-----|------|-------|
| `configuredBrowsers` | JSON Data (`[BrowserConfig]`) | BrowserManager |
| `routingRules` | JSON Data (`[BrowserRoutingRule]`) | BrowserManager |
| `hiddenBundleIDs` | JSON Data (`Set<String>`) | BrowserManager |
| `onboardingCompleted` | Bool | BrowserManager |
| `hasCompletedOnboarding` | Bool | OnboardingManager |
| `DomainFrequencyStats` | JSON Data (`[String: [String: Int]]`) | DomainFrequencyTracker |

**UI test suite**: `in.sreerams.Chowser.UITests`

## UI Testing Flags

| Flag | Effect |
|------|--------|
| `-UITesting` | Enables test mode; switches UserDefaults suite; skips Apple Event handler |
| `-UITesting_ClearData` | Clears all persisted browsers and rules on launch |
| `-ResetToFreshSetup` | Same as `-UITesting_ClearData` |
| `-UITesting_OpenSettings` | Auto-opens settings window after 0.2s |
| `-UITesting_OpenPicker` | Auto-opens picker panel after 0.2s |
| `-UITesting_MockInstalledBrowsers` | Returns hardcoded mock browsers (Chrome, Firefox, Safari, Zen) |
| `-UITesting_DisableExternalOpen` | Prevents real browser launch; logs to `lastOpenedBrowserBundleIDForTesting` |
| `-UITesting_DisableSystemIntegration` | Skips SMAppService registration |
| `-UITesting_DefaultURL` | Sets `currentURL` to `https://example.com/ui-test` |

**Environment variable**: `CHOWSER_DEFAULTS_SUITE` overrides the UserDefaults suite name.

## Browser Support Matrix

| Browser | Bundle ID | Family | Profile Detection | Private Mode | Custom Args |
|---------|-----------|--------|-------------------|--------------|-------------|
| Google Chrome | `com.google.Chrome` | Chromium | `Local State` JSON | `--incognito` | Yes |
| Brave | `com.brave.Browser` | Chromium | `Local State` JSON | `--incognito` | Yes |
| Microsoft Edge | `com.microsoft.edgemac` | Chromium | `Local State` JSON | `--incognito` | Yes |
| Vivaldi | `com.vivaldi.Vivaldi` | Chromium | `Local State` JSON | `--incognito` | Yes |
| Arc | `company.thebrowser.Browser` | Chromium | `Local State` JSON* | `--incognito` | Yes |
| Dia | `company.thebrowser.Dia` | Chromium | `Local State` JSON | `--incognito` | Yes |
| Chromium | `org.chromium.Chromium` | Chromium | `Local State` JSON | `--incognito` | Yes |
| Opera | `com.operasoftware.Opera` | Chromium | — | `--incognito` | Yes |
| Firefox | `org.mozilla.firefox` | Firefox | `profiles.ini` | `-private` | Yes |
| Zen Browser | `app.zen-browser.zen` | Firefox | `profiles.ini` | `-private` | Yes |
| LibreWolf | `org.mozilla.librewolf` | Firefox | `profiles.ini` | `-private` | Yes |
| Waterfox | `net.waterfox.waterfox` | Firefox | `profiles.ini` | `-private` | Yes |
| Safari | `com.apple.Safari` | Other | — | — | — |
| Any other | varies | Other | — | — | Yes |

*Arc: profiles are detected but selection may not work reliably (see `gotchas.md` #6).

## Chromium Profile Locations

| Browser | Application Support path |
|---------|-------------------------|
| Chrome | `Google/Chrome/Local State` |
| Brave | `BraveSoftware/Brave-Browser/Local State` |
| Edge | `Microsoft Edge/Local State` |
| Vivaldi | `Vivaldi/Local State` |
| Arc | `Arc/User Data/Local State` |
| Dia | `Dia/User Data/Local State` |

**JSON path**: `json["profile"]["info_cache"][profileKey]["name"]`

## Firefox Profile Locations

| Browser | Application Support path |
|---------|-------------------------|
| Firefox | `Firefox/profiles.ini` |
| Zen | `Zen/profiles.ini` |

**INI structure**: `[Profile*]` sections, `Name=` for display name.

## Default Hidden Bundle IDs

```
com.mxtech.mxplayerforios
com.mxtech.videoplayer.pro
com.mxplayer.mac
com.rockysandstudio.MKPlayer
io.mpv
com.colliderli.iina
org.videolan.vlc
```

## Picker Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `1`–`9` (main + numpad) | Open browser by shortcut key |
| Letter key | Cycle through browsers starting with that letter |
| `P` | Toggle private / incognito mode |
| `R` | Open in-picker rule creation (if URL available) |
| `Tab` / `Shift+Tab` | Move selection forward / backward |
| `↑` `↓` `←` `→` | Move selection |
| `Return` / `Enter` / `Space` | Open selected browser |
| `Cmd+C` | Copy URL to clipboard |
| `Escape` | Close rule sheet (if open) or dismiss picker |
| `Option` + any open key | Open in private mode |

## Accessibility Identifiers

### Picker
| Identifier | Element |
|------------|---------|
| `picker.urlDisplay` | URL bubble |
| `picker.configureRuleButton` | Plus button (add rule) |
| `picker.browserRow` | Each browser icon |
| `picker.emptyState` | Empty state message |
| `picker.lastOpenedBrowser` | Hidden test label (UI testing only) |
| `picker.configureRule.nameField` | Rule name field (ConfigureRuleView) |
| `picker.configureRule.hostField` | Host pattern field |
| `picker.configureRule.browserPicker` | Browser picker |
| `picker.configureRule.cancelButton` | Cancel button |
| `picker.configureRule.saveButton` | Save button |

### Settings — Sidebar
| Identifier | Element |
|------------|---------|
| `settings.sidebar.browsers` | Browsers tab |
| `settings.sidebar.rules` | Rules tab |
| `settings.sidebar.apps` | Apps tab |
| `settings.sidebar.general` | General tab |

### Settings — Browsers
| Identifier | Element |
|------------|---------|
| `settings.browser.searchField` | Search filter |
| `settings.browserList` | Browser list |
| `settings.browser.nameField` | Browser name field |
| `settings.browser.shortcutPicker` | Shortcut key picker |
| `settings.browser.deleteButton` | Delete button |
| `settings.restoreDefaultButton` | Restore defaults |
| `settings.exportBrowsersButton` | Export menu item |
| `settings.importBrowsersButton` | Import menu item |

### Settings — Rules
| Identifier | Element |
|------------|---------|
| `settings.rule.searchField` | Search filter |
| `settings.rulesList` | Rules list |
| `settings.rule.nameField` | Rule name field |
| `settings.rule.hostField` | Host pattern field |
| `settings.rule.pathField` | Path prefix field |
| `settings.rule.browserPicker` | Browser picker |
| `settings.rule.deleteButton` | Delete button |
| `settings.exportRulesButton` | Export menu item |
| `settings.importRulesButton` | Import menu item |

### Settings — Add Sheets
| Identifier | Element |
|------------|---------|
| `settings.addSheet.option` | Installed browser option |
| `settings.addSheet.custom.nameField` | Custom app name |
| `settings.addSheet.custom.bundleIdField` | Custom app bundle ID |
| `settings.addSheet.custom.argsField` | Custom app arguments |
| `settings.addSheet.custom.addButton` | Add custom app button |
| `settings.addRule.nameField` | Rule name |
| `settings.addRule.hostField` | Host pattern |
| `settings.addRule.pathField` | Path prefix |
| `settings.addRule.browserPicker` | Browser picker |
| `settings.addRule.fillTestHostButton` | "Use example host" button |
| `settings.addRule.confirmButton` | Add rule button |
