# Chowser 3.1.5 Release Verification

Date: 2026-06-12
Task: T14 full release verification and manual upload readiness

## Summary

T14 automated release verification was run with isolated DerivedData paths under `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/`. Product source code, project settings, entitlements, tests, CI, export/upload tooling, and `chowser-electrobun/` were not modified.

Scope change: after the UI-test attempts below failed, the user explicitly said “do not do e2e anymore”. UI/E2E tests are therefore waived/skipped by user instruction for this release continuation. They are not green and should not be represented as passed. Required automated release gates now rely on the Release build, unit tests, App Store/TestFlight archive, and archive metadata.

Post-F2 update: after the Add Browser profile-collapse fix, Atlas independently verified the targeted `BrowserConfigTests` and Release build, then reran a fresh App Store/TestFlight archive. The post-F2 archive replaced the prior archive at `release/Chowser.xcarchive`; metadata still verifies `Applications/Chowser.app`, bundle `in.sreerams.Chowser`, version `3.1.5`, and build `202606110001`.

Current machine: macOS 26.4.1 (`25E253`). Oldest-supported macOS QA is unavailable on this machine and remains pending human QA on a real macOS 14 target.

## Command results

| Gate | Command | Result | Evidence |
| --- | --- | --- | --- |
| Primary Release build | `xcodebuild -project "Chowser.xcodeproj" -scheme "Chowser" -configuration Release build -derivedDataPath "/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14BuildDerivedData"` | Passed: `** BUILD SUCCEEDED **` | Built app exists at `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14BuildDerivedData/Build/Products/Release/Chowser.app`. |
| Unit tests | `xcodebuild test -project "Chowser.xcodeproj" -scheme "Chowser" -destination 'platform=macOS' -only-testing:ChowserTests -derivedDataPath "/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UnitDerivedData"` | Passed: `** TEST SUCCEEDED **`; Swift Testing reported `145 tests in 6 suites passed`. | `.xcresult`: `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UnitDerivedData/Logs/Test/Test-Chowser-2026.06.12_09-33-25-+0530.xcresult`. Full captured output: `/Users/sreeram/.local/share/opencode/tool-output/tool_eb9ffe7900015yAlN3pDVlzy0Z`. |
| Post-F2 targeted BrowserConfigTests and Release build | Targeted `BrowserConfigTests` plus Release build after the Add Browser profile-collapse fix. | Passed: targeted `BrowserConfigTests` and Release build passed. | Captured output: `/Users/sreeram/.local/share/opencode/tool-output/tool_eba45eb8e0013X2agOuArS0a0I`. |
| UI/E2E tests | Waived/skipped after user instruction: “do not do e2e anymore”. Historical attempt retained: two-step existing-scheme recovery built the Debug host app, then ran `xcodebuild test -project "Chowser.xcodeproj" -scheme "ChowserUITests" -destination 'platform=macOS' -derivedDataPath "/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UITwoStepDerivedData"`. | Not a required release gate for this continuation. Not green: the retained attempt failed after executing UI tests, `Executed 11 tests, with 11 failures (0 unexpected)`. Representative failures: `Settings UI did not appear`, `Picker UI should be visible`, and `Add rule button not found`. | Host app exists at `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UITwoStepDerivedData/Build/Products/Debug/Chowser.app`. `.xcresult`: `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UITwoStepDerivedData/Logs/Test/Test-ChowserUITests-2026.06.12_09-39-05-+0530.xcresult`. Full captured output: `/Users/sreeram/.local/share/opencode/tool-output/tool_eba04e7cf001hmVuUnIjvo96Ld`. |
| App Store/TestFlight archive | `xcodebuild archive -project "Chowser.xcodeproj" -scheme "Chowser" -configuration Release -derivedDataPath "/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14ArchiveDerivedData" -archivePath "release/Chowser.xcarchive" ENABLE_APP_SANDBOX=YES CODE_SIGN_ENTITLEMENTS=Chowser/ChowserAppStore.entitlements SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APP_STORE'` | Passed: `** ARCHIVE SUCCEEDED **` | Archive exists at `release/Chowser.xcarchive`. Full captured output: `/Users/sreeram/.local/share/opencode/tool-output/tool_eba00a98e001mb0mMfYfpeWprf`. |
| Fresh post-F2 App Store/TestFlight archive | `xcodebuild archive` after the Add Browser profile-collapse fix, using DerivedData `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserAtlasPostF2ArchiveDerivedData` and archive path `release/Chowser.xcarchive`. | Passed: fresh post-F2 archive succeeded. | Archive exists at `release/Chowser.xcarchive`. Captured output: `/Users/sreeram/.local/share/opencode/tool-output/tool_eba4850020019n4vWF8Inf16QP`. |
| Archive metadata | `test -d "release/Chowser.xcarchive"` and `/usr/libexec/PlistBuddy` reads from archive `Info.plist` | Passed | `ApplicationPath = Applications/Chowser.app`; `CFBundleIdentifier = in.sreerams.Chowser`; `CFBundleShortVersionString = 3.1.5`; `CFBundleVersion = 202606110001`. |

