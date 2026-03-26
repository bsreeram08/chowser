# Chowser Electrobun — Manual QA Checklist

**Platform Coverage:** Windows 10/11, Ubuntu 22.04+, Fedora 38+, Arch Linux  
**Last Updated:** March 2026  
**Scope:** All major features across Windows and Linux platforms

---

## A. Pre-Flight Checks (Both Platforms)

### A1: Application Launch
- [ ] App launches without crash or error dialogs
- [ ] **Expected result:** Tray icon appears within 2 seconds

### A2: Tray/System Tray Icon
- [ ] Tray icon (⟳) appears in system tray / taskbar area
- [ ] **Expected result:** Icon is visible and clickable on first launch

### A3: No Error Dialogs on Startup
- [ ] No "WebView2 not found" dialog (Windows) or webkit2gtk errors (Linux)
- [ ] **Expected result:** Clean launch with working UI renderer

### A4: Settings Window Accessibility
- [ ] Click tray icon → "Settings" menu item appears
- [ ] **Expected result:** Settings window opens without lag or UI corruption

---

## B. Default Browser Registration (Platform-Specific)

### Windows 10/11: Registry Registration

- [ ] On first launch, attempt to register via registry
- [ ] **Expected result:** `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RegisteredApplications` contains entry for Chowser

### Windows: Settings UI Registration

- [ ] Tray menu → "Set as Default Browser" opens Windows Settings
- [ ] Settings → "Apps" → "Default apps" shows option to select Chowser
- [ ] **Expected result:** After selection, all http:// and https:// links open via Chowser

### Linux: xdg-settings Registration

- [ ] Tray menu → "Set as Default Browser"
- [ ] **Expected result:** `xdg-settings set default-url-scheme-handler http in.sreerams.chowser-electrobun` succeeds

### Linux: Verification

- [ ] Run: `xdg-settings get default-url-scheme-handler http` returns `in.sreerams.chowser-electrobun`
- [ ] **Expected result:** Returns correct app ID

---

## C. URL Interception

### C1: HTTP Links
- [ ] Click an http:// link (e.g., from Slack, Discord, Notes app, File Manager, Firefox address bar)
- [ ] **Expected result:** Chowser picker appears showing the URL

### C2: HTTPS Links
- [ ] Click an https:// link (e.g., from any web app)
- [ ] **Expected result:** Chowser picker appears showing the URL

### C3: Routing Rule Bypass
- [ ] Create a routing rule: host pattern `example.com`, target browser `Chrome`
- [ ] Click a link to `https://example.com/path`
- [ ] **Expected result:** Browser opens directly WITHOUT showing picker

### C4: Rule Matching Priority (First Match Wins)
- [ ] Create two rules: rule1 for `*.com` → Firefox, rule2 for `github.com` → Chrome
- [ ] Move rule2 to top
- [ ] Click `https://github.com/user/repo`
- [ ] **Expected result:** Opens in Chrome (rule2 matched first)

---

## D. Picker UI — Keyboard Shortcuts & Layout

### D1: Keyboard Shortcut 1-9
- [ ] Picker appears
- [ ] Press `1` → Opens in 1st browser
- [ ] Press `2` → Opens in 2nd browser
- [ ] Press `9` → Opens in 9th browser (if available)
- [ ] **Expected result:** Browser launches immediately without showing Settings

### D2: First Letter Navigation
- [ ] Multiple browsers starting with "C" (Chrome, Chromium) are configured
- [ ] Picker appears
- [ ] Press `C` → Cycles through browsers starting with 'C'
- [ ] **Expected result:** Selects next browser starting with that letter

### D3: Arrow Keys Navigation
- [ ] Picker appears
- [ ] Press `↑` → Selects previous browser
- [ ] Press `↓` → Selects next browser
- [ ] **Expected result:** Selection moves left-to-right (icons mode) or up-to-down (list mode)

### D4: Enter to Open
- [ ] Picker appears, a browser is highlighted
- [ ] Press `Return` / `Enter`
- [ ] **Expected result:** Opens in selected browser

