# Native TestFlight Reactivation Learnings

## 2026-06-11 Task: plan-initialization
- Electrobun is explicitly excluded for this cycle.
- Release target is TestFlight-only with manual Xcode Organizer upload.
- Browser profile/private-mode support in sandbox/TestFlight is release-blocking.
- MCP remains opt-in and visible, but every endpoint must be token-protected when enabled.
- Liquid Glass support is selective and native-only: custom floating/card/chip surfaces with macOS 26 gates and fallbacks.

## 2026-06-11 Task: T1 baseline release inventory
- Public App Store ID `6760034779` resolves to the Chowser Mac listing; `6741527291` returns 404.
- TestFlight reactivation path is manual Xcode Organizer upload; no current `.github/workflows/` file uploads from `pre-release` to App Store Connect.
- Release inventory recorded in `.sisyphus/notepads/native-testflight-reactivation/release-inventory.md`.
- App Store Release config uses bundle ID `in.sreerams.Chowser`, team `TH2VPAUX6Y`, `MARKETING_VERSION` `3.1.5`, build `202603130606`, `ChowserAppStore.entitlements`, sandbox enabled, and `APP_STORE`.

## 2026-06-11 Task: T2 exploration synthesis
- Current profile discovery has backend read support but no user-facing grant flow: `SandboxBookmarkManager` resolves existing bookmark data but never creates it.
- `BrowserProfileDetector` calls `SandboxBookmarkManager.shared.startAccessing()` and then falls back to direct `~/Library/Application Support`; in `APP_STORE` this fallback can mask missing bookmark access.
- Recommended architecture: explicit profile access manager/bookmark flow, user grants `~/Library/Application Support` or browser profile root via `NSOpenPanel`, app stores a read-only app-scoped security-scoped bookmark, and profile detection uses the bookmark in sandbox builds.
- UI touchpoints: Settings Browsers banner, Add Browser installed-apps banner, and onboarding Browsers step copy/CTA.
- Accessibility identifiers recommended: `settings.profileAccess.banner`, `settings.profileAccess.grantButton`, `settings.profileAccess.resetButton`, `settings.addSheet.profileAccess.grantButton`, `onboarding.profileAccess.grantButton`.

## 2026-06-11 Task: T2 sandbox profile-access implementation
- `SandboxBookmarkManager` now owns the explicit Application Support grant path and still persists under `securityScopedBookmark_AppSupport`.
- App Store profile discovery now requires the bookmark-backed Application Support URL; non-App-Store builds keep the direct Application Support fallback for local development.
- `BrowserProfileDetector.detectProfiles(for:appSupportURL:)` gives tests deterministic temp fixtures instead of relying on installed local browser profiles.
- Settings/Add Browser/onboarding expose profile-access grant CTAs with the required accessibility identifiers and clear profile detector cache after grant/reset.

## 2026-06-11 Task: T2 Atlas verification fixes
- `SandboxBookmarkManager.realUserHomeDirectory()` uses Darwin `getpwuid(getuid())` so the profile-access picker defaults under the login user home instead of a sandbox container home.
- `grantStatus` now validates bookmark resolution by attempting the same security-scoped access path used by profile detection; denied access reports `.invalid` so Settings/Add Browser/onboarding keep showing recovery UI.
- Tests now cover malformed bookmark data, mocked denied security-scope access, and the login-home Application Support default helper.

## 2026-06-11 Task: T3 launch research synthesis
- Current `BrowserManager.launchInfo(...)` returns browser application arguments, while `open(...)` passes URL separately through LaunchServices or `/usr/bin/open`; existing `BrowserLaunchTests` are stale because they expect the URL inside launch arguments.
- Apple documentation says `NSWorkspace.OpenConfiguration.arguments` is ignored when the calling process is sandboxed, so App Store/TestFlight builds cannot reliably deliver browser profile/private flags through that property.
- Direct-download builds can keep `/usr/bin/open -n -a ... --args ...` for profile/private flags; App Store builds should treat app-bundle browser selection as reliable and profile/private flags as unsupported/unreliable unless verified by public browser APIs.
- Recommended T3 implementation seam: pure launch planning/intent structs that describe URL delivery, app arguments, direct vs App Store launch mode, and new-instance behavior without launching external browsers.
- Tests should cover Chromium and Firefox profile/private combinations, single-instance browser lowering for Arc/Dia/Zen, stale URL-in-args expectations, and custom argument parsing with profile names containing spaces.

