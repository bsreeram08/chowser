<!-- Last verified: 2026-07-12 -->

# Architectural Decisions

Decisions that would surprise a new contributor. Each entry explains the "why" that the code alone doesn't capture.

---

## 1. NSPanel instead of NSWindow for the picker

**Context**: The picker must appear instantly over whatever the user is looking at, including full-screen apps.

**Options considered**:
- `NSWindow` — standard window; causes a Space switch when a full-screen app is active
- `NSPanel` with `.nonactivatingPanel` — appears over full-screen apps without a Space switch

**Decision**: Custom `ChowserPanel` subclass of `NSPanel` with style mask `.nonactivatingPanel | .fullSizeContentView | .borderless`, level `.mainMenu + 1`, and collection behavior `.canJoinAllSpaces | .fullScreenAuxiliary`.

**Trade-offs**:
- Gained: Picker appears instantly over full-screen apps, no Space animation
- Sacrificed: Panel doesn't participate in normal window ordering; requires manual focus handling

**References**: `AppDelegate.swift` lines 24-27 (ChowserPanel class), lines 261-274 (panel creation)

---

## 2. Process + /usr/bin/open instead of NSWorkspace.openApplication

**Context**: Chromium-based browsers need `--profile-directory` to open in a specific profile.

**Options considered**:
- `NSWorkspace.shared.openApplication(at:configuration:)` — drops custom arguments when Chromium hands off to an existing process
- `Process` + `/usr/bin/open -n -a <app>` with `--args` — passes arguments reliably to a new instance

**Decision**: Use `Process` + `/usr/bin/open -n -a` for all profile-aware launches. The `-n` flag forces a new instance, preventing the existing process from swallowing the `--profile-directory` argument.

**Trade-offs**:
- Gained: Reliable profile selection for Chromium and Firefox
- Sacrificed: Slightly slower launch (subprocess overhead); must handle `Process` error paths

**References**: `BrowserManager.swift` `launchInfo()` method (line 718+), `open()` method

---

## 3. NSWindowController + NSHostingController instead of SwiftUI Settings scene

**Context**: SwiftUI's `Settings` scene auto-presents when the app is activated via NSApp.activate, which conflicts with the picker workflow (activating the app to show the picker would also show settings).

**Options considered**:
- SwiftUI `Settings { SettingsView() }` scene — auto-presents on activation
- Manual `NSWindowController` wrapping `NSHostingController<SettingsView>` — full control over when the window appears

**Decision**: Manual `NSWindowController` in `AppDelegate`. The `@main` struct's `Settings` scene contains an `EmptyView()` placeholder.

**Trade-offs**:
- Gained: Settings window only appears when explicitly requested; no conflict with picker activation
- Sacrificed: More AppKit boilerplate; can't use SwiftUI Settings DSL

**References**: `AppDelegate.swift` line 224 (window creation), `ChowserApp.swift` (EmptyView placeholder)

---

## 4. Deferred, cancellable application reopen

**Context**: App Mode users expect clicking the Dock icon to reopen Settings. macOS can call `applicationShouldHandleReopen` immediately before delivering a URL-open event, so opening Settings synchronously from that callback races normal link handling.

**Options considered**:
- Open Settings immediately from `applicationShouldHandleReopen`
- Leave the callback unimplemented and require explicit menu commands
- Schedule a short deferred reopen that URL-open handling cancels

**Decision**: `applicationShouldHandleReopen` schedules a cancellable deferred Settings reveal. `application(_:open:)` cancels the pending work item before processing any URL. This handles AppKit's event ordering directly instead of relying on an `isHandlingURL` flag that is set too late.

**Trade-offs**:
- Gained: Native Dock-reopen behavior in App Mode without presenting Settings during link handling
- Sacrificed: Settings presentation waits briefly while Chowser determines whether a URL event follows

**References**: `AppDelegate.applicationShouldHandleReopen`, `AppDelegate.application(_:open:)`, `docs/adr/0004-atomic-app-mode-transitions.md`

---

## 5. Observable singleton with debounced UserDefaults writes

**Context**: BrowserManager is the single source of truth for all browser/rule state. Drag-to-reorder in settings can trigger dozens of mutations per second.

**Options considered**:
- Write to UserDefaults on every mutation — high I/O during drag operations
- Debounced writes with 0.3s delay — batches rapid mutations

**Decision**: `DispatchWorkItem`-based debounce at 0.3 seconds. Each mutation cancels the pending save and schedules a new one. `flushPendingSaves()` is called before operations that need consistent state (import/export).

**Trade-offs**:
- Gained: Smooth drag-to-reorder without I/O stutter
- Sacrificed: If the app crashes within 0.3s of a change, that change is lost; must remember to flush before reads

**References**: `BrowserManager.swift` lines 170-190 (`scheduleSaveBrowsers`, `scheduleSaveRules`, `flushPendingSaves`)

---

## 6. Local @State editing with commit-on-blur

**Context**: `BrowserConfigRow` and `RuleRowView` are in SwiftUI Lists. If every keystroke immediately mutated the BrowserManager, the entire list would re-render on each character.

**Options considered**:
- Direct binding to BrowserManager properties — causes list re-render per keystroke
- Local `@State` with deferred commit — smooth typing, commits on focus loss

