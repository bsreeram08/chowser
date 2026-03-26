# Chowser Electrobun: Windows & Linux Release Plan

## TL;DR

> **Quick Summary**: Make Chowser Electrobun fully functional on Windows and Linux with 100% feature parity with macOS Chowser, including a complete UI redesign in Svelte with iOS-quality aesthetics.
> 
> **Deliverables**:
> - Cross-platform browser launching (Windows .exe, Linux binaries with profiles)
> - Complete Svelte UI (picker, settings, onboarding wizard)
> - Windows/Linux build targets and self-extracting packages
> - Platform-specific integrations (default browser, launch-at-login)
> - All 11 feature categories working on all platforms
> 
> **Estimated Effort**: Large (50+ tasks across 5 waves)
> **Parallel Execution**: YES - 5 waves with 5-10 tasks each
> **Critical Path**: Svelte Setup → Core UI Components → Picker UI → Platform Launching → Packaging

---

## Context

### Original Request
"Plan to make sure the entire chowser-electrobun works and is ready for release for Windows and Linux. I want every feature to work in parity with Chowser iOS project. And I also want the UI to look really good as good as iOS UI."

### Interview Summary
**Key Discussions**:
- **Platforms**: Windows 10+ (with legacy consideration), All major Linux distros
- **Distribution**: Direct download installers only (self-extracting archives acceptable)
- **UI Framework**: Migrate from vanilla TS to Svelte
- **Design Direction**: iOS/macOS Chowser-like aesthetic (glass effects, clean typography)
- **Feature Parity**: 100% required across all 11 feature categories
- **Source App Routing**: Disable on Windows/Linux if unreliable (accuracy > availability)
- **Testing**: Unit tests for core logic + manual QA for UI

**Research Findings**:
- Electrobun browser detection already works for Windows AND Linux
- Profile discovery (Chrome Local State, Firefox profiles.ini) works cross-platform
- Browser launching is macOS-only — needs Win/Linux Bun.spawn() implementation
- No Windows/Linux build targets configured
- No onboarding flow exists in Electrobun version
- Current UI is vanilla TS/HTML/CSS — needs complete Svelte redesign

### Metis Review
**Identified Gaps** (addressed):
- Electrobun installer limitations → User accepted self-extracting archives
- Source app detection accuracy → Will disable feature if unreliable
- Windows 10 not officially supported → Acceptable (works with WebView2)
- No code signing API → Manual implementation if needed later

---

## Work Objectives

### Core Objective
Deliver a production-ready Chowser Electrobun release for Windows and Linux with complete feature parity with the macOS native app and iOS-quality visual design.

### Concrete Deliverables
- `chowser-electrobun/` with working Windows and Linux builds
- Svelte-based picker UI with iOS-quality aesthetics
- Svelte-based settings UI with full CRUD functionality
- Svelte-based onboarding wizard (5 steps)
- Cross-platform browser launching with profile support
- Platform-specific default browser registration
- Platform-specific launch-at-login
- Self-extracting packages for Windows (.exe) and Linux (tarball)

### Definition of Done
- [ ] `npm run build:windows` produces working Windows package
- [ ] `npm run build:linux` produces working Linux package
- [ ] All 11 feature categories functional on Windows and Linux
- [ ] UI matches iOS/macOS Chowser visual quality
- [ ] Unit tests pass for all platform-specific code
- [ ] Manual QA completed on Windows 10/11 and Ubuntu/Fedora

### Must Have
- Picker with icons/list layouts, all keyboard shortcuts (1-9, arrows, P, H, R)
- Routing rules with host patterns, path prefix, regex support
- Browser profiles (Chrome, Firefox, Edge, Brave)
- Settings with browsers, rules, general, hidden apps tabs
- MCP server for AI automation
- Import/export JSON
- Domain frequency tracking and suggestions
- URL cleaning and unshortening

### Must NOT Have (Guardrails)
- **No source-app routing on Windows/Linux** (disabled due to reliability concerns)
- **No NSIS/MSI or AppImage/deb packaging** (self-extracting only)
- **No auto-update mechanism** (not requested)
- **No localization/i18n** (English only)
- **No macOS changes** (existing macOS build should continue working)
- **No Tauri migration** (staying with Electrobun)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (bun test in package.json)
- **Automated tests**: Tests-after (add tests for new platform code)
- **Framework**: bun test

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Frontend/UI**: Use Playwright — Navigate, interact, assert DOM, screenshot
- **Backend/Logic**: Use Bash (bun test) — Run tests, assert pass
- **Cross-platform**: Use Bash — Build, run on platform, verify behavior

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — Svelte setup + shared infrastructure):
├── Task 1: Set up Svelte in Electrobun project [quick]
├── Task 2: Create design system tokens (colors, typography, spacing) [quick]
├── Task 3: Create shared Svelte components (Button, Input, Toggle, Card) [visual-engineering]
├── Task 4: Implement cross-platform browser launcher (Windows/Linux) [deep]
├── Task 5: Add Windows/Linux build targets to electrobun.config.ts [quick]
├── Task 6: Create platform detection utilities [quick]
└── Task 7: Set up Playwright for Electrobun UI testing [quick]

Wave 2 (Core UI Components — picker and settings layouts):
├── Task 8: Build Picker shell component with glass effect background [visual-engineering]
├── Task 9: Build BrowserIcon component with size variants [visual-engineering]
├── Task 10: Build BrowserListItem component [visual-engineering]
├── Task 11: Build URL bubble component with copy/unshorten actions [visual-engineering]
├── Task 12: Build Settings shell with sidebar navigation [visual-engineering]
├── Task 13: Build BrowserConfigRow component for settings [visual-engineering]
├── Task 14: Build RuleRow component for settings [visual-engineering]
└── Task 15: Build reusable Modal/Sheet component [visual-engineering]

Wave 3 (Feature Implementation — complete picker and settings):
├── Task 16: Implement Picker icons layout mode [visual-engineering]
├── Task 17: Implement Picker list layout mode [visual-engineering]
├── Task 18: Implement Picker keyboard handling (1-9, arrows, P, H, R) [deep]
├── Task 19: Implement quick rule creation from picker [visual-engineering]
├── Task 20: Implement Settings Browsers tab with full CRUD [visual-engineering]
├── Task 21: Implement Settings Rules tab with master-detail [visual-engineering]
├── Task 22: Implement Settings General tab [visual-engineering]
├── Task 23: Implement Settings Hidden Apps tab [visual-engineering]
├── Task 24: Implement import/export UI for browsers and rules [visual-engineering]
└── Task 25: Implement Temporary Focus Mode UI [visual-engineering]

Wave 4 (Onboarding + Platform Integration):
├── Task 26: Build Onboarding wizard shell with step navigation [visual-engineering]
├── Task 27: Implement Welcome step [visual-engineering]
├── Task 28: Implement Default Browser step with platform-specific registration [deep]
├── Task 29: Implement Browsers detection step [visual-engineering]
├── Task 30: Implement AI Setup step (MCP server) [visual-engineering]
├── Task 31: Implement Rules introduction step [visual-engineering]
├── Task 32: Implement Finish step with completion handling [visual-engineering]
├── Task 33: Implement launch-at-login for Windows [deep]
├── Task 34: Implement launch-at-login for Linux [deep]
└── Task 35: Implement default browser registration for Linux [deep]

Wave 5 (Polish + Packaging):
├── Task 36: Add domain frequency tracking UI (suggestion banner) [visual-engineering]
├── Task 37: Implement URL cleaning and unshortening UI [quick]
├── Task 38: Implement clipboard URL handling [quick]
├── Task 39: Add unit tests for cross-platform launcher [quick]
├── Task 40: Add unit tests for platform detection utilities [quick]
├── Task 41: Configure Windows self-extracting package [quick]
├── Task 42: Configure Linux tarball package [quick]
├── Task 43: Add platform-specific icons and metadata [quick]
├── Task 44: Create README with installation instructions [writing]
└── Task 45: Manual QA on Windows 10/11 [unspecified-high]

Wave FINAL (Verification — 4 parallel reviews, then user okay):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Cross-platform QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
-> Present results -> Get explicit user okay

Critical Path: Task 1 → Task 3 → Task 8 → Task 16 → Task 18 → Task 28 → Task 41 → F1-F4
Parallel Speedup: ~65% faster than sequential
Max Concurrent: 7 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|------------|--------|------|
| 1 | — | 3, 8-15, 16-25 | 1 |
| 2 | — | 3, 8-15 | 1 |
| 3 | 1, 2 | 8-15, 16-25 | 1 |
| 4 | — | 18, 28, 33-35 | 1 |
| 5 | — | 41, 42 | 1 |
| 6 | — | 28, 33-35 | 1 |
| 7 | 1 | F3 | 1 |
| 8-15 | 1, 2, 3 | 16-25, 26-32 | 2 |
| 16-25 | 8-15 | 36-38 | 3 |
| 26-35 | 8-15, 4, 6 | 45 | 4 |
| 36-45 | 16-25, 26-35 | F1-F4 | 5 |
| F1-F4 | 36-45 | — | FINAL |