## 2026-06-11 Task: T3 sandboxed launch validation implementation
- `BrowserManager` now exposes a pure `BrowserLaunchPlan` seam with requested vs delivered application arguments, launch mode (`directDownload` vs `appStoreSandbox`), document URLs, new-instance behavior, and `/usr/bin/open` lowering.
- Direct-download launches still deliver profile/private flags via `/usr/bin/open`; the generated arguments place the URL once before `--args` and browser app arguments after `--args`.
- App Store/TestFlight launch plans preserve reliable app-bundle selection and URL delivery via `NSWorkspace`, but intentionally deliver no application arguments because sandboxed `OpenConfiguration.arguments` is ignored.
- Custom argument tokenization now happens before `{profile}` replacement, so templates like `--profile-directory={profile}` keep profile names containing spaces as one argument.
- `BrowserLaunchTests` now cover Chromium/Firefox profile and private combinations, Safari/other no-arg behavior, direct vs App Store lowering, URL de-duplication, and single-instance Arc/Dia/Zen handling.

## 2026-06-11 Task: T3 post-review fixes
- Post-implementation review caught missing Dia launch-plan coverage; `BrowserLaunchTests` now includes `company.thebrowser.dia` in Chromium argument and single-instance `-n` suppression coverage.
- App Store builds now centralize launch-argument capability in `BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild`; persisted/imported/new browser and rule configs normalize away profile/custom/private launch settings when `APP_STORE` is active.
- Settings, Add Browser, onboarding, and rule creation now use minimal App Store-specific copy/disabled controls so users are not promised profile/private/custom launch arguments that sandboxed `NSWorkspace` cannot deliver.

## 2026-06-11 Task: T4 MCP API hardening
- `MCPServer` now requires `Authorization: Bearer <token>` before routing every HTTP request, including `GET /status`, `GET /browsers`, `GET /rules`, unknown paths, and all write/delete endpoints.
- The listener remains `NWParameters.tcp` with `acceptLocalOnly = true`; enablement remains manual via Settings/onboarding/menu bar, and the token is visible in UI instead of being printed to stdout.
- `MCPServerTests` use live localhost requests on port 24246 and cover missing, malformed, wrong, and valid auth paths plus stopped-server connection refusal.

## 2026-06-11 Task: T5 onboarding state unification
- `hasCompletedOnboarding` is now the single canonical onboarding persistence key used by launch gating, onboarding completion/reset, and `BrowserManager` fresh setup.
- `AppEnvironment.makeDefaultStore()` centralizes suite selection so app code and tests respect `CHOWSER_DEFAULTS_SUITE` / `-UITesting` defaults isolation instead of reaching directly for `UserDefaults.standard`.
- `OnboardingManager` clears the canonical onboarding key during `-UITesting_ClearData` / `-ResetToFreshSetup` initialization because `AppDelegate` consults it before `BrowserManager.shared` is guaranteed to exist.
- `OnboardingStateTests` cover first-launch false, completed true across manager instances, reset false, `BrowserManager.resetToFreshSetup()` clearing launch-gate state, and UI-test suite isolation.
- T5 verification fix: `BrowserManager.hasCompletedOnboarding` must remain a computed bridge to `OnboardingManager`/shared defaults, not a stored property, so an already-created manager immediately observes later onboarding state changes made through `OnboardingManager`.

## 2026-06-11 Task: T3 final App Store guardrail pass
- Existing browser editing now disables custom launch arguments and avoids saving them when `APP_STORE` is active; direct-download builds keep editable custom arguments.
- Existing rule editing now disables private/incognito routing with explanatory copy in App Store builds, matching the Add Rule and quick-rule creation paths.
- Picker private-mode UI and shortcuts now respect the same launch-argument capability gate: App Store builds hide the `P` hint, ignore `P`/Option private requests, and only open regular browser launches.
- The menu-bar clipboard submenu no longer advertises private opening in App Store builds, and MCP browser/rule writes report `launchArgumentsSupported` while using manager normalization instead of direct custom-argument mutation.
- Verification passed: `BrowserLaunchTests` executed 12 tests successfully, and Release build succeeded with isolated DerivedData after the shared DerivedData build database was locked.

