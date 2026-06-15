# Draft: Native TestFlight Reactivation

## Requirements (confirmed)
- Native macOS app only: user said “we will skip electro bun for now, because we don't have linux or windows to test.”
- TestFlight reactivation: app was removed from TestFlight due to no updates, and user wants to push one for TestFlight users.
- Review implementation issues before release.
- Review market/category gaps and missing features.
- Fully support Liquid Glass in the native macOS UI for this TestFlight cycle.

## Technical Decisions
- Electrobun is explicitly out of scope for this plan; no Windows/Linux testing or packaging work.
- Treat upcoming work as a TestFlight-only reactivation release, not a broad product relaunch or public App Store submission candidate.
- Separate release blockers from post-TestFlight product backlog to prevent scope creep.
- MCP/local API remains opt-in and visible in Settings/onboarding, but must be security/review hardened enough for TestFlight.
- Browser profile support must fully work in sandbox/TestFlight; unreliable profile behavior is a release blocker.
- Upload path is manual Xcode Organizer, not CI automation for this cycle.
- Verification coverage is current macOS plus the oldest supported App Store target available to the implementer.
- Test strategy is tests-after plus agent-executed QA; targeted tests are added for changed code and critical release paths.
- Liquid Glass support is in scope for native SwiftUI/AppKit UI only; it must use Apple-native APIs, keep macOS availability gates, and preserve non-glass fallbacks.
- Full Liquid Glass support means selective, Apple-guided adoption: central reusable modifiers, custom floating/card/chip surfaces only, not glassing every settings/list/form control.

## Research Findings
- Strategic release review: release-blocking scope should be App Store/TestFlight archive, signing/sandbox/version, core onboarding/link interception/picker/rules/settings flow, and no sandbox-incompatible behavior.
- Market research: Chowser already covers baseline browser-router features; missing competitive features like browser extensions, rule tester/history, tracking stripping, URL rewrite rules, and Shortcuts/Focus should be backlog, not TestFlight blockers.
- Release readiness: App Store build settings exist, but repo automation does not upload TestFlight; version/build must be bumped; App Store URL IDs differ across README/docs; `DISTRIBUTION.md` claims TestFlight automation that is not implemented.
- Native implementation audit: critical/high risks are sandbox profile discovery, untested AppDelegate URL/source-app interception, App Store profile/private launch divergence, split onboarding state, and MCP review/security surface.
- Liquid Glass research: Apple documents Liquid Glass across latest Apple platforms; standard SwiftUI/AppKit controls pick it up automatically when built with latest SDKs and run on latest platform releases. Custom SwiftUI surfaces use `glassEffect(_:in:)`, `GlassEffectContainer`, and glass button styles with availability fallbacks.
- Existing Chowser state: `Chowser/PickerViewModifiers.swift` already gates `.glassEffect` behind `#available(macOS 26.0, *)` and falls back to `.ultraThinMaterial` / solid backgrounds for older macOS or reduced transparency.
- Liquid Glass UI map: `PickerViewModifiers.swift` should become the central modifier family; `ContentView.swift` currently has a separate custom `NSVisualEffectView(.menu)` panel background and should route through the shared picker glass system.
- Liquid Glass UI map: adopt glass for picker panel surface, picker URL action buttons, shortcut/keycap badges, rule suggestion banner, and in-picker `ConfigureRuleView` cards/chips.
- Liquid Glass UI map: optional/selective glass for browser grid cards, rule detail `DetailSection` cards, filter chips, and onboarding hero/prompt/status cards.
- Liquid Glass UI map: do not glass `NSMenu`, status item, `NSOpenPanel`/`NSSavePanel`, Settings window/sidebar/list rows/forms, dense browser/rule rows, or ordinary text/status badges.
- Apple guidance: standard controls adopt Liquid Glass automatically on latest SDK/OS; custom glass should be sparse; use `GlassEffectContainer` for grouped custom effects; `.interactive()` only belongs on real interactive surfaces.

## Open Questions
- None blocking.

## Scope Boundaries
- INCLUDE: Native Swift macOS release readiness, version/build bump, App Store/TestFlight archive path, core flow QA, critical native fixes, full native Liquid Glass support with fallbacks, release notes/tester notes, implementation audit triage, market-gap backlog.
- EXCLUDE: Electrobun, Windows/Linux, browser extensions, URL rewrite scripting, Focus/Shortcuts, mail/file handlers, major product relaunch, broad refactors not tied to release risk.