### Agent Dispatch Summary

- **Wave 1**: 7 tasks — T1,2,5,6,7 → `quick`, T3 → `visual-engineering`, T4 → `deep`
- **Wave 2**: 8 tasks — T8-15 → `visual-engineering`
- **Wave 3**: 10 tasks — T16,17,19-25 → `visual-engineering`, T18 → `deep`
- **Wave 4**: 10 tasks — T26-32 → `visual-engineering`, T28,33,34,35 → `deep`
- **Wave 5**: 10 tasks — T36 → `visual-engineering`, T37-44 → `quick`, T45 → `unspecified-high`
- **FINAL**: 4 tasks — F1 → `oracle`, F2,F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [x] 1. Set up Svelte in Electrobun project

  **What to do**:
  - Install Svelte 5 and required build tooling (vite, @sveltejs/vite-plugin-svelte)
  - Configure vite.config.ts for Svelte compilation
  - Update electrobun.config.ts to use Vite-built output for views
  - Create src/views/picker/App.svelte and src/views/settings/App.svelte entry points
  - Verify hot reload works in development

  **Must NOT do**:
  - Don't remove existing vanilla TS code until Svelte replacement is ready
  - Don't use SvelteKit (too heavy for Electrobun views)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Standard setup task, well-documented process

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 4, 5, 6, 7)
  - **Blocks**: Tasks 3, 8-15, 16-25
  - **Blocked By**: None

  **References**:
  - `chowser-electrobun/package.json` — Current dependencies
  - `chowser-electrobun/electrobun.config.ts` — View entry points configuration
  - `chowser-electrobun/src/views/picker/index.html` — Current picker entry
  - Official Svelte 5 docs: https://svelte.dev/docs/svelte/overview

  **Acceptance Criteria**:
  - [ ] `npm install` succeeds with Svelte dependencies
  - [ ] `npm run dev` starts with Svelte compilation working
  - [ ] App.svelte renders "Hello Svelte" in picker view

  **QA Scenarios**:
  ```
  Scenario: Svelte compiles and renders in picker view
    Tool: Bash
    Preconditions: npm install completed
    Steps:
      1. Run `npm run dev` in chowser-electrobun/
      2. Wait 5 seconds for compilation
      3. Check stdout for "compiled" message without errors
    Expected Result: No compilation errors, server running
    Failure Indicators: "Error", "Failed", compilation warnings about Svelte
    Evidence: .sisyphus/evidence/task-1-svelte-setup.txt
  ```

  **Commit**: YES (groups with Wave 1)
  - Message: `feat(electrobun): add Svelte 5 with Vite build setup`
  - Files: `package.json`, `vite.config.ts`, `src/views/*/App.svelte`

- [x] 2. Create design system tokens (colors, typography, spacing)

  **What to do**:
  - Create src/views/shared/tokens.css with CSS custom properties
  - Define color palette matching iOS Chowser (background, foreground, accent, muted)
  - Define typography scale (font sizes, weights, line heights)
  - Define spacing scale (4px base unit)
  - Define border radius values for glass effect cards
  - Support both light and dark mode via prefers-color-scheme

  **Must NOT do**:
  - Don't use Tailwind (keep CSS simple for Electrobun bundle size)
  - Don't over-engineer — keep it minimal

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: CSS variables definition, straightforward design task

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 4, 5, 6, 7)
  - **Blocks**: Task 3, Tasks 8-15
  - **Blocked By**: None

  **References**:
  - macOS Chowser `ContentView.swift` — Visual styling patterns
  - macOS Chowser `PickerViewModifiers.swift` — Glass effect fallbacks
  - iOS design guidelines for color palette inspiration

  **Acceptance Criteria**:
  - [ ] tokens.css exists with all color, typography, spacing variables
  - [ ] Dark mode variables defined with @media (prefers-color-scheme: dark)
  - [ ] Variables use semantic names (--color-background, --color-text-primary, etc.)

  **QA Scenarios**:
  ```
  Scenario: Design tokens file exists with required variables
    Tool: Bash
    Preconditions: None
    Steps:
      1. Read src/views/shared/tokens.css
      2. Grep for "--color-background"
      3. Grep for "--font-size-base"
      4. Grep for "--spacing-4"
      5. Grep for "prefers-color-scheme: dark"
    Expected Result: All grep commands find matches
    Failure Indicators: "No such file", empty grep results
    Evidence: .sisyphus/evidence/task-2-tokens.txt
  ```

  **Commit**: NO (groups with Task 1)

- [x] 3. Create shared Svelte components (Button, Input, Toggle, Card)

  **What to do**:
  - Create src/views/shared/components/ directory
  - Build Button.svelte with variants (primary, secondary, ghost) and sizes (sm, md, lg)
  - Build Input.svelte with label, placeholder, error state support
  - Build Toggle.svelte for boolean settings (launch at login, etc.)
  - Build Card.svelte with glass effect background (backdrop-filter: blur)
  - Build Icon.svelte wrapper for inline SVG icons
  - All components use design tokens from Task 2

  **Must NOT do**:
  - Don't add animations yet (polish phase)
  - Don't build complex form validation (keep simple)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: UI component design requiring visual quality

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential after Tasks 1, 2
  - **Blocks**: Tasks 8-15, 16-25
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `src/views/shared/tokens.css` (from Task 2) — Design tokens
  - macOS Chowser `BrowserConfigRow.swift` — Button/toggle patterns
  - macOS Chowser `PickerViewModifiers.swift` — Glass effect implementation

  **Acceptance Criteria**:
  - [ ] Button.svelte renders with 3 variants and 3 sizes
  - [ ] Input.svelte shows label, handles input events
  - [ ] Toggle.svelte toggles boolean value
  - [ ] Card.svelte has glass effect with backdrop-filter

  **QA Scenarios**:
  ```
  Scenario: Button component renders all variants
    Tool: Playwright
    Preconditions: Dev server running
    Steps:
      1. Navigate to picker view
      2. Query for button[data-variant="primary"]
      3. Query for button[data-variant="secondary"]
      4. Query for button[data-variant="ghost"]
      5. Screenshot each variant
    Expected Result: All 3 button variants render correctly
    Failure Indicators: Missing elements, no backdrop-filter on Card
    Evidence: .sisyphus/evidence/task-3-components.png

  Scenario: Toggle component changes state on click
    Tool: Playwright
    Preconditions: Dev server running with test toggle
    Steps:
      1. Find toggle element
      2. Assert initial state is false (unchecked)
      3. Click toggle
      4. Assert state is true (checked)
    Expected Result: Toggle state changes
    Evidence: .sisyphus/evidence/task-3-toggle.png
  ```

  **Commit**: YES (groups with Wave 1)
  - Message: `feat(ui): add shared Svelte component library`
  - Files: `src/views/shared/components/*.svelte`

