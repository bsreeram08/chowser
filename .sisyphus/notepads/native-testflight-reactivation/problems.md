# Native TestFlight Reactivation Problems

## 2026-06-11 Task: plan-initialization
- No blockers yet; plan just initialized.

## 2026-06-11 Task: T2 sandbox profile-access implementation
- Manual QA is still required in a signed sandbox/TestFlight build: open Settings/Add Browser/onboarding, grant `~/Library/Application Support`, verify profile rows appear, reset/revoke access, and confirm recovery banners return without crashes.
- Temporary App Store home-relative entitlement exceptions were intentionally left in place for this task; removal should wait until signed-sandbox manual QA proves the bookmark path works.

## 2026-06-11 Task: T2 Atlas verification fixes
- Atlas found two T2 defects: panel default used `homeDirectoryForCurrentUser` which can resolve to the sandbox container, and grant status hid recovery UI when bookmark resolution succeeded but security-scoped access would fail. Both are fixed; signed sandbox/TestFlight manual QA is still required.

## 2026-06-11 Task: T3 sandboxed launch validation implementation
- Manual QA remains required in a signed sandbox/TestFlight build: verify Chrome default/non-default/private and Firefox default/non-default launches now behave according to the explicit App Store limitation (browser selection reliable; profile/private arguments not claimed as delivered).
- Per-file LSP diagnostics still report existing SourceKit indexing false positives for project symbols/Testing, but `xcodebuild test` and Release build both compile the modified files successfully.

## 2026-06-11 Task: T3 post-review fixes
- Signed sandbox/TestFlight manual QA remains required for final release confidence: verify browser app selection for Chrome and Firefox, confirm App Store UI disables or explains profile/private/custom launch limitations, and verify direct-download builds still deliver profile/private arguments.

## 2026-06-11 Task: T4 MCP API hardening
- Manual T14 curl checks: start API server, capture token from Settings/onboarding UI, then verify `curl -i http://localhost:24245/status` returns `401` and `curl -i -H "Authorization: Bearer <token>" http://localhost:24245/status` returns `200` with status schema.
- Manual T14 curl checks should also cover `GET /browsers` and `GET /rules` with and without the Bearer header, then stop the server and verify localhost:24245 refuses the connection.
- Per-file SourceKit diagnostics still show known false positives for project symbols and the `Testing` module; targeted `xcodebuild test` and Release `xcodebuild` both passed.

## 2026-06-11 Task: T5 onboarding state unification
- Manual T14 QA should verify the UI-visible lifecycle in a signed app: fresh install shows onboarding once, completing onboarding suppresses it on relaunch, Settings “Replay Onboarding” opens the welcome flow, and “Reset to Fresh Setup” causes onboarding to appear again on next launch.
- Per-file SourceKit diagnostics still show known false positives for project symbols and the `Testing` module; `OnboardingStateTests`, `BrowserManagerTests`, and Release `xcodebuild` passed.

## 2026-06-11 Task: T3 final App Store guardrail pass
- No new code blockers found. SourceKit per-file diagnostics still cannot resolve project symbols, but the required `BrowserLaunchTests` and Release build both compile the modified files successfully.
- Signed sandbox/TestFlight manual QA remains required: verify App Store UI no longer advertises private/profile/custom launch support in picker, menu bar, browser edit, and rule edit paths; verify direct-download builds still support private/profile/custom arguments.

## 2026-06-11 Task: T6 URL/source-app routing seams
- Per-file SourceKit diagnostics still show known false positives for project symbols and `Testing`; targeted `xcodebuild test` and Release build passed and are the compile truth.
- Manual T14 QA remains required for broad external-click behavior: set Chowser as default browser, create a source-app-specific rule from an external app such as Slack/Mail, click a matching HTTP/HTTPS link, verify Chowser routes directly to the configured browser, then hold Shift on a matching link and verify the picker appears instead.

## 2026-06-11 Task: T7 centralized rule validation
- Per-file SourceKit diagnostics still show known false positives for project symbols and `Testing`; the new rule validation code compiled through targeted `xcodebuild test` and Release `xcodebuild`.
- Initial parallel `xcodebuild test` invocation hit Xcode's shared DerivedData `build.db` lock for `BrowserManagerTests`; rerunning the suite sequentially passed.
- Manual T14 QA should include importing a mixed valid/invalid rules JSON and exercising MCP `POST /rules` with invalid host/regex/path/browser/source-app values using the UI-visible token, although automated BrowserManager/MCP coverage now verifies the safety behavior.