## 2026-06-11 Task: T6 URL/source-app routing seams
- `AppDelegate` now exposes pure seams for Apple Event URL-string validation, sender PID/bundle/frontmost source-app resolution, and incoming route resolution with source-app cleanup.
- Source-app routing had an async lifecycle bug: `application(_:open:)` cleared `BrowserManager.currentSourceAppBundleId` immediately after scheduling the routing `Task`; cleanup now happens inside the route-resolution seam after `resolvedRoute(for:)` has used the source context.
- Invalid Apple Event payloads without a URL scheme are rejected before calling `application(_:open:)`, preventing relative/garbage payloads from reaching picker/browser routing.
- `BrowserManagerTests` cover source-app-specific matching, mismatch picker fallback, temporary focus precedence over source-specific rules, forced picker/Shift bypass behavior, source resolution fallback order, and source-context clearing.
- Verification passed: `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/BrowserManagerTests` (59 tests) and `xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build`.

## 2026-06-11 Task: T7 centralized rule validation
- `BrowserManager` now owns one `RoutingRuleValidationError` + validation/normalization path for rule adds, whole-rule edits, field-specific edit helpers, duplication, and imports; `BrowserRoutingRule` Codable/storage shape remains unchanged.
- Rule validation now normalizes host patterns, path prefixes, source app bundle IDs, profile/private-mode launch capability, and default rule names before storage; invalid edits leave the existing stored rule untouched.
- Rule imports decode the existing schema but only merge rules that pass manager validation, so bad imported host/regex/path/browser/source-app data is skipped instead of corrupting stored rules.
- MCP `POST /rules` now uses the same manager validation for create/update and returns client errors for invalid rule IDs, missing browsers, malformed host/regex/path/source data, or unknown update IDs instead of silently accepting or creating unintended rules.
- `BrowserManagerTests` and `MCPServerTests` cover invalid host patterns, invalid regex, path normalization/malformed paths, source-app validation and matching, browser existence, import validation, and MCP validation behavior.
- Verification passed: `BrowserManagerTests` (62 tests), `MCPServerTests` (40 tests), and `xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build`.

## 2026-06-11 Task: T8 clipboard private-mode routing
- Clipboard private opening now uses a manager-scoped `currentURLPrivateModeRequested` flag instead of relying on users to toggle private mode inside the picker.
- Direct-download builds honor the forced private request for matching routing rules and picker fallback; normal clipboard opening clears the flag, and picker dismissal clears it again to prevent leakage into later URLs.
- App Store/TestFlight builds remain honest: the private clipboard menu item stays hidden by the existing capability gate, and incoming private-mode requests/rule private mode resolve to false when launch arguments are unsupported.
- `BrowserManagerTests` now cover private clipboard arming, normal clipboard clearing, and forced private overriding a non-private routing rule; verification passed with 65 BrowserManager tests and Release build.
- T8 review caught that a global Boolean could leak across async URL opens and that picker reuse made `onAppear` insufficient; the implementation now stores a URL-scoped pending private request, consumes it before `unshortenURL`, carries the local result into routing/picker fallback, and resyncs picker private state on current URL/request changes.
- Final T8 verification passed with 67 BrowserManager tests and `xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build`.

## 2026-06-11 Task: T9 Liquid Glass modifier infrastructure
- `PickerViewModifiers.swift` now centralizes named reusable surfaces: `pickerPanelSurface()`, `pickerInteractiveMiniButton()`, `pickerBadgeChip()`, and `pickerInlineCard()`.
- Each modifier preserves the three-tier path: reduced-transparency solid `NSColor` background first, macOS 26 `glassEffect` behind `#available(macOS 26.0, *)`, then macOS 14-safe material or low-opacity fallback.
- Backward-compatible typealiases keep the previous modifier type names available while T10/T11 migrate picker and optional card call sites.
- No `GlassEffectContainer` was introduced in T9 because this task only defines individual surface infrastructure; grouped containers should be added only where T10/T11 actually group custom glass elements.