- [ ] 4. Implement cross-platform browser launcher (Windows/Linux)

  **What to do**:
  - Modify src/bun/browserLauncher.ts to handle Windows and Linux
  - Use Bun.spawn() instead of /usr/bin/open for non-macOS
  - Windows: spawn exe directly with --profile-directory for Chromium, -P for Firefox
  - Linux: spawn binary from PATH with same profile arguments
  - Use browserDetector.resolveExecutablePath() to find browser exe/binary
  - Handle private mode flags: --incognito (Chromium), -private (Firefox)
  - Ensure spawned process is detached (doesn't block Chowser)

  **Must NOT do**:
  - Don't break existing macOS launching (keep /usr/bin/open path)
  - Don't implement source-app features (disabled on Win/Linux)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: Complex platform-specific logic requiring careful implementation

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 5, 6, 7)
  - **Blocks**: Tasks 18, 28, 33-35
  - **Blocked By**: None

  **References**:
  - `chowser-electrobun/src/bun/browserLauncher.ts:1-100` — Current macOS-only implementation
  - `chowser-electrobun/src/bun/browserDetector.ts:resolveExecutablePath` — Platform-aware path resolution
  - macOS `BrowserManager.swift:launchInfo()` — Profile and private mode argument patterns

  **Acceptance Criteria**:
  - [ ] launchBrowser() works on Windows with Chrome profile
  - [ ] launchBrowser() works on Linux with Firefox profile
  - [ ] Private mode opens --incognito for Chrome, -private for Firefox
  - [ ] Process is detached (Chowser doesn't wait)

  **QA Scenarios**:
  ```
  Scenario: Launch Chrome with profile on Windows
    Tool: Bash (on Windows)
    Preconditions: Chrome installed with "Profile 1"
    Steps:
      1. Call launchBrowser("chrome", "Profile 1", "https://example.com", false)
      2. Check process list for chrome.exe with --profile-directory
    Expected Result: Chrome opens with correct profile
    Failure Indicators: Chrome doesn't open, wrong profile
    Evidence: .sisyphus/evidence/task-4-windows-chrome.txt

  Scenario: Launch Firefox in private mode on Linux
    Tool: Bash (on Linux)
    Preconditions: Firefox installed
    Steps:
      1. Call launchBrowser("firefox", null, "https://example.com", true)
      2. Check process list for firefox with -private flag
    Expected Result: Firefox opens in private mode
    Evidence: .sisyphus/evidence/task-4-linux-firefox.txt
  ```

  **Commit**: YES (groups with Wave 1)
  - Message: `feat(launcher): add Windows and Linux browser launching`
  - Files: `src/bun/browserLauncher.ts`

- [ ] 5. Add Windows/Linux build targets to electrobun.config.ts

  **What to do**:
  - Add `build.windows` section to electrobun.config.ts
  - Add `build.linux` section to electrobun.config.ts
  - Configure self-extracting package output paths
  - Add npm scripts: `build:windows`, `build:linux`, `package:windows`, `package:linux`
  - Test that electrobun CLI accepts the new config

  **Must NOT do**:
  - Don't configure NSIS/MSI (not supported by Electrobun)
  - Don't configure AppImage/deb (not supported)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Configuration task, straightforward

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4, 6, 7)
  - **Blocks**: Tasks 41, 42
  - **Blocked By**: None

  **References**:
  - `chowser-electrobun/electrobun.config.ts` — Current macOS-only config
  - Electrobun docs for cross-platform build configuration

  **Acceptance Criteria**:
  - [ ] electrobun.config.ts has build.windows and build.linux sections
  - [ ] package.json has build:windows and build:linux scripts
  - [ ] `npm run build:windows` runs without config errors

  **QA Scenarios**:
  ```
  Scenario: Windows build config is valid
    Tool: Bash
    Preconditions: None
    Steps:
      1. Run `npm run build:windows -- --dry-run` (or validate config)
      2. Check exit code
    Expected Result: No configuration errors
    Failure Indicators: "Invalid config", missing field errors
    Evidence: .sisyphus/evidence/task-5-windows-config.txt
  ```

  **Commit**: NO (groups with Task 4)

- [ ] 6. Create platform detection utilities

  **What to do**:
  - Create src/bun/platform.ts with platform detection functions
  - Export isWindows(), isLinux(), isMacOS() helpers
  - Export getPlatformConfigPath() for settings storage
  - Export getPlatformStartupPath() for launch-at-login registration
  - Export getDefaultBrowserRegistryPath() for Windows registry keys

  **Must NOT do**:
  - Don't duplicate existing browserDetector.ts platform logic (import it)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Simple utility functions

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4, 5, 7)
  - **Blocks**: Tasks 28, 33, 34, 35
  - **Blocked By**: None

  **References**:
  - `chowser-electrobun/src/bun/browserDetector.ts` — Existing platform checks
  - `chowser-electrobun/src/bun/config.ts` — Platform-aware config paths

  **Acceptance Criteria**:
  - [ ] platform.ts exports isWindows(), isLinux(), isMacOS()
  - [ ] Functions return correct values on each platform
  - [ ] getPlatformConfigPath() returns correct path per OS

  **QA Scenarios**:
  ```
  Scenario: Platform detection returns correct OS
    Tool: Bash
    Preconditions: None
    Steps:
      1. Run bun test for platform.ts
      2. Verify isWindows() === (process.platform === "win32")
    Expected Result: All platform functions return expected values
    Evidence: .sisyphus/evidence/task-6-platform.txt
  ```

  **Commit**: NO (groups with Task 4)

- [ ] 7. Set up Playwright for Electrobun UI testing

  **What to do**:
  - Install @playwright/test as dev dependency
  - Create playwright.config.ts with Electrobun webview configuration
  - Create tests/e2e/ directory for UI tests
  - Create a sample test that opens the picker view and verifies it loads
  - Add npm script: `test:e2e`

  **Must NOT do**:
  - Don't write all tests now (just setup + sample)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`playwright-best-practices`]
  - Reason: Standard Playwright setup

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1-6)
  - **Blocks**: Task F3
  - **Blocked By**: Task 1 (needs Svelte views to test)

  **References**:
  - `chowser-electrobun/package.json` — Add dev dependency
  - Playwright docs for Electron/WebView testing patterns

  **Acceptance Criteria**:
  - [ ] playwright.config.ts exists
  - [ ] `npm run test:e2e` runs sample test
  - [ ] Sample test passes (picker view loads)

  **QA Scenarios**:
  ```
  Scenario: Playwright test runs successfully
    Tool: Bash
    Preconditions: Dev server running, Svelte setup complete
    Steps:
      1. Run `npm run test:e2e`
      2. Check exit code is 0
      3. Check output shows "1 passed"
    Expected Result: Test passes
    Evidence: .sisyphus/evidence/task-7-playwright.txt
  ```

  **Commit**: YES (end of Wave 1)
  - Message: `feat(test): add Playwright E2E testing setup`
  - Files: `playwright.config.ts`, `tests/e2e/*.spec.ts`

- [x] 8. Build Picker shell component with glass effect background

  **What to do**:
  - Create src/views/picker/components/PickerShell.svelte
  - Implement glass effect background using backdrop-filter: blur(20px)
  - Add fallback for reduced transparency (solid background)
  - Include URL display area at top
  - Include browser selection area (slot for icons/list layout)
  - Include action bar at bottom (private mode toggle, create rule button)
  - Match macOS Chowser picker dimensions and padding

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 9-15)
  - **Blocks**: Tasks 16, 17
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - macOS `ContentView.swift` — Picker layout structure
  - macOS `PickerViewModifiers.swift:glassBackground()` — Glass effect implementation
  - `src/views/shared/tokens.css` — Design tokens

  **Acceptance Criteria**:
  - [ ] PickerShell.svelte renders with glass effect
  - [ ] Has slot for browser content
  - [ ] Has URL area and action bar
  - [ ] Fallback works when backdrop-filter unsupported

  **QA Scenarios**:
  ```
  Scenario: Picker shell renders with glass effect
    Tool: Playwright
    Steps:
      1. Open picker view
      2. Query .picker-shell element
      3. Get computed style backdrop-filter
      4. Assert contains "blur"
      5. Screenshot
    Expected Result: Glass effect visible
    Evidence: .sisyphus/evidence/task-8-picker-shell.png
  ```

  **Commit**: NO (groups with Wave 2)

- [x] 9. Build BrowserIcon component with size variants

  **What to do**:
  - Create src/views/shared/components/BrowserIcon.svelte
  - Accept props: browserBundleId, size (small/medium/large), showLabel, isSelected
  - Render browser icon image with proper sizing (24px, 32px, 48px)
  - Show keyboard shortcut badge (1-9) if assigned
  - Show label below icon when showLabel=true
  - Apply selected state styling (highlight ring)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 8, 10-15)
  - **Blocks**: Task 16
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - macOS `BrowserCardView.swift` — Icon card design
  - macOS `ContentView.swift:browserIconButton()` — Icon button behavior

  **Acceptance Criteria**:
  - [ ] Renders icon at 3 size variants
  - [ ] Shows shortcut badge when assigned
  - [ ] Shows label when showLabel=true
  - [ ] Selected state has visual indicator

  **QA Scenarios**:
  ```
  Scenario: Browser icon shows shortcut badge
    Tool: Playwright
    Steps:
      1. Render BrowserIcon with shortcutKey="1"
      2. Query .shortcut-badge
      3. Assert text content is "1"
    Expected Result: Badge shows "1"
    Evidence: .sisyphus/evidence/task-9-icon-badge.png
  ```

  **Commit**: NO (groups with Wave 2)