## 2026-06-11 Task: T8 clipboard private-mode routing
- Per-file SourceKit diagnostics still show known project-index false positives for modified Swift files (`BrowserManager`, `AppEnvironment`, `Testing`, etc. unresolved), but targeted `xcodebuild test` and Release `xcodebuild` both compiled successfully.
- Manual T14 QA should verify the visible clipboard flow in a direct-download build: copy an HTTP/HTTPS URL, choose menu bar Open Clipboard URL → Open in Private, confirm the picker shows private mode pre-armed when no rule matches, and confirm Chrome/Firefox receive private/incognito launch behavior when selected.
- Manual T14 QA should also verify an App Store/TestFlight build still hides the Open in Private clipboard submenu and only exposes regular clipboard opening.
- The initial T8 review found a resolved implementation defect: the private request was a global Boolean and picker sync only happened on `onAppear`; it was fixed with URL-scoped one-shot consumption and `ContentView` resync on URL/request changes before final verification.

## 2026-06-11 Task: T9 Liquid Glass modifier infrastructure
- Manual visual QA remains required on macOS 26: apply the new picker modifiers in T10/T11 and verify panel, mini-button, chip, and inline-card glass shapes look correct without over-glassing dense rows or Settings surfaces.
- Manual fallback QA remains required on macOS 14 and with Reduce Transparency enabled: confirm solid `windowBackgroundColor` / `controlBackgroundColor` surfaces remain legible and that non-glass fallbacks match the existing low-opacity/material picker style.

## 2026-06-11 Task: T10 picker Liquid Glass adoption
- Manual visual QA remains required on macOS 26, macOS 14 fallback, light/dark mode, Reduce Transparency, keyboard navigation, and full-screen overlay because these are visual/runtime picker states not covered by automated tests in this task.
- Per-file SourceKit diagnostics still show known project-index false positives for modified Swift files (`BrowserManager`, `ConfigureRuleView`, `DetailRow`, and picker modifier extensions unresolved), but Release `xcodebuild` compiled `ContentView.swift`, `ConfigureRuleView.swift`, and `PickerViewModifiers.swift` successfully.
- No targeted tests were run because T10 changed visual modifiers only and did not touch browser selection, URL copy, private-mode state, rule creation persistence, or keyboard event handling seams.

## 2026-06-11 Task: T11 optional non-picker Liquid Glass polish
- Manual visual QA remains required for Settings browser-grid cards, rule detail sections, filter chips, and onboarding browser/AI setup steps on macOS 26, macOS 14 fallback, light/dark mode, and Reduce Transparency; verify text contrast stays high and no dense Settings/List/Form surfaces look over-glassed.
- Per-file SourceKit diagnostics still show known project-index/cross-file false positives for dependent Swift files (`BrowserConfig`, `BrowserManager`, `SandboxBookmarkManager`, `MCPServer`, and custom modifier extensions unresolved), while `PickerViewModifiers.swift` reports zero diagnostics and Release `xcodebuild` compiled all modified files successfully.
- No targeted component/snapshot tests exist for `BrowserCardView`, `FilterChip`, `DetailSection`, or onboarding visual surfaces; T11 verification therefore used per-file diagnostics plus the required Release build.
- Post-review issue resolved: unshortening progress/error indicators were initially treated as glass badges; they were reverted to plain low-opacity status backgrounds and the Release build still passes.

## 2026-06-12 Task: T14 timeout recovery
- No durable pre-timeout T14 command log, `RELEASE_VERIFICATION.md`, or `release/*.xcarchive` was found during recovery, so build/test/archive/manual QA outcomes remain unverified for T14.
- No `xcodebuild` process was still running at recovery time; the timed-out command does not need cancellation.

## 2026-06-12 Task: T14 UI-test blocker
- UI-test recovery proved an existing invocation can build/find the host app and execute `ChowserUITests`, but the UI suite is red: 11/11 tests failed on runtime UI assertions. This blocks T14 automated verification until resolved or a later valid invocation passes.