## 2026-06-11 Task: T10 picker Liquid Glass adoption
- `ContentView` now routes the picker panel through `pickerPanelSurface()` and removes the competing `NSVisualEffectView(.menu)` wrapper/background path.
- Picker URL action buttons use `pickerInteractiveMiniButton()`, shortcut/keycap badges use `pickerBadgeChip()`, and the rule suggestion banner uses `pickerInlineCard()` so fallback/reduced-transparency behavior stays centralized in T9.
- Browser icon-layout selected/hover hit areas use the shared inline-card surface only when highlighted; browser icons, labels, dividers, standard controls, and dense list-row backgrounds intentionally remain unglassed.
- `ConfigureRuleView` now uses `pickerInlineCard()` for the in-picker rule details card and `pickerBadgeChip()` for the host chip while preserving the TextField, menu Picker, checkbox, and Save/Cancel controls as standard UI.

## 2026-06-11 Task: T11 optional non-picker Liquid Glass polish
- Added `customCardSurface()` and `customChipSurface()` beside the T9 picker modifiers so non-picker custom surfaces share the same reduced-transparency solid path, macOS 26 `glassEffect` gate, and macOS 14-safe fallback without reusing picker-named APIs semantically.
- Applied custom-card polish only to safe standalone surfaces: browser grid cards, rule detail section content cards, and the onboarding AI setup prompt card.
- Applied custom-chip polish only to safe custom chips/demo surfaces: filter chip outer shells and onboarding browser demo shortcut chips; selected filter chips remain solid accent for contrast.
- Left Settings `NavigationSplitView`, sidebars, lists, forms, modal sheets, dense rows, AppKit/file panels, browser icons, dividers, primary onboarding CTAs, and ordinary status/count badges unchanged to avoid over-glassing dense or standard UI.
- Post-review fix: URL unshortening progress/error status indicators stay plain low-opacity badges instead of `pickerBadgeChip()` because T10 approved URL action buttons and shortcut/keycap badges, not transient status indicators.
## 2026-06-11 Task: T11 verification
- T11 non-picker Liquid Glass polish touched only `PickerViewModifiers.swift`, `BrowserCardView.swift`, `FilterChip.swift`, `RuleUIComponents.swift`, and onboarding prompt/demo surfaces in `UI/Onboarding/OnboardingSteps.swift`.
- Code review found selective adoption only on custom card/chip surfaces: browser grid cards, filter chips, rule detail content cards, onboarding browser demo chips, and AI setup prompt card.
- Settings `NavigationSplitView`, sidebars, lists, forms, modal sheets, AppKit menus, file panels, standard buttons, browser icons, text labels, and dense rows were not converted to glass.
- Per-file SourceKit still reports known project-context false positives for app symbols/modifiers in dependent Swift files, but `PickerViewModifiers.swift` itself has no diagnostics and the full Release xcodebuild succeeded.
- T11 Release build passed with isolated DerivedData: `xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build -derivedDataPath /var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT11ReleaseDerivedData`.

## 2026-06-11 Task: T12 release metadata
- T12 uses deterministic build number `202606110001`, greater than inventory build `202603130606`; App Store Connect was not queried locally because this task forbids App Store Connect automation/API-key flows.
- `MARKETING_VERSION` remains `3.1.5`; no local project evidence required a new external version.
- TestFlight notes and manual Organizer checklist live in `release/TESTFLIGHT_NOTES.md` and keep T13 backlog items explicitly out of scope.


## 2026-06-11 Task: T12 release metadata artifact correction
- `release/` is ignored as generated release output, so the durable TestFlight notes/checklist artifact was moved to tracked root `TESTFLIGHT_NOTES.md`.
- Removed the ignored `release/TESTFLIGHT_NOTES.md` duplicate to avoid conflicting human-facing copies.
- Build metadata remains unchanged: `CURRENT_PROJECT_VERSION` `202606110001`, `MARKETING_VERSION` `3.1.5`.