- [x] 10. Build BrowserListItem component

  **What to do**:
  - Create src/views/shared/components/BrowserListItem.svelte
  - Show browser icon (small), name, profile name (if any)
  - Show keyboard shortcut on right side
  - Apply hover and selected states
  - Support click handler for selection

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 8-9, 11-15)
  - **Blocks**: Task 17
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - macOS `ContentView.swift:browserListRow()` — List row design

  **Acceptance Criteria**:
  - [ ] Shows icon, name, profile, shortcut
  - [ ] Hover state changes background
  - [ ] Selected state is visually distinct

  **QA Scenarios**:
  ```
  Scenario: List item shows profile name
    Tool: Playwright
    Steps:
      1. Render BrowserListItem with profile="Work"
      2. Query .profile-name
      3. Assert text contains "Work"
    Expected Result: Profile name visible
    Evidence: .sisyphus/evidence/task-10-list-item.png
  ```

  **Commit**: NO (groups with Wave 2)

- [x] 11. Build URL bubble component with copy/unshorten actions

  **What to do**:
  - Create src/views/picker/components/UrlBubble.svelte
  - Display URL with truncation for long URLs
  - Show unshorten progress indicator when active
  - Copy button with clipboard API
  - Unshorten button (H key trigger)
  - Error indicator for unshorten failures

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 8-10, 12-15)
  - **Blocks**: Task 37
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - macOS `ContentView.swift:urlBubble()` — URL display design
  - macOS `BrowserManager.swift:unshortenURL()` — Unshorten logic

  **Acceptance Criteria**:
  - [ ] URL displays with proper truncation
  - [ ] Copy button copies to clipboard
  - [ ] Progress indicator shows during unshorten
  - [ ] Error state displays failure message

  **QA Scenarios**:
  ```
  Scenario: Copy button copies URL to clipboard
    Tool: Playwright
    Steps:
      1. Set URL to "https://example.com"
      2. Click copy button
      3. Read clipboard
      4. Assert clipboard equals URL
    Expected Result: URL in clipboard
    Evidence: .sisyphus/evidence/task-11-url-copy.txt
  ```

  **Commit**: NO (groups with Wave 2)

- [x] 12. Build Settings shell with sidebar navigation

  **What to do**:
  - Create src/views/settings/components/SettingsShell.svelte
  - Sidebar with navigation items: Browsers, Rules, General, Hidden Apps
  - Main content area (slot)
  - Active tab indicator in sidebar
  - Match macOS Settings window proportions

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 8-11, 13-15)
  - **Blocks**: Tasks 20-24
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - macOS `SettingsView.swift` — Settings layout with NavigationSplitView

  **Acceptance Criteria**:
  - [ ] Sidebar shows all 4 tabs
  - [ ] Clicking tab changes active state
  - [ ] Content slot renders correctly

  **QA Scenarios**:
  ```
  Scenario: Tab navigation works
    Tool: Playwright
    Steps:
      1. Click "Rules" tab
      2. Assert Rules tab has active class
      3. Assert content area shows rules content
    Expected Result: Tab switch works
    Evidence: .sisyphus/evidence/task-12-settings-nav.png
  ```

  **Commit**: NO (groups with Wave 2)

- [ ] 13. Build BrowserConfigRow component for settings

  **What to do**:
  - Create src/views/settings/components/BrowserConfigRow.svelte
  - Show browser icon, name, profile
  - Editable shortcut key input
  - Custom arguments input (expandable)
  - Delete button
  - Drag handle for reordering

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 8-12, 14-15)
  - **Blocks**: Task 20
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - macOS `BrowserConfigRow.swift` — Row design and behavior

  **Acceptance Criteria**:
  - [ ] Shows all browser info
  - [ ] Shortcut key editable
  - [ ] Custom args expandable
  - [ ] Delete confirmation works

  **QA Scenarios**:
  ```
  Scenario: Shortcut key can be changed
    Tool: Playwright
    Steps:
      1. Find shortcut input
      2. Clear and type "2"
      3. Blur input
      4. Assert value saved
    Expected Result: Shortcut updated
    Evidence: .sisyphus/evidence/task-13-shortcut-edit.png
  ```

  **Commit**: NO (groups with Wave 2)

- [ ] 14. Build RuleRow component for settings

  **What to do**:
  - Create src/views/settings/components/RuleRow.svelte
  - Show rule pattern, target browser, status (enabled/disabled)
  - Enable/disable toggle
  - Edit button → opens edit sheet
  - Delete button with confirmation
  - Duplicate button

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 8-13, 15)
  - **Blocks**: Task 21
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - macOS `RuleRowView.swift` — Rule row design
  - macOS `RuleUIComponents.swift` — Shared rule UI

  **Acceptance Criteria**:
  - [ ] Shows pattern, browser, status
  - [ ] Toggle enables/disables
  - [ ] Edit opens sheet
  - [ ] Duplicate creates copy

  **QA Scenarios**:
  ```
  Scenario: Toggle disables rule
    Tool: Playwright
    Steps:
      1. Find enabled rule toggle
      2. Click toggle
      3. Assert rule.isEnabled is false
    Expected Result: Rule disabled
    Evidence: .sisyphus/evidence/task-14-rule-toggle.png
  ```

  **Commit**: NO (groups with Wave 2)

- [ ] 15. Build reusable Modal/Sheet component

  **What to do**:
  - Create src/views/shared/components/Modal.svelte
  - Overlay background with click-to-close
  - Centered content with max-width
  - Close button in corner
  - Escape key to close
  - Slide-up animation

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 8-14)
  - **Blocks**: Tasks 19, 20, 21, 24
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - macOS `AddRuleSheet.swift` — Sheet pattern
  - macOS `AddBrowserSheet.swift` — Sheet pattern

  **Acceptance Criteria**:
  - [ ] Renders centered content
  - [ ] Closes on overlay click
  - [ ] Closes on Escape
  - [ ] Has animation

  **QA Scenarios**:
  ```
  Scenario: Modal closes on Escape
    Tool: Playwright
    Steps:
      1. Open modal
      2. Press Escape key
      3. Assert modal not visible
    Expected Result: Modal closed
    Evidence: .sisyphus/evidence/task-15-modal-escape.txt
  ```

  **Commit**: YES (end of Wave 2)
  - Message: `feat(ui): add core Svelte components for picker and settings`
  - Files: `src/views/*/components/*.svelte`

- [x] 16. Implement Picker icons layout mode

  **What to do**:
  - Create src/views/picker/layouts/IconsLayout.svelte
  - Horizontal scrollable row of BrowserIcon components
  - Support icon size preference (small/medium/large)
  - Support showLabels preference
  - Highlight selected browser
  - Keyboard navigation (left/right arrows)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 17-25)
  - **Blocks**: Task 18
  - **Blocked By**: Tasks 8, 9

  **References**:
  - macOS `ContentView.swift:browserIconsLayout()` — Icons layout implementation

  **Acceptance Criteria**:
  - [ ] Icons display horizontally
  - [ ] Selected browser highlighted
  - [ ] Arrow keys change selection
  - [ ] Scrolls when many browsers

  **QA Scenarios**:
  ```
  Scenario: Arrow keys navigate icons
    Tool: Playwright
    Steps:
      1. Open picker with 5 browsers
      2. Press right arrow
      3. Assert second browser selected
      4. Press left arrow
      5. Assert first browser selected
    Expected Result: Selection moves with arrows
    Evidence: .sisyphus/evidence/task-16-icons-nav.png
  ```

  **Commit**: NO (groups with Wave 3)

- [x] 17. Implement Picker list layout mode

  **What to do**:
  - Create src/views/picker/layouts/ListLayout.svelte
  - Vertical scrollable list of BrowserListItem components
  - Show all browser info (name, profile, shortcut)
  - Highlight selected browser
  - Keyboard navigation (up/down arrows)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16, 18-25)
  - **Blocks**: Task 18
  - **Blocked By**: Tasks 8, 10

  **References**:
  - macOS `ContentView.swift:browserListLayout()` — List layout implementation

  **Acceptance Criteria**:
  - [ ] List displays vertically
  - [ ] Shows name, profile, shortcut
  - [ ] Up/down arrows navigate
  - [ ] Scrolls for long lists

  **QA Scenarios**:
  ```
  Scenario: List shows profiles
    Tool: Playwright
    Steps:
      1. Add browser with profile "Work"
      2. Open picker in list mode
      3. Find list item with "Work"
    Expected Result: Profile visible in list
    Evidence: .sisyphus/evidence/task-17-list-profile.png
  ```

  **Commit**: NO (groups with Wave 3)