**Decision**: Each row keeps local `@State` copies of editable fields (`editingName`, `editingHost`, etc.). Changes are committed to BrowserManager only when focus leaves the field (via `.onChange(of: focusedField)`) or on Return key.

**Trade-offs**:
- Gained: Typing is instant; list doesn't re-render during edits
- Sacrificed: Must sync external changes back to local state (handled by `.onChange(of: rule/browser)` that only updates unfocused fields)

**References**: `BrowserConfigRow.swift` (commitField, onChange of focusedField), `RuleRowView.swift` (same pattern)

---

## 7. Equatable conformance on row views (excluding closures)

**Context**: SwiftUI's `.equatable()` modifier prevents unnecessary view re-renders, but closures are not `Equatable`.

**Options considered**:
- No Equatable — SwiftUI re-renders all rows on any list change
- Equatable with closure exclusion — compares data properties only

**Decision**: Both `BrowserConfigRow` and `RuleRowView` conform to `Equatable`, comparing only data properties (`browser`/`rule`, `canMoveUp`, `canMoveDown`, `hasSearchQuery`) and deliberately excluding all callback closures.

**Trade-offs**:
- Gained: Rows only re-render when their data actually changes
- Sacrificed: If callback closures capture stale state, the row won't re-render to pick up new closures (mitigated by callbacks always accessing current `BrowserManager.shared` state)

**References**: `BrowserConfigRow.swift` Equatable extension, `RuleRowView.swift` Equatable extension

---

## 8. Apple Event handler registered in applicationWillFinishLaunching

**Context**: macOS delivers the first URL-open event very early in the app lifecycle. If the handler is registered in `applicationDidFinishLaunching`, the event arrives before the handler is installed and is lost.

**Options considered**:
- Register in `applicationDidFinishLaunching` — misses early events
- Register in `applicationWillFinishLaunching` — catches everything

**Decision**: Register `handleGetURLEvent` in `applicationWillFinishLaunching`, before Cocoa installs its own default handler.

**Trade-offs**:
- Gained: Never misses the first URL event on launch
- Sacrificed: Handler code must be defensive about uninitialized state (BrowserManager may not be fully loaded yet)

**References**: `AppDelegate.swift` `applicationWillFinishLaunching` method

---

## 9. Arc browser — single browser without profile support

**Context**: Arc uses Chromium's `Local State` file and has profile directories, but its architecture handles profiles internally in a way that `--profile-directory` does not reliably work.

**Options considered**:
- Detect and expose Arc profiles like other Chromium browsers
- Treat Arc as a single browser entry without profile support

**Decision**: Arc's bundle IDs (`company.thebrowser.Browser`, `company.thebrowser.dia`) are in the Chromium family for launch argument purposes, but profile detection works — however, in practice Arc profiles are managed internally and the flag may not select the correct space. The profile detection still runs and users can choose profiles, but results may vary.

**Trade-offs**:
- Gained: Simpler UX for Arc users; no broken profile selection
- Sacrificed: Power users who want Arc profile routing must use custom launch arguments

**References**: `BrowserProfileDetector.swift` Chromium path mapping (includes Arc/Dia paths), `BrowserManager.swift` browser family detection

---

## 10. Onboarding activation policy toggle (.accessory ↔ .regular)

**Context**: Chowser runs as `LSUIElement` (`.accessory` activation policy — no Dock icon). But onboarding needs to present a prominent window that the user can interact with normally.

**Options considered**:
- Show onboarding as another NSPanel — non-standard UX, focus issues
- Temporarily switch to `.regular` activation policy for onboarding — proper window with Dock icon

**Decision**: `OnboardingManager.showOnboardingWindow` sets `NSApp.setActivationPolicy(.regular)`, which makes the app appear in the Dock and allows normal window focus. On close, it switches back to `.accessory`.

**Trade-offs**:
- Gained: Onboarding feels like a normal app window; proper keyboard focus and window management
- Sacrificed: Brief Dock icon appearance during onboarding; must ensure the switch-back happens even if the user force-closes

**References**: `UI/Onboarding/OnboardingManager.swift` lines 29 (set .regular), 70 (set .accessory)

---

## 11. Separate application targets for direct and App Store distribution

**Context**: Direct downloads need profile-aware unsandboxed launching and Sparkle updates. Mac App Store policy requires sandboxing and forbids non-store update mechanisms. Conditional Swift alone cannot prove that Sparkle is absent from the submitted binary.

**Options considered**:
- One target with configuration-only flags — less project setup, but package linkage and updater metadata can leak into the App Store artifact
- Two repositories or source trees — strongest isolation, but guarantees code drift
- Two application targets sharing one synchronized source group — explicit binary boundary without source duplication

**Decision**: Keep `Chowser` as the unsandboxed direct target with `DIRECT_DISTRIBUTION` and Sparkle. Build `ChowserAppStore` through the `Chowser-AppStore` scheme with `APP_STORE`, sandbox entitlements, and no Sparkle dependency. Verify both finished artifacts in CI.

**Trade-offs**:
- Gained: App Store compliance is inspectable; direct-only dependencies and metadata cannot be embedded accidentally
- Sacrificed: Xcode target settings and the small distribution-specific Info.plist surface must remain synchronized

**References**: `Chowser.xcodeproj/project.pbxproj`, `Chowser/AppUpdateController.swift`, `scripts/verify-distribution-artifact.sh`, `DISTRIBUTION.md`
