# Draft: Chowser Electrobun Windows/Linux Release

## Requirements (confirmed)
- Feature parity with macOS Chowser (all features)
- Windows and Linux support
- UI quality matching iOS/macOS aesthetics

## Technical Decisions
- **Windows**: Windows 10+ with legacy consideration
- **Linux**: All major distros + AppImage/Flatpak for universal coverage
- **Distribution**: Direct download installers only (no store submission)
- **Timeline**: As soon as ready (quality-focused, no hard deadline)
- **UI Framework**: Migrate from vanilla TS to **Svelte** (smaller bundle, simpler reactivity)
- **UI Design**: iOS/macOS Chowser-like aesthetic (glass effects, clean typography)
- **Feature Parity**: 100% feature parity required (all features must work)
- **Onboarding**: Multi-step wizard (same as macOS, with platform-appropriate instructions)
- **Testing**: Unit tests for core logic + manual QA for UI
- **Platform Limitations**: Implement alternatives (find native ways to achieve similar functionality)
- **Source App Routing**: Disable if unreliable on Windows/Linux (only show if accurate)
- **Framework**: Stay with Electrobun (accept installer limitations)
- **Packaging**: Self-extracting archives acceptable (no NSIS/AppImage required)

## Research Findings

### Electrobun Framework (from librarian)
- **Tech Stack**: TypeScript-first, Bun runtime, System WebView (WebKit/Edge WebView2/WebKitGTK)
- **Bundle Size**: ~12-14MB (vs Electron 150MB+)
- **Platform Support**: macOS 14+, Windows 11+ (Win10 with WebView2), Ubuntu 22.04+
- **Limitation**: `Utils.openExternal()` only opens in system default browser - need `Bun.spawn()` for custom launches with profiles

### Browser Detection
- **Windows**: Registry queries (HKLM/HKCU) via PowerShell, common paths under Program Files
- **Linux**: Parse `.desktop` files in `/usr/share/applications/` and XDG directories

### Profile Discovery  
- **Chrome/Chromium**: Read `Local State` JSON from user data directory
- **Firefox**: Parse `profiles.ini` from `.mozilla/firefox/` or `.config/mozilla/firefox/`

### Launching with Profiles
- **Chromium**: `--profile-directory="Profile 1" --new-window URL`
- **Firefox**: `-P "ProfileName" URL`

### Default Browser Registration
- **Windows 10+**: Requires user interaction via `ms-settings:defaultapps` (system restriction)
- **Linux**: `xdg-settings set default-web-browser your-app.desktop`

### UI Best Practices
- Use `system-ui` font family, `backdrop-filter` for glass effects
- React + Tailwind recommended
- Frameless windows with custom titlebar for consistent look

### Key Limitations
- No global shortcuts API (focus-based only)
- WebView2 not pre-installed on Win10 < 2004
- Linux: WebKitGTK may differ from WebKit

- [awaiting 2 more explore agents: feature mapping + project assessment]

### Electrobun Project Assessment (from explore agent)

**Project Structure**:
- `src/bun/` — Main Bun process (index.ts, models.ts, config.ts, routing.ts, browserDetector.ts, browserLauncher.ts, mcpServer.ts)
- `src/views/picker/` — Picker webview UI (vanilla TS + HTML/CSS)
- `src/views/settings/` — Settings webview UI (vanilla TS + HTML/CSS)
- Build config: `electrobun.config.ts` + `package.json`

**Already Implemented ✅**:
- URL interception and picker lifecycle
- Smart routing engine (host glob/regex, pathPrefix, sourceApp matching)
- Domain frequency tracking and suggestions
- **Browser detection for macOS, Windows, AND Linux** (all three platforms!)
- Profile discovery for Chrome/Firefox on all platforms
- Persistence with platform-aware config directories
- MCP local HTTP API (localhost:24245)
- Picker UI with keyboard shortcuts (1-9, arrows), private mode toggle, rule creation
- Settings UI with full CRUD for browsers & rules, detect browsers, import/export, MCP toggle
- Unit tests for core modules