### D5: Private Mode Toggle
- [ ] Picker appears
- [ ] Press `P` → Private mode indicator turns on (visual change)
- [ ] Press `P` again → Private mode indicator turns off
- [ ] Select a browser while private mode is ON
- [ ] **Expected result:** Browser opens in incognito / private mode

### D6: Quick Rule Creation
- [ ] Picker shows `https://github.com/user/repo`
- [ ] Press `R` → Quick rule creation sheet opens
- [ ] Host pattern is pre-filled with `github.com`
- [ ] Fill name: "GitHub → Chrome"
- [ ] Select target browser
- [ ] Press "Create Rule"
- [ ] **Expected result:** Rule is created and persisted; next time `github.com` link is clicked, it opens directly

### D7: URL Unshortening
- [ ] Picker shows a shortened URL (e.g., `bit.ly/abc123`)
- [ ] Press `H` → Unshortening animation appears
- [ ] **Expected result:** URL resolves to full destination (e.g., `https://github.com/...`); if unshortening fails, error message appears

### D8: Icons Layout Mode
- [ ] Settings → General → Layout preference set to "Icons"
- [ ] Click a link to trigger picker
- [ ] **Expected result:** Picker shows horizontal row of browser icons; each icon is ~48px, labeled with shortcut number

### D9: List Layout Mode
- [ ] Settings → General → Layout preference set to "List"
- [ ] Click a link to trigger picker
- [ ] **Expected result:** Picker shows vertical list; each row has browser name, profile (if set), and shortcut key

### D10: URL Bubble Display
- [ ] Picker appears
- [ ] **Expected result:** Current URL is displayed in a "bubble" / card at the top of the picker

### D11: Escape Key / Click Outside
- [ ] Picker is open
- [ ] Press `Esc` or click outside picker
- [ ] **Expected result:** Picker closes WITHOUT opening a browser

---

## E. Browser Profiles

### E1: Chrome Profile Detection
- [ ] Close all browsers
- [ ] Settings → Browsers → "🔍 Detect Installed Browsers"
- [ ] **Expected result:** Chrome is detected; all installed profiles appear (e.g., "Default", "Profile 1", "Work")

### E2: Firefox Profile Detection
- [ ] Close all browsers
- [ ] Settings → Browsers → "🔍 Detect Installed Browsers"
- [ ] **Expected result:** Firefox is detected; all installed profiles appear (e.g., "default", "work-profile")

### E3: Chromium Profile Opening
- [ ] Add Chrome with profile "Profile 1"
- [ ] Create a routing rule to open `example.com` in this Chrome profile
- [ ] Click `https://example.com`
- [ ] **Expected result:** Chrome opens with "Profile 1" active

### E4: Firefox Profile Opening
- [ ] Add Firefox with profile "work"
- [ ] Create a routing rule to open `work.example.com` in this Firefox profile
- [ ] Click `https://work.example.com`
- [ ] **Expected result:** Firefox opens with "work" profile active

---

## F. Settings — Browsers Tab

### F1: Manual Browser Addition
- [ ] Settings → Browsers → "Add Browser"
- [ ] Enter name: "Chrome Custom"
- [ ] Enter app ID (Windows: `Google.Chrome`, Linux: `google-chrome`)
- [ ] Enter profile: "Profile 1"
- [ ] Enter shortcut key: "1"
- [ ] Press "Add"
- [ ] **Expected result:** Browser appears in list; is immediately available in picker

### F2: Browser Deletion
- [ ] Settings → Browsers → Select a browser row
- [ ] Press "Delete" or click trash icon
- [ ] **Expected result:** Browser is removed; no longer appears in picker

### F3: Browser Reordering via Drag
- [ ] Settings → Browsers
- [ ] Drag browser "A" above browser "B"
- [ ] **Expected result:** Shortcut keys update (A gets "1", B gets "2"); order persists after restart

### F4: Auto-Detection Button
- [ ] Settings → Browsers → "🔍 Detect Installed Browsers" button
- [ ] **Expected result:** All installed browsers and profiles are listed; can be added with checkboxes