## Archive readiness

- Archive path: `release/Chowser.xcarchive`.
- Archive app path: `Applications/Chowser.app`.
- Bundle ID: `in.sreerams.Chowser`.
- Version/build: `3.1.5` / `202606110001`.
- App Store build flags used: `ENABLE_APP_SANDBOX=YES`, `CODE_SIGN_ENTITLEMENTS=Chowser/ChowserAppStore.entitlements`, `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APP_STORE'`.
- Archive was not exported, uploaded, notarized, or opened in Organizer.

## Manual QA status

These gates were not manually passed in this run unless noted below. They remain pending human QA because they require interactive app/browser/default-browser state, signed sandbox/TestFlight behavior, specific browser installs/profiles, older OS hardware/VMs, or visual inspection.

| Manual gate | Status | Evidence / next step |
| --- | --- | --- |
| MCP curl behavior on port 24245 | Pending human QA | Unit tests did verify token behavior on test port 24246, including 401 without/wrong/malformed token, 200 for authorized endpoints, and stopped-server refusal. Manual app-run curl with UI-visible token still pending. |
| Onboarding lifecycle/reset | Pending human QA | Unit tests cover canonical onboarding state; visible first-launch/replay/reset flow still pending. |
| External app URL routing/source-app capture | Pending human QA | Unit tests cover source-app rule matching and context cleanup; real external app click flow still pending. |
| Browser profiles in signed sandbox/TestFlight | Pending human QA | Archive exists for manual signed sandbox/TestFlight validation; profile access grant and real Chrome/Firefox profile discovery still pending. |
| Private/profile/custom launch behavior | Pending human QA | Unit tests cover direct-download launch plans and App Store launch-argument guardrails. Real browser behavior still pending; App Store/TestFlight should not overpromise private/profile/custom launch args. |
| Settings persistence | Pending human QA | Unit tests cover persistence; visible edit/relaunch flow still pending. |
| Liquid Glass/fallback paths | Pending human QA | Current machine is macOS 26.4.1; no visual QA was performed. macOS 26 Liquid Glass, macOS 14 fallback, dark/light mode, Reduce Transparency, keyboard navigation, and full-screen overlay remain pending. |
| Oldest-supported macOS | Unavailable locally | No real macOS 14 target is available in this run. Test on real oldest-supported target before final release confidence. |

## Blockers / follow-up

- UI/E2E tests are waived/skipped for this release continuation by explicit user instruction, “do not do e2e anymore”. They are not green. Historical evidence is retained: the initial direct `ChowserUITests` scheme attempt failed before execution because the host app was missing. Recovery then used a same-DerivedData two-step flow to build the `Chowser` Debug host app and run the existing `ChowserUITests` scheme; that invocation executed all 11 UI tests, but all 11 failed on UI assertions (`Settings UI did not appear`, `Picker UI should be visible`, `Add rule button not found`). Do not treat UI/E2E as an active automated release blocker under the updated scope.
- Human manual QA remains required for MCP curl with a UI-visible token, onboarding, routing, browser profiles/private behavior, Settings persistence, Liquid Glass/fallback visuals, and oldest-supported macOS.

## UI-test retry history

- Direct UI-test scheme attempt: `xcodebuild test -project "Chowser.xcodeproj" -scheme "ChowserUITests" -destination 'platform=macOS' -derivedDataPath "/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UIDerivedData"` failed before execution because `Build/Products/Debug/Chowser.app` was missing. `.xcresult`: `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UIDerivedData/Logs/Test/Test-ChowserUITests-2026.06.12_09-33-51-+0530.xcresult`.
- Host-scheme attempt: `xcodebuild test -project "Chowser.xcodeproj" -scheme "Chowser" -destination 'platform=macOS' -only-testing:ChowserUITests -derivedDataPath "/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UIHostDerivedData"` failed immediately because `ChowserUITests` is not a member of the `Chowser` scheme/test plan. Error result bundle: `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/ResultBundle_2026-12-06_09-38-0039.xcresult`.
- Two-step existing-scheme recovery built the host app and executed the UI target, but the test suite failed: `Executed 11 tests, with 11 failures (0 unexpected)`. `.xcresult`: `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UITwoStepDerivedData/Logs/Test/Test-ChowserUITests-2026.06.12_09-39-05-+0530.xcresult`.

## Final human upload step

After accepting the UI/E2E waiver and completing required manual QA, open Xcode > Window > Organizer > select `release/Chowser.xcarchive` > Distribute App > App Store Connect > Upload.