- [x] 18. Implement Picker keyboard handling (1-9, arrows, P, H, R)

  **What to do**:
  - Add keydown event listener to picker window
  - Number keys 1-9: directly open browser with matching shortcut
  - Arrow keys: move selection (left/right for icons, up/down for list)
  - Enter/Space: open selected browser
  - P: toggle private mode
  - H/S: trigger URL unshorten
  - R: open quick rule creation
  - Option+Enter: open in private mode
  - Tab/Shift-Tab: cycle selection
  - Initial letter typing: select browser starting with letter

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential after Tasks 16, 17
  - **Blocks**: None (critical feature)
  - **Blocked By**: Tasks 4, 16, 17

  **References**:
  - macOS `ContentView.swift:handlePickerKeyDown()` — Complete keyboard handling
  - macOS `ContentView.swift:normalizedShortcutKey()` — Shortcut mapping

  **Acceptance Criteria**:
  - [ ] 1-9 opens correct browser
  - [ ] Arrows move selection
  - [ ] P toggles private mode indicator
  - [ ] H triggers unshorten
  - [ ] R opens rule creation modal

  **QA Scenarios**:
  ```
  Scenario: Number key opens browser
    Tool: Playwright
    Steps:
      1. Open picker with browser shortcut "1"
      2. Press "1" key
      3. Assert launchBrowser called with correct browser
    Expected Result: Browser launches
    Evidence: .sisyphus/evidence/task-18-shortcut.txt

  Scenario: P key toggles private mode
    Tool: Playwright
    Steps:
      1. Open picker
      2. Assert private mode indicator OFF
      3. Press "P"
      4. Assert private mode indicator ON
    Expected Result: Private mode toggled
    Evidence: .sisyphus/evidence/task-18-private.png
  ```

  **Commit**: NO (groups with Wave 3)

- [x] 19. Implement quick rule creation from picker

  **What to do**:
  - Create src/views/picker/components/QuickRuleSheet.svelte
  - Pre-fill host from current URL
  - Browser dropdown (select target browser)
  - Profile dropdown (if browser has profiles)
  - Private mode checkbox
  - Save creates rule and closes picker
  - Cancel returns to picker

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-18, 20-25)
  - **Blocks**: None
  - **Blocked By**: Tasks 8, 15

  **References**:
  - macOS `ConfigureRuleView.swift` — Quick rule creation UI
  - macOS `AddRuleSheet.swift` — Full rule sheet

  **Acceptance Criteria**:
  - [ ] Host pre-filled from URL
  - [ ] Browser dropdown works
  - [ ] Save creates rule
  - [ ] R key opens this sheet

  **QA Scenarios**:
  ```
  Scenario: Host is pre-filled from URL
    Tool: Playwright
    Steps:
      1. Set current URL to "https://github.com/test"
      2. Press R to open quick rule
      3. Assert host field contains "github.com"
    Expected Result: Host pre-filled
    Evidence: .sisyphus/evidence/task-19-prefill.png
  ```

  **Commit**: NO (groups with Wave 3)

- [x] 20. Implement Settings Browsers tab with full CRUD

  **What to do**:
  - Create src/views/settings/tabs/BrowsersTab.svelte
  - List all configured browsers using BrowserConfigRow
  - "Detect Browsers" button → calls detectInstalledBrowsers RPC
  - "Add Browser" button → opens add browser modal
  - Drag-to-reorder with sortable library
  - Import/Export buttons in toolbar
  - Edit browser → opens edit modal
  - Delete with confirmation

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-19, 21-25)
  - **Blocks**: Task 24
  - **Blocked By**: Tasks 12, 13, 15

  **References**:
  - macOS `SettingsView+Browsers.swift` — Browsers tab implementation
  - macOS `AddBrowserSheet.swift` — Add browser modal
  - macOS `EditBrowserSheet.swift` — Edit browser modal

  **Acceptance Criteria**:
  - [ ] Lists all browsers
  - [ ] Detect adds new browsers
  - [ ] Add/Edit modals work
  - [ ] Drag reorder persists
  - [ ] Delete removes browser

  **QA Scenarios**:
  ```
  Scenario: Detect browsers finds Chrome
    Tool: Playwright
    Preconditions: Chrome installed
    Steps:
      1. Click "Detect Browsers"
      2. Wait for detection
      3. Assert Chrome appears in list
    Expected Result: Chrome detected
    Evidence: .sisyphus/evidence/task-20-detect.png
  ```

  **Commit**: NO (groups with Wave 3)

- [x] 21. Implement Settings Rules tab with master-detail

  **What to do**:
  - Create src/views/settings/tabs/RulesTab.svelte
  - List all rules grouped by target browser
  - Rule tester input (type URL, see which rule matches)
  - Add Rule button → opens add rule modal
  - Edit rule → opens edit modal with all fields
  - Duplicate rule creates copy with new ID
  - Enable/disable toggle inline
  - Support regex rules (useRegex checkbox)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-20, 22-25)
  - **Blocks**: Task 24
  - **Blocked By**: Tasks 12, 14, 15

  **References**:
  - macOS `SettingsView+Rules.swift` — Rules tab implementation
  - macOS `AddRuleSheet.swift` — Add/Edit rule modal
  - macOS `BrowserManager.swift:resolveRoute()` — Rule matching for tester

  **Acceptance Criteria**:
  - [ ] Rules listed and grouped
  - [ ] Rule tester shows matches
  - [ ] Add/Edit modals work
  - [ ] Regex rules can be created
  - [ ] Duplicate creates copy

  **QA Scenarios**:
  ```
  Scenario: Rule tester shows matching rule
    Tool: Playwright
    Steps:
      1. Create rule for "*.github.com" → Chrome
      2. Type "https://github.com/test" in tester
      3. Assert shows "Matches: Chrome"
    Expected Result: Rule match displayed
    Evidence: .sisyphus/evidence/task-21-tester.png
  ```

  **Commit**: NO (groups with Wave 3)

- [x] 22. Implement Settings General tab

  **What to do**:
  - Create src/views/settings/tabs/GeneralTab.svelte
  - Picker layout dropdown (icons/list)
  - Icon size dropdown (small/medium/large)
  - Show labels toggle
  - Launch at login toggle (platform-specific)
  - Set as default browser button (opens OS settings)
  - MCP Server section (start/stop toggle, port display, token copy)
  - Reset to defaults button
  - About section with version

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-21, 23-25)
  - **Blocks**: None
  - **Blocked By**: Tasks 12

  **References**:
  - macOS `SettingsView+General.swift` — General tab implementation
  - macOS `MCPServerSettingsRow` — MCP server controls

  **Acceptance Criteria**:
  - [ ] All preferences save correctly
  - [ ] MCP server can be started/stopped
  - [ ] Default browser button works per platform
  - [ ] Reset clears preferences

  **QA Scenarios**:
  ```
  Scenario: Layout preference changes picker
    Tool: Playwright
    Steps:
      1. Open General tab
      2. Change layout to "list"
      3. Open picker
      4. Assert list layout shown
    Expected Result: Layout changed
    Evidence: .sisyphus/evidence/task-22-layout.png
  ```

  **Commit**: NO (groups with Wave 3)

- [x] 23. Implement Settings Hidden Apps tab

  **What to do**:
  - Create src/views/settings/tabs/HiddenAppsTab.svelte
  - List currently hidden bundle IDs
  - Unhide button for each entry
  - Add bundle ID input for manual hiding
  - Clear all button

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-22, 24-25)
  - **Blocks**: None
  - **Blocked By**: Task 12

  **References**:
  - macOS `SettingsView+General.swift` — Hidden apps section

  **Acceptance Criteria**:
  - [ ] Lists hidden apps
  - [ ] Unhide removes from list
  - [ ] Add adds new bundle ID
  - [ ] Clear all removes all

  **QA Scenarios**:
  ```
  Scenario: Hide and unhide app
    Tool: Playwright
    Steps:
      1. Add bundle ID "com.test.app"
      2. Assert it appears in list
      3. Click Unhide
      4. Assert it's removed
    Expected Result: Hide/unhide works
    Evidence: .sisyphus/evidence/task-23-hidden.png
  ```

  **Commit**: NO (groups with Wave 3)

- [x] 24. Implement import/export UI for browsers and rules

  **What to do**:
  - Add Import/Export buttons to Browsers tab toolbar
  - Add Import/Export buttons to Rules tab toolbar
  - Import: file picker → parse JSON → merge into state
  - Export: generate JSON → save dialog
  - Show success/error toast notification

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-23, 25)
  - **Blocks**: None
  - **Blocked By**: Tasks 15, 20, 21

  **References**:
  - macOS `BrowserManager.swift:exportBrowsers/importBrowsers` — Export/import logic
  - macOS `SettingsView+Browsers.swift` — Import/export UI triggers

  **Acceptance Criteria**:
  - [ ] Export creates valid JSON file
  - [ ] Import merges with existing data
  - [ ] Success notification shown
  - [ ] Error handling for invalid JSON

  **QA Scenarios**:
  ```
  Scenario: Export and reimport rules
    Tool: Playwright
    Steps:
      1. Create rule
      2. Export rules to file
      3. Delete rule
      4. Import from file
      5. Assert rule restored
    Expected Result: Round-trip works
    Evidence: .sisyphus/evidence/task-24-import.txt
  ```

  **Commit**: NO (groups with Wave 3)