**NOT Implemented / Gaps ❌**:
1. **Browser launching is macOS-only** — uses `/usr/bin/open`, not exe paths
2. **No Windows/Linux build targets** in electrobun.config.ts
3. **Default browser registration** is macOS-only (opens System Settings)
4. **Launch-at-login** preference saved but not OS-registered for Win/Linux
5. **No Windows/Linux packaging** (.exe, .msi, .deb, .AppImage)
6. **Source-app routing** may not work on Win/Linux (depends on Electrobun event payload)
7. **No onboarding flow** — macOS has multi-step wizard, Electrobun has none
8. **UI needs complete redesign** — vanilla TS → Svelte with iOS-quality aesthetics

**Tech Stack**:
- Electrobun + Bun runtime
- TypeScript (vanilla TS for UI, no React/heavy framework)
- Pure HTML/CSS for views

### macOS Chowser Feature Inventory (from explore agent)

**Complete Feature List to Port**:

1. **System Integration**
   - Menu bar (tray) with status icon
   - Default browser registration
   - URL interception (http/https)
   - Source app detection (which app opened the link)

2. **Picker UI**
   - Two layouts: "icons" (horizontal) and "list" (vertical)
   - Icon sizes: small/medium/large
   - Show/hide labels toggle
   - Keyboard shortcuts: 1-9 for browsers, arrows, Tab, Return, P (private), H (unshorten), R (create rule)
   - Private mode toggle (Option+click or P key)
   - URL bubble with copy, unshorten, manual resolve
   - Quick rule creation from picker

3. **Routing Rules**
   - Host pattern matching (exact, wildcard *.example.com, regex)
   - Path prefix matching
   - Source app matching (open links from Slack in Chrome, etc.)
   - Per-rule private mode
   - Enable/disable toggle
   - Temporary "Focus Mode" (route all to one browser for 1 hour / until tomorrow)

4. **Browser Management**
   - Auto-detect installed browsers
   - Profile detection (Chromium Local State, Firefox profiles.ini)
   - Custom arguments per browser
   - Drag-to-reorder
   - Hidden apps list (exclude non-browsers)

5. **Settings/Preferences**
   - Browsers tab: add/edit/reorder/import/export
   - Rules tab: master-detail, test rule, duplicate, enable/disable
   - General tab: picker appearance, launch at login, MCP server, reset, about
   - Apps tab: hidden bundle IDs

6. **Onboarding Wizard** (5 steps)
   - Welcome
   - Set Default Browser
   - Browsers (auto-detected)
   - AI Setup (MCP server + prompt copy)
   - Rules introduction
   - Finish

7. **MCP Server** (AI automation API)
   - Endpoints: GET/POST/DELETE /browsers, /rules, GET /status
   - Auth token (X-Chowser-Token header)
   - localhost:24245

8. **Clipboard Handling**
   - Menu: "Open Clipboard URL..."
   - Open in browser / Open in private

9. **Domain Frequency Tracking**
   - Records domain→browser clicks
   - Suggests auto-rules at 30+ clicks (60% dominance)
   - Subtle banner in picker

10. **URL Utilities**
    - Tracking parameter removal (utm_*, fbclid, gclid, etc.)
    - Automatic shortlink unshortening
    - Manual unshorten (H/S key)

11. **Import/Export**
    - JSON format for browsers and rules
    - Merge semantics (update existing, append new)

## Open Questions
1. ~~Target platforms~~ ✓ Windows 10+, Linux universal
2. ~~Distribution strategy~~ ✓ Direct download installers
3. ~~Timeline~~ ✓ Quality-focused, ASAP
4. UI preferences - any specific design direction beyond "like iOS"?
5. Testing requirements - automated tests, manual QA, both?
6. Localization - English only or multi-language?

## Scope Boundaries
- INCLUDE:
  - Cross-platform browser launching (Windows exe, Linux binaries)
  - Windows/Linux build targets and packaging (NSIS, .deb, AppImage, Flatpak)
  - Default browser registration for Windows/Linux
  - Launch-at-login for Windows/Linux
  - Complete UI redesign in Svelte (picker + settings + onboarding)
  - iOS-quality visual design (glass effects, smooth animations, clean typography)
  - All 11 feature categories from macOS (100% parity)
  - Source-app routing alternatives investigation
  - Unit tests for new platform code
  - Manual QA on Windows and Linux

- EXCLUDE:
  - macOS support changes (Electrobun project currently works on macOS)
  - App Store submission (direct download only)
  - Auto-update mechanism (not requested)
  - Localization/i18n (English only unless specified)
  - Mobile platforms
