# Native TestFlight Reactivation Plan

## TL;DR

> Reactivate Chowser TestFlight with a native macOS-only release that proves sandboxed browser/profile/private-mode routing works, hardens the opt-in MCP API, fixes release-critical implementation gaps, adds full selective Liquid Glass support with fallbacks, and prepares a manual Xcode Organizer upload.

> **Deliverables**: sandbox-safe profile support, hardened MCP API, unified onboarding state, tested URL/source-app routing, validated rule editing/private clipboard behavior, selective Liquid Glass UI, bumped build/version metadata, release notes, manual archive/upload checklist, and market-gap backlog.

> **Estimated Effort**: Large | **Parallel Execution**: Limited | **Critical Path**: sandbox profile/private validation → release blockers → Liquid Glass → QA/archive → manual upload prep

---

## Context

### Original Request

The app was removed from TestFlight due to no updates. The next release should be native macOS only; Electrobun, Windows, and Linux are out of scope because they cannot be tested right now. Before uploading, review implementation issues and market gaps. Full Liquid Glass support is now in scope.

### Confirmed Decisions

- Native Swift/macOS app only.
- TestFlight-only release, not a public App Store relaunch candidate.
- Manual Xcode Organizer upload; no CI/TestFlight upload automation in this cycle.
- MCP/local API remains opt-in and visible in Settings/onboarding, but must be hardened.
- Browser profile support must fully work in sandbox/TestFlight; unreliable profile/private behavior is release-blocking.
- Verification covers current macOS plus oldest supported App Store target available to the implementer.
- Test strategy is tests-after plus agent-executed QA.
- Liquid Glass support means selective Apple-guided adoption on custom floating/card/chip surfaces, not glassing every Settings/List/Form/AppKit surface.

### Research Findings

- App Store build settings exist in `Chowser.xcodeproj/project.pbxproj`: bundle ID `in.sreerams.Chowser`, team `TH2VPAUX6Y`, marketing version `3.1.5`, current build `202603130606`, App Store entitlements, sandbox enabled, and `APP_STORE` compilation condition.
- `MACOSX_DEPLOYMENT_TARGET` is `14.0` for the app target; screenshot targets show `26.2` and should not drive product compatibility claims.
- `DISTRIBUTION.md` claims TestFlight automation, but repo workflows only build/test and DMG-release; no TestFlight upload workflow or `ExportOptions.plist` exists.
- README and docs disagree on App Store app ID; verify the real App Store Connect ID before publishing release notes.
- Critical native risks: sandbox profile discovery lacks bookmark creation/grant flow; AppDelegate URL/source-app interception is under-tested; App Store launch path may diverge for profile/private mode; onboarding state is split; MCP GET endpoints are unauthenticated; rule editing bypasses validation; clipboard “Open in Private…” does not force private; tests miss release-critical cases.
- Market gaps are backlog only for this release: browser extensions, rule tester/history, tracking stripping, URL rewrite/native-app targets, short URL expansion, Focus/Shortcuts, mail/file handlers.
- Liquid Glass APIs are macOS 26+ public APIs: use `glassEffect`, `GlassEffectContainer`, glass button styles, `#available(macOS 26.0, *)`, reduced-transparency fallbacks, and avoid overuse.
- Chowser already has partial Liquid Glass in `Chowser/PickerViewModifiers.swift`, but `Chowser/ContentView.swift` still uses a separate `NSVisualEffectView(.menu)` panel background path.

---

## Work Objectives

### Core Objective

Ship a TestFlight-reactivation build that is safe, testable, native-only, and visually current on macOS 26 while preserving macOS 14+ fallback behavior.

### Must Have

- Sandboxed/App Store build can launch selected Chrome and Firefox profiles reliably, including private/incognito where supported.
- MCP is opt-in, localhost-only, visible when enabled, and token-protected on every endpoint.
- Onboarding and reset flows use one coherent persisted state model.
- URL interception, source-app routing, rule matching, rule editing, and private clipboard behavior have targeted tests or QA coverage.
- Liquid Glass adoption is centralized, availability-gated, accessible, and non-disruptive on older macOS.
- Manual archive/upload checklist is accurate and executable by a human in Xcode Organizer.

### Must NOT Have

- Do not touch `chowser-electrobun/`.
- Do not add Windows/Linux work.
- Do not add browser extensions, URL rewrite scripting, Focus/Shortcuts, mail/file handlers, or rule history/tester in this release.
- Do not add CI/TestFlight upload automation.
- Do not glass standard AppKit menus/panels, Settings sidebar/list/form surfaces, dense rows, or ordinary text/status badges.
- Do not silently degrade profile/private behavior in TestFlight.

---

## Verification Strategy

### Commands

Primary build:

```bash
xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build
```

Unit tests:

```bash
xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests
```

UI/E2E tests, waived for this release continuation by explicit user instruction:

```bash
xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS'
```

Do not run this command for the current release continuation. Historical attempts remain part of T14 evidence, but UI/E2E tests are not a required automated release gate after the user said “do not do e2e anymore”.