### F5: Settings Persistence
- [ ] Settings → Browsers → Add a new browser "Test Browser"
- [ ] Close Settings
- [ ] Restart app
- [ ] Open Settings → Browsers
- [ ] **Expected result:** "Test Browser" is still there

---

## G. Settings — Rules Tab

### G1: Add Routing Rule
- [ ] Settings → Rules → "Add Rule"
- [ ] Fill host pattern: `github.com`
- [ ] Fill path prefix: (leave empty)
- [ ] Select target browser: Chrome
- [ ] Leave source app empty (Windows/Linux don't support source-app routing)
- [ ] Press "Add"
- [ ] **Expected result:** Rule appears in list; is immediately active

### G2: Edit Routing Rule
- [ ] Settings → Rules → Click an existing rule
- [ ] Change host pattern to `*.github.com`
- [ ] Change target browser
- [ ] Press "Save"
- [ ] **Expected result:** Rule is updated; old rule behavior is replaced

### G3: Delete Routing Rule
- [ ] Settings → Rules → Select a rule
- [ ] Press "Delete" or click trash icon
- [ ] **Expected result:** Rule is removed; matching URLs now show picker again

### G4: Host Pattern Matching
- [ ] Create rule: host pattern `example.com`, target Chrome
- [ ] Click `https://example.com/path` → Opens in Chrome (✓)
- [ ] Click `https://subdomain.example.com` → Shows picker (✗ subdomain doesn't match exact)
- [ ] **Expected result:** Exact match works; wildcard patterns require glob syntax

### G5: Wildcard Host Pattern
- [ ] Create rule: host pattern `*.example.com`, target Chrome
- [ ] Click `https://api.example.com` → Opens in Chrome (✓)
- [ ] Click `https://www.example.com` → Opens in Chrome (✓)
- [ ] **Expected result:** Wildcard patterns work correctly

### G6: Path Prefix Matching
- [ ] Create rule: host pattern `github.com`, path prefix `/api`, target Chrome
- [ ] Click `https://github.com/api/repos` → Opens in Chrome (✓)
- [ ] Click `https://github.com/user/repo` → Shows picker (✗ doesn't match /api)
- [ ] **Expected result:** Path prefix is respected

### G7: Private Mode in Rule
- [ ] Create rule: host pattern `sensitive.example.com`, target Firefox, check "Use Private Mode"
- [ ] Click `https://sensitive.example.com`
- [ ] **Expected result:** Firefox opens in private / private browsing mode

### G8: Rule Persistence
- [ ] Create a rule
- [ ] Restart app
- [ ] Settings → Rules
- [ ] **Expected result:** Rule is still there

---

## H. Settings — General Tab

### H1: Launch at Login — Windows
- [ ] Settings → General → Toggle "Launch at Login"
- [ ] Registry check: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run` contains entry `in.sreerams.chowser-electrobun`
- [ ] **Expected result:** Toggle is saved; entry exists when enabled

### H1b: Launch at Login — Linux
- [ ] Settings → General → Toggle "Launch at Login"
- [ ] File check: `~/.config/autostart/in.sreerams.chowser-electrobun.desktop` exists
- [ ] **Expected result:** File exists when toggle is enabled; deleted when disabled

### H2: Layout Preference Persistence
- [ ] Settings → General → Set layout to "List"
- [ ] Close and restart app
- [ ] Trigger picker
- [ ] **Expected result:** Picker shows list layout (preference persisted)

### H3: Import JSON Configuration
- [ ] Create a JSON file with 2 browsers and 3 rules (see examples in README)
- [ ] Settings → General → "Import Config"
- [ ] Select the file
- [ ] **Expected result:** Browsers and rules are merged into existing config; no duplicates if re-importing same file

### H4: Export JSON Configuration
- [ ] Settings → General → "Export Config"
- [ ] Save to Downloads folder
- [ ] Open file and verify structure
- [ ] **Expected result:** Valid JSON with `browsers` and `rules` arrays

### H5: Config File Integrity
- [ ] After import/export, verify file paths:
  - Windows: `%APPDATA%\in.sreerams.chowser-electrobun\state.json`
  - Linux: `~/.config/in.sreerams.chowser-electrobun/state.json`
- [ ] **Expected result:** File is valid JSON

---

## I. Onboarding

### I1: Onboarding on Fresh Install
- [ ] Delete config file (Windows: `%APPDATA%\in.sreerams.chowser-electrobun`, Linux: `~/.config/in.sreerams.chowser-electrobun`)
- [ ] Launch app
- [ ] **Expected result:** Onboarding wizard appears (not Settings)

### I2: Onboarding Step 1 — Welcome
- [ ] Onboarding is showing
- [ ] **Expected result:** "Welcome" screen explains Chowser's purpose

### I3: Onboarding Step 2 — Default Browser
- [ ] Press "Next"
- [ ] **Expected result:** Step shows "Set as Default Browser" button; clicking opens system settings

### I4: Onboarding Step 3 — Browser Selection
- [ ] Complete step 2 and press "Next"
- [ ] **Expected result:** Step shows list of installed browsers; can select which to add

### I5: Onboarding Step 4 — AI (MCP Server)
- [ ] Complete step 3 and press "Next"
- [ ] **Expected result:** Step explains MCP server feature; toggle to enable/disable

### I6: Onboarding Step 5 — Finish
- [ ] Complete step 4 and press "Next"
- [ ] **Expected result:** "Finish" screen; pressing "Done" closes onboarding and shows Settings

### I7: Onboarding Completion
- [ ] Finish onboarding
- [ ] Close and restart app
- [ ] **Expected result:** Onboarding does NOT appear again

### I8: Set Default Browser from Onboarding
- [ ] In onboarding step 2, click "Set as Default Browser"
- [ ] Complete system settings registration
- [ ] Resume onboarding
- [ ] **Expected result:** Button no longer shows (or shows "Already Set")

---

## J. Domain Frequency Suggestions

### J1: Suggestion Banner After 30 Clicks
- [ ] Create a routing rule for `github.com` → Firefox (to track clicks)
- [ ] Click 29 `github.com` links (can repeatedly click same link)
- [ ] **Expected result:** No suggestion banner yet
- [ ] Click the 30th link to `github.com`
- [ ] Picker shows suggestion banner: "We noticed you open github.com in Firefox"

### J2: Create Rule from Suggestion
- [ ] Suggestion banner is showing
- [ ] Press "Create Rule"
- [ ] **Expected result:** Rule is auto-created; future `github.com` links open directly without picker

### J3: Dismiss Suggestion
- [ ] Suggestion banner is showing
- [ ] Press "Dismiss"
- [ ] **Expected result:** Banner disappears; same domain suggestion doesn't re-appear until click count resets

### J4: Suggestion Persists Across Sessions
- [ ] Suggestion banner appears
- [ ] Close app without creating/dismissing
- [ ] Restart app and trigger another link to same domain
- [ ] **Expected result:** Suggestion banner reappears (state is persisted)

---

## K. Clipboard URL Feature

### K1: Clipboard URL in Tray Menu
- [ ] Copy a valid URL (e.g., `https://github.com`) to clipboard
- [ ] Right-click tray icon (or click and look for menu)
- [ ] **Expected result:** Tray menu shows "Open Clipboard URL" option

### K2: Clipboard URL Submenu
- [ ] Clipboard has a valid URL
- [ ] Tray menu → "Open Clipboard URL"
- [ ] **Expected result:** Submenu shows all configured browsers

### K3: Open Clipboard URL
- [ ] Clipboard has `https://example.com`
- [ ] Tray menu → "Open Clipboard URL" → Select a browser
- [ ] **Expected result:** Browser opens the URL directly (bypasses picker)

### K4: Private Mode from Clipboard
- [ ] Clipboard has `https://example.com`
- [ ] Tray menu → "Open Clipboard URL" → "Open in Private"
- [ ] **Expected result:** Browser opens URL in incognito / private mode

### K5: No Menu When Clipboard Empty
- [ ] Delete clipboard content (or copy non-URL text)
- [ ] Right-click tray icon
- [ ] **Expected result:** "Open Clipboard URL" option is hidden or disabled

---

## L. MCP Server (REST API)

### L1: MCP Server Start
- [ ] Settings → General → Enable "MCP Server" toggle
- [ ] **Expected result:** Toggle turns on; server starts on localhost:24245

### L2: Health Check Endpoint
- [ ] MCP Server is running
- [ ] Open terminal/PowerShell and run:
  ```
  curl http://localhost:24245/status
  ```
- [ ] **Expected result:** Returns `{"status":"running","port":24245}`

### L3: Get Browsers Endpoint
- [ ] Run:
  ```
  curl http://localhost:24245/browsers
  ```
- [ ] **Expected result:** Returns JSON array of configured browsers

### L4: Create Browser via API
- [ ] Run:
  ```
  curl -X POST http://localhost:24245/browsers \
    -H "Content-Type: application/json" \
    -d '{"name":"API Browser","appId":"com.google.Chrome","profile":""}'
  ```
- [ ] **Expected result:** Returns new browser with assigned ID

### L5: Get Rules Endpoint
- [ ] Run:
  ```
  curl http://localhost:24245/rules
  ```
- [ ] **Expected result:** Returns JSON array of routing rules

### L6: Create Rule via API
- [ ] Run:
  ```
  curl -X POST http://localhost:24245/rules \
    -H "Content-Type: application/json" \
    -d '{"name":"API Rule","hostPattern":"api.example.com","browserAppId":"com.google.Chrome"}'
  ```
- [ ] **Expected result:** Returns new rule with assigned ID

### L7: Delete Browser via API
- [ ] Run:
  ```
  curl -X DELETE http://localhost:24245/browsers/{browser_id}
  ```
- [ ] **Expected result:** Returns `{"success":true}` and browser is removed from config

### L8: Delete Rule via API
- [ ] Run:
  ```
  curl -X DELETE http://localhost:24245/rules/{rule_id}
  ```
- [ ] **Expected result:** Returns `{"success":true}` and rule is removed from config

### L9: MCP Server Persistence
- [ ] Create a browser via API
- [ ] Toggle MCP Server off
- [ ] Restart app
- [ ] Enable MCP Server again
- [ ] Query `/browsers` endpoint
- [ ] **Expected result:** Browser created via API is still there (config was persisted)

---

## M. Focus Mode (Temporary Default Browser)

### M1: Focus Mode Menu Items
- [ ] Tray menu → "Focus Mode" submenu appears
- [ ] **Expected result:** Shows quick-set options for top 3 browsers (e.g., "Focus: Chrome for 1 Hour")

### M2: 1-Hour Focus Mode
- [ ] Tray menu → Focus Mode → "Focus: Chrome for 1 Hour"
- [ ] **Expected result:** Focus mode activates; all links route to Chrome for 1 hour

### M3: Until Tomorrow Focus Mode
- [ ] Tray menu → Focus Mode → "Focus: Firefox Until Tomorrow"
- [ ] **Expected result:** Focus mode activates; all links route to Firefox until next 00:00 (midnight)

### M4: All Links Route During Focus Mode
- [ ] Enable Focus Mode for Chrome
- [ ] Click links to `github.com`, `google.com`, `youtube.com`
- [ ] **Expected result:** All links open in Chrome, regardless of routing rules or picker

### M5: Focus Mode Expiration
- [ ] Enable "1 Hour" Focus Mode
- [ ] Wait for expiration (or adjust system clock forward)
- [ ] Tray menu shows "Focus Mode" options again
- [ ] **Expected result:** Focus mode expires automatically

### M6: Clear Focus Mode
- [ ] Focus Mode is active
- [ ] Tray menu → "Clear Focus Mode"
- [ ] **Expected result:** Focus mode is disabled; next link shows picker (or respects routing rules again)

### M7: Focus Status Banner
- [ ] Focus Mode is active
- [ ] Click any link
- [ ] Picker appears with a banner showing active Focus Mode
- [ ] **Expected result:** Banner indicates which browser is focused and when it expires

---

## N. Platform-Specific Checks

### Windows 10 / Windows 11

#### N1a: Windows 10 Compatibility (Build 19041+)
- [ ] Install on Windows 10 Build 19041 (22H2)
- [ ] **Expected result:** App launches and runs without errors

#### N1b: Windows 11 Compatibility
- [ ] Install on Windows 11 (any build)
- [ ] **Expected result:** App launches and runs without errors

#### N2: WebView2 Rendering
- [ ] Picker appears
- [ ] **Expected result:** UI renders cleanly; no flickering or rendering artifacts

#### N3: System Tray Icon (Windows)
- [ ] App is running
- [ ] **Expected result:** Tray icon appears in Windows taskbar (bottom-right corner); right-click shows menu

#### N4: WebView2 Auto-Installation
- [ ] Uninstall WebView2 Runtime from Control Panel (if installed)
- [ ] Launch Chowser
- [ ] **Expected result:** Prompt appears; clicking "Install" downloads and installs WebView2

#### N5: File Associations Registration
- [ ] After first launch, check Settings → Apps → Default Apps
- [ ] Search for "http" or "https"
- [ ] **Expected result:** Chowser can be set as default handler

---

### Linux (Ubuntu 22.04+, Fedora 38+, Arch)

#### N6a: Ubuntu 22.04 Compatibility
- [ ] Install on Ubuntu 22.04 LTS
- [ ] Verify WebKit2GTK is installed: `dpkg -l | grep webkit2gtk`
- [ ] Launch Chowser
- [ ] **Expected result:** App launches without library errors

#### N6b: Fedora 38+ Compatibility
- [ ] Install on Fedora 38+
- [ ] Verify webkit2gtk is installed: `rpm -qa | grep webkit2gtk`
- [ ] Launch Chowser
- [ ] **Expected result:** App launches without library errors

#### N6c: Arch Linux Compatibility
- [ ] Install on Arch Linux
- [ ] Verify webkit2gtk is installed: `pacman -Q webkit2gtk`
- [ ] Launch Chowser
- [ ] **Expected result:** App launches without library errors

#### N7: WebKit2GTK Rendering
- [ ] Picker appears
- [ ] **Expected result:** UI renders cleanly; text is readable; no rendering artifacts

#### N8: System Tray Icon (Linux)
- [ ] App is running
- [ ] **Expected result:** Tray icon appears in system tray (top-right on GNOME, top-left on KDE)
- [ ] Note: May require AppIndicator support on some GNOME versions

#### N9: URL Scheme Registration (Linux)
- [ ] Run: `xdg-mime query default x-scheme-handler/http`
- [ ] **Expected result:** Returns `in.sreerams.chowser-electrobun.desktop` after setting as default

#### N10: Desktop Entry Creation
- [ ] Check: `~/.config/applications/in.sreerams.chowser-electrobun.desktop`
- [ ] **Expected result:** File exists with proper launcher entry

#### N11: Autostart Desktop File (Linux)
- [ ] Enable "Launch at Login" in Settings
- [ ] Check: `~/.config/autostart/in.sreerams.chowser-electrobun.desktop`
- [ ] **Expected result:** File exists when toggle is ON; deleted when OFF

---

## O. Cross-Platform Checks (All Platforms)

### O1: Configuration File Location
- [ ] Settings → General → Verify config path matches expected location
- [ ] Windows: `%APPDATA%\in.sreerams.chowser-electrobun\state.json`
- [ ] Linux: `~/.config/in.sreerams.chowser-electrobun/state.json`
- [ ] macOS: `~/Library/Application Support/in.sreerams.chowser-electrobun/state.json`
- [ ] **Expected result:** File exists and contains valid JSON

### O2: Tray Menu Full Options
- [ ] Right-click / long-press tray icon
- [ ] **Expected result:** Menu includes:
  - Settings
  - Set as Default Browser
  - Open Clipboard URL (if applicable)
  - Focus Mode
  - MCP Server (if supported)
  - Exit

### O3: Settings Window CRUD
- [ ] Open Settings
- [ ] Add a browser → appears immediately
- [ ] Edit a browser → changes apply instantly
- [ ] Delete a browser → removed from list and picker
- [ ] **Expected result:** All CRUD operations work without lag

### O4: Keyboard Shortcuts Across Sessions
- [ ] Settings → Browsers → Set shortcut keys for 3 browsers (1, 2, 3)
- [ ] Trigger picker
- [ ] Press `1` → Opens in first browser
- [ ] Restart app
- [ ] Trigger picker again
- [ ] Press `1` → Still opens in first browser
- [ ] **Expected result:** Shortcut keys persist

### O5: Rule Conflict Resolution
- [ ] Create two rules: rule1 for `*.example.com`, rule2 for `api.example.com`
- [ ] Move rule2 to position 1 (top priority)
- [ ] Click `https://api.example.com`
- [ ] **Expected result:** Uses rule2 (first match wins)

---

## P. Regression Testing (Automated)

### P1: Unit Tests Pass
- [ ] Run: `bun test`
- [ ] **Expected result:** All tests pass (0 failures)

### P2: Build Succeeds
- [ ] Run: `bun run build`
- [ ] **Expected result:** Build completes without errors; artifact is generated

### P3: TypeScript Type Safety
- [ ] Run: `npx tsc --noEmit`
- [ ] **Expected result:** No type errors

### P4: No Console Warnings
- [ ] Open DevTools (if available)
- [ ] Trigger picker and interact with UI
- [ ] **Expected result:** No critical errors in console

---

## Q. Smoke Test (Quick Validation)

**Use this checklist for rapid pre-release validation (10-15 minutes):**

- [ ] App launches without crash
- [ ] Tray icon is visible
- [ ] Click a URL → Picker appears
- [ ] Press `1` → Browser opens
- [ ] Settings → Can add/delete a browser
- [ ] Settings → Can add/delete a rule
- [ ] Rule matches → Link opens directly
- [ ] Keyboard shortcut `P` toggles private mode
- [ ] Keyboard shortcut `R` opens quick rule creation
- [ ] Layout preference (icons/list) persists
- [ ] Import/export config works
- [ ] MCP server starts (if enabled)
- [ ] Focus Mode menu appears and functions
- [ ] Onboarding doesn't re-appear after completion
- [ ] Domain frequency suggestion banner appears after 30 clicks
- [ ] All unit tests pass (`bun test`)

---

## Notes for Testers

### Environment Setup

**Windows 10/11:**
- WebView2 Runtime installed (verify via Control Panel → Programs & Features)
- Multiple browsers available (Chrome, Firefox, Edge)

**Linux:**
- WebKit2GTK installed (`sudo apt install libwebkit2gtk-4.1-0` on Ubuntu)
- Multiple browsers available (Google Chrome, Firefox)

### Testing Best Practices

1. **Isolation:** Use separate browser profiles for each test to avoid contamination
2. **Persistence:** Always verify config persists after app restart
3. **Regression:** Before marking "complete", run full unit test suite
4. **Documentation:** Note any platform-specific quirks or unexpected behaviors

### Known Limitations (Not Test Failures)

- **Shift-to-force-picker** not available (OS limitation)
- **Source-app routing** disabled on Windows/Linux (OS limitation)
- **AppIndicator support** required on some GNOME systems for tray icon visibility

---

## Sign-Off

| Item | Value |
|---|---|
| Platform | [Windows/Linux] |
| Build Version | [X.Y.Z] |
| Build Date | [YYYY-MM-DD] |
| Tester Name | [Name] |
| Test Date | [YYYY-MM-DD] |
| Result | [ ] PASS [ ] FAIL |
| Notes | [Any blockers, workarounds, or deviations] |

---

**End of Checklist**