- [x] 25. Implement Temporary Focus Mode UI

  **What to do**:
  - Add focus mode controls to picker UI
  - Show current focus status (if active)
  - Menu options: Focus for 1 Hour, Focus Until Tomorrow, Clear Focus
  - When focus active, all URLs route to focused browser
  - Show countdown/expiry time

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-24)
  - **Blocks**: None
  - **Blocked By**: Task 8

  **References**:
  - macOS `AppDelegate.swift` — Focus mode menu items
  - macOS `BrowserManager.swift:setTemporaryRoute()` — Focus mode logic

  **Acceptance Criteria**:
  - [ ] Focus mode can be set
  - [ ] All URLs route to focused browser
  - [ ] Focus expires after duration
  - [ ] Clear focus removes it immediately

  **QA Scenarios**:
  ```
  Scenario: Focus mode routes all URLs
    Tool: Bash
    Steps:
      1. Set focus to Chrome for 1 hour
      2. Open any URL
      3. Assert Chrome launched (not picker shown)
    Expected Result: Focus overrides rules
    Evidence: .sisyphus/evidence/task-25-focus.txt
  ```

  **Commit**: YES (end of Wave 3)
  - Message: `feat(ui): implement complete picker and settings functionality`
  - Files: `src/views/picker/**/*.svelte`, `src/views/settings/**/*.svelte`

- [x] 26. Build Onboarding wizard shell with step navigation

  **What to do**:
  - Create src/views/onboarding/OnboardingShell.svelte
  - Step indicator showing current step (1-5)
  - Back/Next navigation buttons
  - Skip button for optional steps
  - Progress bar
  - Window chrome with close button

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 27-35)
  - **Blocks**: Tasks 27-32
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - macOS `OnboardingView.swift` — Onboarding flow controller

  **Acceptance Criteria**:
  - [ ] Step indicator shows 5 steps
  - [ ] Back/Next navigate between steps
  - [ ] Progress bar updates
  - [ ] Close button dismisses wizard

  **QA Scenarios**:
  ```
  Scenario: Navigate through all steps
    Tool: Playwright
    Steps:
      1. Open onboarding
      2. Click Next 4 times
      3. Assert on step 5
      4. Assert progress bar at 100%
    Expected Result: Navigation works
    Evidence: .sisyphus/evidence/task-26-onboarding-nav.png
  ```

  **Commit**: NO (groups with Wave 4)

- [x] 27. Implement Welcome step

  **What to do**:
  - Create src/views/onboarding/steps/WelcomeStep.svelte
  - App logo and name
  - Welcome message explaining what Chowser does
  - "Get Started" button to proceed

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26, 28-35)
  - **Blocks**: None
  - **Blocked By**: Task 26

  **References**:
  - macOS `OnboardingSteps.swift:WelcomeStepView` — Welcome step content

  **Acceptance Criteria**:
  - [ ] Logo displays
  - [ ] Welcome text explains app
  - [ ] Get Started advances to step 2

  **QA Scenarios**:
  ```
  Scenario: Welcome step displays
    Tool: Playwright
    Steps:
      1. Open onboarding
      2. Assert logo visible
      3. Assert "Get Started" button visible
    Expected Result: Welcome content shown
    Evidence: .sisyphus/evidence/task-27-welcome.png
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 28. Implement Default Browser step with platform-specific registration

  **What to do**:
  - Create src/views/onboarding/steps/DefaultBrowserStep.svelte
  - Explain why setting as default is needed
  - "Set as Default" button triggers platform registration:
    - Windows: Open ms-settings:defaultapps
    - Linux: Run xdg-settings set default-web-browser
    - macOS: Open System Settings
  - Auto-detect if already default (show checkmark)
  - Skip option if user declines

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-27, 29-35)
  - **Blocks**: None
  - **Blocked By**: Tasks 4, 6, 26

  **References**:
  - macOS `OnboardingSteps.swift:DefaultBrowserStepView` — Default browser step
  - `src/bun/platform.ts` — Platform detection utilities

  **Acceptance Criteria**:
  - [ ] Opens correct system settings per platform
  - [ ] Auto-detects if already default
  - [ ] Skip option available
  - [ ] Checkmark shows when set

  **QA Scenarios**:
  ```
  Scenario: Windows opens system settings
    Tool: Bash (Windows)
    Steps:
      1. Click "Set as Default"
      2. Assert ms-settings:defaultapps opened
    Expected Result: Settings app opens
    Evidence: .sisyphus/evidence/task-28-windows-default.txt

  Scenario: Linux runs xdg-settings
    Tool: Bash (Linux)
    Steps:
      1. Click "Set as Default"
      2. Check xdg-settings was called
    Expected Result: xdg-settings executed
    Evidence: .sisyphus/evidence/task-28-linux-default.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [x] 29. Implement Browsers detection step

  **What to do**:
  - Create src/views/onboarding/steps/BrowsersStep.svelte
  - Show detected browsers with icons
  - Explain that profiles were found
  - Allow unchecking browsers to exclude
  - "Detect Again" button to refresh

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-28, 30-35)
  - **Blocks**: None
  - **Blocked By**: Task 26

  **References**:
  - macOS `OnboardingSteps.swift:BrowsersStepView` — Browsers step

  **Acceptance Criteria**:
  - [ ] Shows detected browsers
  - [ ] Checkbox to include/exclude
  - [ ] Detect Again refreshes list
  - [ ] Shows profile count

  **QA Scenarios**:
  ```
  Scenario: Browsers are auto-detected
    Tool: Playwright
    Steps:
      1. Navigate to Browsers step
      2. Assert at least one browser shown
    Expected Result: Browsers detected
    Evidence: .sisyphus/evidence/task-29-browsers.png
  ```

  **Commit**: NO (groups with Wave 4)