## 2026-06-11 Task: T13 market-gap backlog documentation
- Created root `MARKET_GAP_BACKLOG.md` as the tracked backlog artifact because no existing `*BACKLOG*.md`, `TODO*.md`, or roadmap Markdown file existed.
- The backlog separates post-TestFlight product discovery from current 3.1.5 TestFlight release blockers and links readers back to `TESTFLIGHT_NOTES.md` for current-release notes.
- Required gaps are labeled Post-TestFlight and out of scope for 3.1.5: browser extensions, rule tester/history, tracking stripping, URL rewrites/native app targets, short URL expansion, Focus/Shortcuts, and mail/file handlers.

## 2026-06-11 Task: T13 backlog wording correction
- Atlas verification found pre-existing native references for `RuleTesterView` in `SettingsView+Rules.swift` and menu-bar Focus Mode in `AppDelegate.swift`; these were not introduced by T13.
- `MARKET_GAP_BACKLOG.md` now distinguishes existing basic rule tester/simulation and Focus Mode from post-TestFlight discovery for routing history, richer tester workflows, Apple Shortcuts automation, and deeper Focus integration.

## 2026-06-12 Task: T14 release verification
- Primary Release build passed with isolated DerivedData at `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14BuildDerivedData`.
- Unit tests passed with isolated DerivedData at `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UnitDerivedData`; Swift Testing reported 145 tests across 6 suites passed.
- App Store/TestFlight archive passed with isolated DerivedData at `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14ArchiveDerivedData` and created `release/Chowser.xcarchive`.
- Archive metadata matches release expectations: bundle ID `in.sreerams.Chowser`, version `3.1.5`, build `202606110001`, app path `Applications/Chowser.app`.

## 2026-06-12 Task: T14 UI/E2E waiver documentation
- User explicitly said “do not do e2e anymore”. Treat UI/E2E tests as waived/skipped by user instruction for this release continuation, not green.
- T14 automated release gates now rely on Release build, unit tests, App Store/TestFlight archive, and archive metadata.
- Preserve the historical UI-test failure evidence: direct scheme attempt failed missing host app; two-step host flow executed 11 UI tests and all 11 failed on UI assertions.

## 2026-06-12 Task: F2 native-review Add Browser profile-collapse fix
- Root cause confirmed in code: `BrowserManager.getInstalledBrowsers()` emits profile-specific entries when profiles exist, while `AddBrowserSheet.filteredBrowsers` previously filtered all `profile != nil` entries out when launch arguments are unsupported.
- `AddBrowserSheet.browserCandidates(...)` now keeps direct-download behavior unchanged, but App Store/TestFlight-style candidate generation collapses detected profile variants into one plain `profile == nil` browser app row per bundle ID.
- Unsupported-launch-args candidate generation skips already-configured base browser identities and strips profile suffixes like `Google Chrome - Work` for the plain Add Browser row label.
- Added unit coverage in `BrowserConfigTests` for both App Store/TestFlight collapse behavior and direct-download profile-variant preservation; no UI/E2E tests were run.
- Verification passed: targeted `BrowserConfigTests` ran 8 tests successfully with isolated DerivedData, and Release build passed with isolated DerivedData in `APP_STORE` mode.

## 2026-06-12 Task: F1 release-readiness doc consistency
- F1 doc blocker was a release-doc inconsistency only: `TESTFLIGHT_NOTES.md` still presented UI/E2E as a pre-upload command, while `DISTRIBUTION.md` used the stale `build/Chowser.xcarchive` path.
- Fixed docs to state UI/E2E is waived/skipped by the user instruction “do not do e2e anymore”, not passing, and to use `release/Chowser.xcarchive` for this TestFlight archive flow.

## 2026-06-12 Task: post-F2 release evidence update
- After the F2 Add Browser profile-collapse fix, Atlas reran targeted `BrowserConfigTests`, a Release build, and a fresh App Store/TestFlight archive successfully.
- Fresh archive evidence uses DerivedData `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserAtlasPostF2ArchiveDerivedData`, captured output `/Users/sreeram/.local/share/opencode/tool-output/tool_eba4850020019n4vWF8Inf16QP`, and archive path `release/Chowser.xcarchive`.
- Post-F2 archive metadata remained valid: `Applications/Chowser.app`, `in.sreerams.Chowser`, version `3.1.5`, build `202606110001`.