App Store/TestFlight archive:

```bash
xcodebuild archive -project Chowser.xcodeproj -scheme Chowser -configuration Release \
  ENABLE_APP_SANDBOX=YES CODE_SIGN_ENTITLEMENTS=Chowser/ChowserAppStore.entitlements \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APP_STORE' \
  -archivePath release/Chowser.xcarchive
```

### Manual QA Gates

- Fresh launch and onboarding complete.
- Set Chowser as default browser.
- Click URL from an external app; source app is captured when available.
- Unmatched URL shows picker.
- Matching host/path/source-app rule bypasses picker.
- Chrome default profile opens.
- Chrome non-default profile opens.
- Chrome private/incognito opens when requested.
- Firefox default profile opens.
- Firefox non-default profile opens.
- Settings opens, edits browsers/rules, persists after relaunch.
- MCP disabled by default; enabled MCP requires token for every endpoint.
- Liquid Glass renders on macOS 26+; reduced-transparency and macOS 14 fallback remain legible.

---

## TODOs

- [x] T1: Baseline release inventory and stale-state cleanup
  - Confirm current git state and remove accidental artifacts only if clearly unrelated, especially staged `Icon\r`.
  - Verify real App Store Connect app ID and reconcile README/docs URLs.
  - Update or annotate `DISTRIBUTION.md` so it no longer claims missing TestFlight automation.
  - Record current `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, bundle ID, team ID, deployment target, entitlements, and archive path in release notes.
  - Verification: git status is understood; documentation matches manual Organizer upload path; no Electrobun files touched.

- [x] T2: Sandbox profile-access spike and implementation
  - Inspect `BrowserProfileDetector.swift`, `SandboxBookmarkManager.swift`, App Store entitlements, and Settings/onboarding profile-access UI.
  - Add or repair a user-mediated security-scoped bookmark grant flow for browser profile directories if current temporary exceptions are insufficient.
  - Ensure Chrome-family and Firefox-family profile discovery works in sandbox/App Store builds without relying on undocumented silent access.
  - Document any entitlement retained and why.
  - Verification: sandbox/App Store build can discover profiles after explicit user grant; no crash when grant is missing or revoked.

- [x] T3: Sandboxed browser/profile/private launch validation and fixes
  - Inspect `BrowserManager.open(...)`, `launchBrowser(...)`, App Store `NSWorkspace.OpenConfiguration` path, and non-App-Store `/usr/bin/open` path.
  - Make App Store/TestFlight launch behavior reliable for browser, profile, and private/incognito targets.
  - Add tests around generated launch intent/arguments where direct browser launching is not unit-testable.
  - Verification: Chrome default/non-default/private and Firefox default/non-default launch scenarios pass manual QA from signed sandbox build.

- [x] T4: MCP API hardening while keeping opt-in visible UX
  - Require token authentication for all MCP endpoints, including `GET /status`, `GET /browsers`, and `GET /rules`.
  - Preserve localhost-only binding and opt-in/off-by-default behavior.
  - Update Settings/onboarding copy so users understand when the API is enabled and how the token is used.
  - Add tests for unauthorized and authorized MCP requests.
  - Verification: unauthenticated curl returns `401`; authorized request with valid token returns expected response; MCP disabled state refuses connections or reports disabled safely.

- [x] T5: Unify onboarding completion state and reset behavior
  - Reconcile `OnboardingManager.hasCompletedOnboarding` and `BrowserManager.onboardingCompleted` into one coherent persistence model.
  - Respect `AppEnvironment` test defaults isolation.
  - Ensure reset/fresh setup flows clear the same state used by launch gating.
  - Add tests for first launch, completed onboarding, reset, and UI-test isolation.
  - Verification: fresh install shows onboarding once; completed onboarding stays complete across relaunch; reset reopens onboarding.

- [x] T6: Add URL interception and source-app routing seams/tests
  - Add testable seams for Apple Event URL extraction, source PID/bundle resolution, and `currentSourceAppBundleId` propagation without relying on real system events.
  - Add tests for invalid URL handling, source-app-specific rule matching, rule bypass vs picker fallback, and temporary focus override precedence.
  - Keep AppDelegate lifecycle behavior unchanged unless tests expose a bug.
  - Verification: unit tests cover source-app routing and broad QA confirms external-app clicked URL still opens through Chowser.

- [x] T7: Centralize rule validation across add/edit/import/MCP paths
  - Inspect rule creation/editing in `BrowserManager`, `AddRuleSheet`, `ModernRuleDetailView`, import handling, and MCP rule endpoints.
  - Route edits through the same validation/normalization path as adds.
  - Preserve existing rule storage compatibility.
  - Add tests for invalid host patterns, invalid regex, path normalization, source-app matching, browser existence, and import/MCP validation behavior.
  - Verification: invalid edits/imports/MCP requests fail safely; valid existing rules still load and match.

- [x] T8: Fix clipboard private-mode behavior or label
  - Inspect `AppDelegate.openClipboardURLPrivate()` and picker private-mode state handling.
  - Prefer implementing a forced-private clipboard path; if impossible without risky picker plumbing, rename UI so it does not overpromise.
  - Add targeted tests or UI QA for clipboard private flow.
  - Verification: menu item either truly opens private mode or is accurately labeled.

- [x] T9: Full selective Liquid Glass support with centralized modifiers
  - Refactor `PickerViewModifiers.swift` into reusable named modifiers for panel surface, interactive mini button, badge/chip, and inline card.
  - Preserve reduced-transparency solid backgrounds before macOS availability checks.
  - Preserve macOS 14+ fallbacks using `.ultraThinMaterial` or current low-opacity fills.
  - Use `GlassEffectContainer` only for grouped custom glass effects where it improves performance/shape interaction.
  - Verification: code compiles with macOS 26 APIs gated; reduced-transparency fallback path remains visually legible.

- [x] T10: Apply Liquid Glass to approved picker and in-picker surfaces
  - Route `ContentView` panel background/overlay through shared picker glass instead of competing `NSVisualEffectView(.menu)` styling.
  - Apply glass modifiers to picker URL action buttons, shortcut/keycap badges, rule suggestion banner, selected/hover browser hit areas only where appropriate, and `ConfigureRuleView` cards/chips.
  - Do not glass browser icons, text labels, dividers, dense list rows, or standard controls.
  - Verification: picker renders correctly on macOS 26, oldest-supported fallback, dark/light mode, reduce transparency, keyboard navigation, and full-screen overlay.

- [x] T11: Apply optional Liquid Glass polish to non-picker custom cards only where safe
  - Evaluate and selectively update `BrowserCardView`, `RuleUIComponents.DetailSection`, `FilterChip`, and onboarding prompt/status/demo cards.
  - Leave Settings `NavigationSplitView`, sidebar, lists, forms, modal sheets, AppKit menus, and file panels standard.
  - Prefer standard `.buttonStyle(.glass)` / `.glassProminent` only for macOS 26+ buttons where Apple guidance fits.
  - Verification: settings/onboarding stay readable and native; no over-glassed dense surfaces.

- [x] T12: Release metadata, build number, and TestFlight notes
  - Bump `CURRENT_PROJECT_VERSION` to a unique value greater than the last uploaded App Store Connect build.
  - Bump `MARKETING_VERSION` only if intentionally creating a new external version.
  - Draft TestFlight beta notes emphasizing native macOS, profile reliability, MCP opt-in hardening, and Liquid Glass on latest macOS.
  - Create a manual Xcode Organizer upload checklist.
  - Verification: project builds with updated version; release notes do not overpromise unsupported market-backlog features.

- [x] T13: Market-gap backlog documentation
  - Create or update a backlog note listing non-blocking market gaps: browser extensions, rule tester/history, tracking stripping, URL rewrites/native app targets, short URL expansion, Focus/Shortcuts, mail/file handlers.
  - Explicitly mark them post-TestFlight and out of scope for this release.
  - Verification: backlog exists and no implementation task includes these features.

- [x] T14: Full release verification and manual upload readiness
  - Run primary build, unit tests, and App Store/TestFlight archive command. UI/E2E tests are waived/skipped by explicit user instruction for this release continuation, not green.
  - Run manual QA gates on current macOS and oldest supported target available.
  - Verify MCP curl behavior, onboarding, routing, profiles, private mode, settings persistence, and Liquid Glass/fallback paths.
  - Prepare final human step: open archive in Xcode Organizer and upload to TestFlight.
  - Verification: required automated checks pass, meaning Release build, unit tests, App Store/TestFlight archive, and archive metadata; historical UI/E2E failures and the user waiver are recorded; manual QA evidence recorded; archive exists at `release/Chowser.xcarchive` or chosen archive path.

---

## Final Verification Wave

- [x] F1: Release readiness reviewer approves archive/upload checklist and version/build metadata
- [x] F2: Native implementation reviewer approves sandbox profiles, launch behavior, onboarding, routing, rule validation, and MCP hardening
- [x] F3: Liquid Glass/design reviewer approves Apple-guided selective adoption, accessibility, and fallback behavior
- [x] F4: QA reviewer approves Release build, unit tests, archive and archive metadata, manual flow evidence, MCP curl evidence, sandbox profile/private-mode evidence, and the recorded UI/E2E waiver with historical failed-test evidence
- [x] F5: Product scope reviewer approves market-gap backlog separation and confirms no Electrobun/Windows/Linux/market-expansion scope leaked into release

---

## Notes for Execution Agents

- Work directly in the current repository unless a worktree is explicitly requested later.
- Do not resume the stale `chowser-electrobun-release` boulder state for this plan.
- Use project skills for SwiftUI, macOS, Liquid Glass, Swift concurrency, Swift style, and Swift testing when delegating implementation.
- Treat sandboxed profile/private-mode validation as the first hard gate before Liquid Glass polish.
- Every task must append findings to `.sisyphus/notepads/native-testflight-reactivation/`.