- [x] 30. Implement AI Setup step (MCP server)

  **What to do**:
  - Create src/views/onboarding/steps/AISetupStep.svelte
  - Explain MCP server for AI integration
  - Start Server button
  - Copy token button
  - Copy setup prompt for AI assistants
  - Skip option for non-AI users

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-29, 31-35)
  - **Blocks**: None
  - **Blocked By**: Task 26

  **References**:
  - macOS `OnboardingSteps.swift:AISetupStepView` — AI setup step
  - macOS `MCPServer.swift` — MCP server functionality

  **Acceptance Criteria**:
  - [ ] Start server works
  - [ ] Token can be copied
  - [ ] Setup prompt copied to clipboard
  - [ ] Skip advances to next step

  **QA Scenarios**:
  ```
  Scenario: Copy token to clipboard
    Tool: Playwright
    Steps:
      1. Start MCP server
      2. Click "Copy Token"
      3. Assert clipboard contains token
    Expected Result: Token copied
    Evidence: .sisyphus/evidence/task-30-token.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [x] 31. Implement Rules introduction step

  **What to do**:
  - Create src/views/onboarding/steps/RulesStep.svelte
  - Explain smart routing concept
  - Show example rules (work URLs → Chrome, personal → Firefox)
  - Explain rule creation (from picker or settings)
  - Link to settings for advanced configuration

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-30, 32-35)
  - **Blocks**: None
  - **Blocked By**: Task 26

  **References**:
  - macOS `OnboardingSteps.swift:RulesStepView` — Rules step

  **Acceptance Criteria**:
  - [ ] Explains routing concept
  - [ ] Shows example rules
  - [ ] Mentions picker rule creation

  **QA Scenarios**:
  ```
  Scenario: Rules step shows examples
    Tool: Playwright
    Steps:
      1. Navigate to Rules step
      2. Assert "example" or sample rules visible
    Expected Result: Examples shown
    Evidence: .sisyphus/evidence/task-31-rules.png
  ```

  **Commit**: NO (groups with Wave 4)

- [x] 32. Implement Finish step with completion handling

  **What to do**:
  - Create src/views/onboarding/steps/FinishStep.svelte
  - Success message
  - Summary of what was set up
  - "Open Settings" button to configure more
  - "Start Using Chowser" closes wizard
  - Mark onboarding as completed in storage
  - Open settings window on completion

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-31, 33-35)
  - **Blocks**: None
  - **Blocked By**: Task 26

  **References**:
  - macOS `OnboardingSteps.swift:FinishStepView` — Finish step
  - macOS `OnboardingManager.swift:closeOnboardingWindow()` — Completion handling

  **Acceptance Criteria**:
  - [ ] Shows completion message
  - [ ] Marks onboarding complete
  - [ ] Opens settings on "Open Settings"
  - [ ] Closes wizard properly

  **QA Scenarios**:
  ```
  Scenario: Completion marks onboarding done
    Tool: Bash
    Steps:
      1. Complete onboarding wizard
      2. Check state.json for hasCompletedOnboarding
    Expected Result: Flag is true
    Evidence: .sisyphus/evidence/task-32-complete.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 33. Implement launch-at-login for Windows

  **What to do**:
  - Create platform-specific startup registration
  - Windows: Add registry key to HKCU\Software\Microsoft\Windows\CurrentVersion\Run
  - Or create shortcut in Startup folder
  - Toggle controlled from Settings General tab
  - Verify registration works after reboot

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-32, 34-35)
  - **Blocks**: None
  - **Blocked By**: Tasks 4, 6

  **References**:
  - macOS `BrowserManager.swift:launchAtLogin` — Toggle pattern
  - Windows registry documentation for startup apps

  **Acceptance Criteria**:
  - [ ] Toggle adds/removes registry entry
  - [ ] App starts on Windows boot when enabled
  - [ ] State persisted correctly

  **QA Scenarios**:
  ```
  Scenario: Enable launch at login on Windows
    Tool: Bash (Windows)
    Steps:
      1. Enable launch at login in settings
      2. Query registry HKCU\...\Run for Chowser
      3. Assert entry exists
    Expected Result: Registry entry present
    Evidence: .sisyphus/evidence/task-33-windows-startup.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 34. Implement launch-at-login for Linux

  **What to do**:
  - Create .desktop file in ~/.config/autostart/
  - Toggle controlled from Settings General tab
  - File should point to Chowser executable
  - Remove file when disabled

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-33, 35)
  - **Blocks**: None
  - **Blocked By**: Tasks 4, 6

  **References**:
  - XDG autostart specification
  - Linux desktop entry format

  **Acceptance Criteria**:
  - [ ] Toggle creates/removes .desktop file
  - [ ] App starts on Linux login when enabled
  - [ ] Works on GNOME, KDE, XFCE

  **QA Scenarios**:
  ```
  Scenario: Enable launch at login on Linux
    Tool: Bash (Linux)
    Steps:
      1. Enable launch at login
      2. Check ~/.config/autostart/ for chowser.desktop
      3. Assert file exists with correct Exec path
    Expected Result: Desktop file created
    Evidence: .sisyphus/evidence/task-34-linux-startup.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 35. Implement default browser registration for Linux

  **What to do**:
  - Create chowser.desktop file with MimeType handlers
  - Use xdg-settings set default-web-browser
  - Register for x-scheme-handler/http and https
  - Add to ~/.local/share/applications/

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-34)
  - **Blocks**: None
  - **Blocked By**: Tasks 4, 6

  **References**:
  - XDG desktop entry specification
  - xdg-settings documentation

  **Acceptance Criteria**:
  - [ ] chowser.desktop created with correct MimeTypes
  - [ ] xdg-settings sets default browser
  - [ ] Works on major desktop environments

  **QA Scenarios**:
  ```
  Scenario: Set as default browser on Linux
    Tool: Bash (Linux)
    Steps:
      1. Run default browser registration
      2. Query xdg-settings get default-web-browser
      3. Assert returns chowser.desktop
    Expected Result: Chowser is default
    Evidence: .sisyphus/evidence/task-35-linux-default.txt
  ```

  **Commit**: YES (end of Wave 4)
  - Message: `feat(onboarding): add multi-step wizard and platform integrations`
  - Files: `src/views/onboarding/**/*.svelte`, `src/bun/platform.ts`

- [ ] 36. Add domain frequency tracking UI (suggestion banner)

  **What to do**:
  - Create suggestion banner component in picker
  - Show when domain has 30+ clicks with 60% browser dominance
  - Display "Always open [domain] in [browser]?" message
  - Click opens quick rule creation with pre-filled values
  - Dismiss option that hides for this session

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 37-45)
  - **Blocks**: None
  - **Blocked By**: Tasks 16, 17

  **References**:
  - macOS `DomainFrequencyTracker.swift` — Tracking and suggestion logic
  - macOS `ContentView.swift:suggestedBrowserBundleId` — Suggestion display

  **Acceptance Criteria**:
  - [ ] Banner appears after threshold met
  - [ ] Click creates rule
  - [ ] Dismiss hides banner
  - [ ] Only shows when no existing rule matches

  **QA Scenarios**:
  ```
  Scenario: Suggestion banner appears after threshold
    Tool: Bash
    Steps:
      1. Simulate 30 clicks to github.com → Chrome
      2. Open picker for github.com URL
      3. Assert suggestion banner visible
    Expected Result: Banner shows suggestion
    Evidence: .sisyphus/evidence/task-36-suggestion.png
  ```

  **Commit**: NO (groups with Wave 5)

- [ ] 37. Implement URL cleaning and unshortening UI

  **What to do**:
  - Wire up URL cleaning (already in routing.ts)
  - Show cleaned URL in picker (tracking params removed)
  - Manual unshorten button (H key)
  - Progress indicator during unshorten
  - Error display for failed unshorten
  - Show original vs cleaned URL toggle

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 36, 38-45)
  - **Blocks**: None
  - **Blocked By**: Task 11

  **References**:
  - macOS `BrowserManager.swift:cleanURL()` — URL cleaning
  - macOS `BrowserManager.swift:unshortenURL()` — Unshorten logic

  **Acceptance Criteria**:
  - [ ] URLs cleaned automatically
  - [ ] H key triggers unshorten
  - [ ] Progress shown during unshorten
  - [ ] Error displayed on failure

  **QA Scenarios**:
  ```
  Scenario: Tracking params removed
    Tool: Playwright
    Steps:
      1. Open picker with URL containing ?utm_source=test
      2. Assert displayed URL lacks utm_source
    Expected Result: Clean URL shown
    Evidence: .sisyphus/evidence/task-37-clean.txt
  ```

  **Commit**: NO (groups with Wave 5)

- [ ] 38. Implement clipboard URL handling

  **What to do**:
  - Add clipboard URL detection in tray menu
  - "Open Clipboard URL" menu item
  - Sub-items: "Open in Browser", "Open in Private"
  - Validate URL is http/https before showing
  - Open picker with clipboard URL when clicked

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 36-37, 39-45)
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - macOS `AppDelegate.swift:clipboardURL()` — Clipboard detection
  - macOS `AppDelegate.swift:openClipboardURL()` — Handler

  **Acceptance Criteria**:
  - [ ] Menu shows clipboard URL when valid
  - [ ] Opens picker with URL
  - [ ] Private mode option works
  - [ ] Hidden when clipboard is not a URL

  **QA Scenarios**:
  ```
  Scenario: Clipboard URL appears in menu
    Tool: Bash
    Steps:
      1. Copy "https://example.com" to clipboard
      2. Open tray menu
      3. Assert "Open Clipboard URL" visible
    Expected Result: Menu item shown
    Evidence: .sisyphus/evidence/task-38-clipboard.png
  ```

  **Commit**: NO (groups with Wave 5)

- [ ] 39. Add unit tests for cross-platform launcher

  **What to do**:
  - Create src/bun/browserLauncher.test.ts
  - Test launchBrowser() with mock spawn
  - Test Windows profile argument format
  - Test Linux profile argument format
  - Test private mode flags per browser type
  - Test error handling for missing browser

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 36-38, 40-45)
  - **Blocks**: None
  - **Blocked By**: Task 4

  **References**:
  - `src/bun/browserLauncher.ts` — Implementation to test
  - Existing test patterns in `src/bun/*.test.ts`

  **Acceptance Criteria**:
  - [ ] Tests for Windows launching
  - [ ] Tests for Linux launching
  - [ ] Tests for profile arguments
  - [ ] Tests for private mode

  **QA Scenarios**:
  ```
  Scenario: Launcher tests pass
    Tool: Bash
    Steps:
      1. Run bun test browserLauncher.test.ts
      2. Assert all tests pass
    Expected Result: 0 failures
    Evidence: .sisyphus/evidence/task-39-launcher-tests.txt
  ```

  **Commit**: NO (groups with Wave 5)

- [ ] 40. Add unit tests for platform detection utilities

  **What to do**:
  - Create src/bun/platform.test.ts
  - Test isWindows(), isLinux(), isMacOS()
  - Test getPlatformConfigPath() returns correct paths
  - Test getPlatformStartupPath()
  - Mock process.platform for cross-platform testing

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 36-39, 41-45)
  - **Blocks**: None
  - **Blocked By**: Task 6

  **References**:
  - `src/bun/platform.ts` — Implementation to test

  **Acceptance Criteria**:
  - [ ] Tests for platform detection
  - [ ] Tests for config paths
  - [ ] Tests for startup paths
  - [ ] All tests pass

  **QA Scenarios**:
  ```
  Scenario: Platform tests pass
    Tool: Bash
    Steps:
      1. Run bun test platform.test.ts
      2. Assert all tests pass
    Expected Result: 0 failures
    Evidence: .sisyphus/evidence/task-40-platform-tests.txt
  ```

  **Commit**: NO (groups with Wave 5)

- [ ] 41. Configure Windows self-extracting package

  **What to do**:
  - Configure Electrobun Windows packaging in electrobun.config.ts
  - Set application metadata (name, version, description)
  - Configure icon for .exe
  - Set output path for Windows build
  - Test package creation works

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 36-40, 42-45)
  - **Blocks**: None
  - **Blocked By**: Task 5

  **References**:
  - `electrobun.config.ts` — Build configuration
  - Electrobun documentation for Windows packaging

  **Acceptance Criteria**:
  - [ ] npm run package:windows produces .exe
  - [ ] Icon embedded correctly
  - [ ] Metadata correct in file properties
  - [ ] Package runs on Windows

  **QA Scenarios**:
  ```
  Scenario: Windows package created
    Tool: Bash
    Steps:
      1. Run npm run package:windows
      2. Assert .exe file exists in build/
      3. Check file size is reasonable (>5MB)
    Expected Result: Package created
    Evidence: .sisyphus/evidence/task-41-windows-pkg.txt
  ```

  **Commit**: NO (groups with Wave 5)

- [ ] 42. Configure Linux tarball package

  **What to do**:
  - Configure Electrobun Linux packaging
  - Set application metadata
  - Include chowser.desktop file for integration
  - Configure icon
  - Set output path for Linux build
  - Test package extraction and running

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 36-41, 43-45)
  - **Blocks**: None
  - **Blocked By**: Task 5

  **References**:
  - `electrobun.config.ts` — Build configuration
  - Electrobun documentation for Linux packaging

  **Acceptance Criteria**:
  - [ ] npm run package:linux produces tarball
  - [ ] Desktop file included
  - [ ] Icon included
  - [ ] Tarball extracts and runs

  **QA Scenarios**:
  ```
  Scenario: Linux package created
    Tool: Bash
    Steps:
      1. Run npm run package:linux
      2. Assert tarball exists in build/
      3. Extract and verify chowser binary exists
    Expected Result: Package created
    Evidence: .sisyphus/evidence/task-42-linux-pkg.txt
  ```

  **Commit**: NO (groups with Wave 5)

- [ ] 43. Add platform-specific icons and metadata

  **What to do**:
  - Create Windows icon (.ico format)
  - Create Linux icons (multiple sizes: 16, 32, 48, 128, 256, 512)
  - Add application metadata for each platform
  - Update electrobun.config.ts to reference icons
  - Verify icons appear correctly in each OS

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 36-42, 44-45)
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `icon.iconset/` — Existing macOS icons
  - Windows .ico format requirements
  - Linux icon size requirements

  **Acceptance Criteria**:
  - [ ] Windows .ico file created
  - [ ] Linux icon sizes created
  - [ ] Icons configured in build
  - [ ] Icons appear in OS correctly

  **QA Scenarios**:
  ```
  Scenario: Windows icon appears in taskbar
    Tool: Bash (Windows)
    Steps:
      1. Run Chowser on Windows
      2. Screenshot taskbar icon
    Expected Result: Correct icon shown
    Evidence: .sisyphus/evidence/task-43-windows-icon.png
  ```

  **Commit**: NO (groups with Wave 5)

- [ ] 44. Create README with installation instructions

  **What to do**:
  - Update chowser-electrobun/README.md
  - Installation instructions for Windows
  - Installation instructions for Linux
  - First-run setup guide
  - Troubleshooting section
  - Platform-specific notes

  **Recommended Agent Profile**:
  - **Category**: `writing`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 36-43, 45)
  - **Blocks**: None
  - **Blocked By**: Tasks 41, 42

  **References**:
  - Existing README.md
  - Installation patterns from similar apps

  **Acceptance Criteria**:
  - [ ] Windows installation documented
  - [ ] Linux installation documented
  - [ ] Screenshots included
  - [ ] Troubleshooting covers common issues

  **QA Scenarios**:
  ```
  Scenario: README has all sections
    Tool: Bash
    Steps:
      1. Read README.md
      2. Grep for "Windows"
      3. Grep for "Linux"
      4. Grep for "Troubleshooting"
    Expected Result: All sections present
    Evidence: .sisyphus/evidence/task-44-readme.txt
  ```

  **Commit**: NO (groups with Wave 5)

- [ ] 45. Manual QA on Windows 10/11

  **What to do**:
  - Install package on Windows 10 and Windows 11
  - Test all picker features (keyboard shortcuts, layouts)
  - Test settings (all tabs)
  - Test onboarding wizard
  - Test browser launching with profiles
  - Test MCP server
  - Test default browser registration
  - Test launch at login
  - Document any issues found

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: [`playwright`]

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (final parallel task)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 26-35, 41

  **References**:
  - macOS Chowser feature list for comparison
  - All task QA scenarios for verification

  **Acceptance Criteria**:
  - [ ] Picker works with all keyboard shortcuts
  - [ ] Settings save and persist
  - [ ] Onboarding completes successfully
  - [ ] Browser profiles launch correctly
  - [ ] MCP server responds to requests
  - [ ] Launch at login works
  - [ ] No critical bugs found

  **QA Scenarios**:
  ```
  Scenario: Full Windows QA checklist
    Tool: Manual + Playwright
    Steps:
      1. Install on Windows 10
      2. Complete onboarding
      3. Test each keyboard shortcut (1-9, P, H, R)
      4. Test each settings tab
      5. Test browser launching with profile
      6. Test MCP server curl request
      7. Screenshot each major screen
    Expected Result: All features work
    Evidence: .sisyphus/evidence/task-45-windows-qa/

  Scenario: Full Windows 11 QA
    Tool: Manual + Playwright  
    Steps: (same as Windows 10)
    Expected Result: All features work
    Evidence: .sisyphus/evidence/task-45-win11-qa/
  ```

  **Commit**: YES (end of Wave 5)
  - Message: `feat(release): add packaging and polish for Windows/Linux release`
  - Files: `electrobun.config.ts`, `README.md`, `icons/`

---

## Final Verification Wave

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `bun test`. Review all changed files for: `as any`/`@ts-ignore`, empty catches, console.log in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names (data/result/item/temp).
  Output: `Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Cross-Platform QA** — `unspecified-high` (+ `playwright` skill)
  Build Windows and Linux packages. Run picker, settings, onboarding on each platform. Execute every QA scenario from every task. Test keyboard shortcuts, rule creation, browser launching with profiles. Save screenshots to `.sisyphus/evidence/final-qa/`.
  Output: `Windows [N/N pass] | Linux [N/N pass] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance. Flag source-app routing if present (should be disabled).
  Output: `Tasks [N/N compliant] | VERDICT`

---

## Commit Strategy

Commits should be made at logical checkpoints:

1. After Wave 1 completion: `feat(electrobun): add Svelte setup and cross-platform launcher`
2. After Wave 2 completion: `feat(ui): add core Svelte components for picker and settings`
3. After Wave 3 completion: `feat(ui): implement complete picker and settings functionality`
4. After Wave 4 completion: `feat(onboarding): add multi-step wizard and platform integrations`
5. After Wave 5 completion: `feat(release): add packaging and polish for Windows/Linux release`

---

## Success Criteria

### Verification Commands
```bash
# Build for Windows
npm run build:windows  # Expected: produces .exe package

# Build for Linux
npm run build:linux  # Expected: produces tarball

# Run tests
bun test  # Expected: all tests pass

# Type check
bun run typecheck  # Expected: no errors
```

### Final Checklist
- [ ] All "Must Have" features present and functional
- [ ] All "Must NOT Have" constraints verified (no source-app routing on Win/Linux)
- [ ] All unit tests pass
- [ ] Manual QA completed on Windows 10/11 and Ubuntu
- [ ] UI matches iOS/macOS Chowser visual quality
- [ ] Picker keyboard shortcuts work (1-9, arrows, P, H, R)
- [ ] Browser profiles work (Chrome, Firefox)
- [ ] Import/export works
- [ ] MCP server works
- [ ] Onboarding wizard completes successfully
