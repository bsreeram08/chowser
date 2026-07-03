# Send Links to iPhone

## TL;DR
> **Summary**: Add a picker-level “Send to iPhone” action menu for the current URL, covering both clicked links and clipboard URLs through Chowser’s existing picker flow. The menu offers AirDrop, QR code, and Copy URL, while best-effort Handoff advertising runs while the picker is open without claiming device detection.
> **Deliverables**:
> - New implementation branch: `feature/send-to-iphone` preferred, fallback `feature/send-to-iphone-20260703` if the preferred branch already exists
> - Testable phone-handoff service seams
> - AirDrop, QR, Copy URL, and Handoff lifecycle support
> - Picker action menu/sheet with accessibility identifiers
> - Swift Testing unit coverage plus limited UI smoke coverage
> - README feature note
> **Effort**: Medium
> **Parallel**: YES - 4 waves
> **Critical Path**: Task 1 → Task 2 → Tasks 3/4 → Task 5 → Task 6 → Final Verification

## Context
### Original Request
User wants Chowser to help open the current link on their phone, whether the URL came from the clipboard or a clicked link. If an iPhone is available through the same iCloud account, the picker should provide a “Send to iPhone” path; otherwise Chowser should show a QR code for the phone Camera app to scan. The motivation is phone-based authentication for some links.

### Interview Summary
- UX: use an action menu, not immediate AirDrop and not QR-first.
- Handoff: include best-effort Handoff in v1.
- Testing: use TDD.
- Branching: executor must create a new branch before implementation.

### Research Summary
- Existing clicked URL flow: `AppDelegate.application(_:open:)` sets `BrowserManager.currentURL`; `showPicker()` hosts `ContentView` in a `ChowserPanel`.
- Existing clipboard URL flow: status menu calls `openClipboardURL()` / `openClipboardURLPrivate()`, validates HTTP(S), then routes through the same app-open path.
- Best picker UI insertion point: `ContentView.urlBubble(url:)`, beside existing URL mini-actions for copy and quick-rule creation.
- No existing QR, `CIQRCodeGenerator`, `NSSharingService`, Handoff/`NSUserActivity`, CloudKit/iCloud, MultipeerConnectivity, or WatchConnectivity code exists.
- Current entitlements do not include iCloud/CloudKit/associated domains; AirDrop + QR require no new entitlement. Handoff may need `NSUserActivityTypes` if using a custom activity type.
- Unit tests use Swift Testing and are strong. UI tests exist with launch flags/accessibility IDs but are documented as unstable and are not enforced by CI.

### Metis Review (gaps addressed)
- Add explicit branch preflight with `feature/send-to-iphone`.
- Do not claim paired/same-iCloud iPhone detection; public APIs cannot guarantee it.
- Handoff must be best-effort and lifecycle-scoped to picker visibility/current URL.
- Avoid real AirDrop/share UI in automated tests by adding protocol seams/fakes.
- Treat UI tests as limited smoke because current UI suite is unstable.

## Work Objectives
### Core Objective
Give users a reliable way to transfer the current HTTP(S) URL from Chowser’s picker to an iPhone using public, App-Store-safe macOS APIs: AirDrop, QR code, Copy URL, and best-effort Handoff.

### Deliverables
- New branch `feature/send-to-iphone` created before edits, or `feature/send-to-iphone-20260703` if the preferred branch already exists.
- Phone-handoff service layer with injectable protocols for share service, pasteboard, QR generation, and Handoff activity lifecycle.
- TDD unit tests for service decisions, QR generation, AirDrop adapter invocation, pasteboard copy, and Handoff lifecycle.
- Picker-level action menu/sheet exposed near the URL bubble for any valid current URL.
- QR fallback sheet displaying a scannable QR image and the exact URL/domain.
- Accessibility identifiers for new controls.
- README feature-list update.

### Definition of Done (verifiable conditions with commands)
- `git branch --show-current` outputs `feature/send-to-iphone` or `feature/send-to-iphone-20260703` before source edits begin.
- Unit tests pass:
  ```bash
  xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests
  ```
- A targeted UI smoke test either passes or records a pre-existing infrastructure waiver with evidence:
  ```bash
  xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS' -only-testing:ChowserUITests/ChowserUITests/testSendToIPhoneActionMenu
  ```
- Release build still succeeds:
  ```bash
  xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build
  ```

### Must Have
- Action label may say “Send to iPhone”.
- Action menu must contain exactly these actionable choices: `AirDrop…`, `Show QR Code`, `Copy URL`.
- Handoff must be described only as best-effort background availability, e.g. “Also available via Handoff on nearby Apple devices when supported.”
- AirDrop path must call public `NSSharingService.Name.sendViaAirDrop` via an adapter/protocol.
- QR path must use Core Image `CIQRCodeGenerator` or an equivalent public Apple framework API.
- Copy path must use a pasteboard abstraction in tests and `NSPasteboard.general` in production.
- Handoff path must use `NSUserActivity.webpageURL` for HTTP(S) URLs and must invalidate when picker closes.

### Must NOT Have
- No claim that Chowser detected a paired iPhone.
- No guaranteed “same iCloud” delivery claims.
- No iOS companion app.
- No CloudKit relay.
- No private AirDrop/device-discovery APIs.
- No MultipeerConnectivity, WatchConnectivity, NearbyInteraction, or Bonjour device discovery in v1.
- No new iCloud/CloudKit/associated-domain entitlement unless a documented Handoff implementation requires a narrow `Info.plist` activity declaration.
- No automated tests that open real AirDrop UI, require a real iPhone, require an iCloud account, or require Bluetooth/Wi‑Fi proximity.

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: TDD + Swift Testing for service/model logic; limited XCTest UI smoke with explicit waiver path for pre-existing UI instability.
- QA policy: Every task has agent-executed scenarios.
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy
### Parallel Execution Waves
> Target: 5-8 tasks per wave. <3 per wave (except final) = under-splitting.
> Extract shared dependencies as Wave-1 tasks for max parallelism.

Wave 1: Task 1 branch/baseline, Task 2 seam-first service contracts/tests
Wave 2: Task 3 QR generation, Task 4 sharing/copy/Handoff adapters
Wave 3: Task 5 picker UI action menu/sheet, Task 6 UI smoke hooks/tests
Wave 4: Task 7 docs/final local verification

### Dependency Matrix (full, all tasks)
- Task 1 blocks all source edits.
- Task 2 blocks Tasks 3, 4, 5, and 6.
- Task 3 blocks QR UI in Task 5.
- Task 4 blocks AirDrop/Copy/Handoff UI wiring in Task 5.
- Task 5 blocks Task 6.
- Tasks 2-6 block Task 7.

### Agent Dispatch Summary (wave → task count → categories)
- Wave 1 → 2 tasks → `quick`, `deep`
- Wave 2 → 2 tasks → `quick`, `deep`
- Wave 3 → 2 tasks → `visual-engineering`, `quick`
- Wave 4 → 1 task → `writing`

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. Create implementation branch and capture baseline

  **What to do**: Before editing source files, verify the working tree and create the required implementation branch.
  1. Run `git status --short` and save output to `.sisyphus/evidence/task-1-branch-status.txt`.
  2. Run `git rev-parse --verify feature/send-to-iphone`.
  3. If `feature/send-to-iphone` does not exist, run `git checkout -b feature/send-to-iphone`.
  4. If `feature/send-to-iphone` already exists, run `git rev-parse --verify feature/send-to-iphone-20260703`; if that fallback does not exist, run `git checkout -b feature/send-to-iphone-20260703`; if both branches exist, stop and report `new branch requirement blocked: both planned branch names exist`.
  5. Run `git branch --show-current` and save output to `.sisyphus/evidence/task-1-branch-current.txt`.
  6. Run baseline unit tests and save output to `.sisyphus/evidence/task-1-baseline-unit-tests.txt`:
     ```bash
     xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests
     ```

  **Must NOT do**: Do not edit source files before a new branch is created. Do not checkout an existing branch. Do not use `git reset`, `git clean`, force checkout, or delete branches.

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: branch creation and baseline verification are straightforward but safety-sensitive.
  - Skills: [`git-master`] - Required for safe git operations.
  - Omitted: [`macos-developer`] - No macOS implementation happens in this task.

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: Tasks 2-7 | Blocked By: none

  **References** (executor has NO interview context - be exhaustive):
  - Commands: `AGENTS.md` - canonical Chowser build/test commands.
  - Test scheme: `Chowser.xcodeproj/xcshareddata/xcschemes/Chowser.xcscheme` - app unit-test scheme includes `ChowserTests`.

  **Acceptance Criteria** (agent-executable only):
  - [ ] `.sisyphus/evidence/task-1-branch-current.txt` contains exactly `feature/send-to-iphone` or `feature/send-to-iphone-20260703`.
  - [ ] `git branch --show-current` outputs `feature/send-to-iphone` or `feature/send-to-iphone-20260703`.
  - [ ] Baseline unit-test output is saved to `.sisyphus/evidence/task-1-baseline-unit-tests.txt`.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Branch created before implementation
    Tool: Bash
    Steps: git branch --show-current
    Expected: stdout is exactly feature/send-to-iphone or feature/send-to-iphone-20260703
    Evidence: .sisyphus/evidence/task-1-branch-current.txt

  Scenario: Existing branch conflict is handled safely
    Tool: Bash
    Steps: git rev-parse --verify feature/send-to-iphone before checkout
    Expected: if preferred branch exists, executor creates fallback feature/send-to-iphone-20260703; if preferred does not exist, executor creates feature/send-to-iphone
    Evidence: .sisyphus/evidence/task-1-branch-status.txt
  ```

  **Commit**: NO | Message: n/a | Files: none

- [x] 2. Add TDD service seam for phone link transfer decisions

  **What to do**: Create the test-first core layer that makes the feature deterministic without invoking system UI.
  1. Add failing Swift Testing coverage in `ChowserTests/PhoneLinkTransferServiceTests.swift`.
  2. Add production source `Chowser/PhoneLinkTransferService.swift` and include it in `Chowser.xcodeproj/project.pbxproj`.
  3. Define `@MainActor @Observable final class PhoneLinkTransferManager` with injectable dependencies and a `shared` instance for UI.
  4. Define action availability for valid HTTP(S) URLs only.
  5. Define menu actions exactly as `airDrop`, `showQRCode`, `copyURL`; Handoff is a lifecycle/status behavior, not a selectable delivery target.
  6. Add explicit status copy constants:
     - Button label: `Send to iPhone`
     - Menu explanatory text: `Also available via Handoff on nearby Apple devices when supported.`
     - No-device-detection guardrail: no string may contain `detected iPhone`, `paired iPhone`, or `same iCloud iPhone found`.

  **Must NOT do**: Do not call `NSSharingService`, `NSPasteboard.general`, Core Image, or `NSUserActivity` directly in this task. This task creates seams and decision logic only.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: defines the feature boundary and testable domain model.
  - Skills: [`Swift Unit Testing Skill`, `swift-style`] - Swift Testing patterns and idiomatic Swift naming.
  - Omitted: [`swiftui-expert-skill`] - No SwiftUI UI is implemented yet.

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: Tasks 3-6 | Blocked By: Task 1

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `Chowser/BrowserManager.swift:318-331` - existing clipboard private request state pattern.
  - Pattern: `Chowser/BrowserManager.swift:337-365` - existing capability/availability flags pattern.
  - Pattern: `ChowserTests/BrowserManagerTests.swift` - representative Swift Testing style.
  - Pattern: `ChowserTests/BrowserLaunchTests.swift` - pure launch-planning tests without invoking real browser opens.
  - Project wiring: `Chowser.xcodeproj/project.pbxproj` - add new source/test file references.

  **Acceptance Criteria** (agent-executable only):
  - [ ] `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/PhoneLinkTransferServiceTests` passes.
  - [ ] Tests prove `https://example.com/path?q=1` exposes AirDrop, QR, and Copy URL actions.
  - [ ] Tests prove invalid URLs or nil current URL expose no enabled phone-transfer actions.
  - [ ] Repository search for forbidden phrases returns no production UI strings: `detected iPhone`, `paired iPhone`, `same iCloud iPhone found`.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Valid URL exposes phone actions
    Tool: Bash
    Steps: xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/PhoneLinkTransferServiceTests/testValidHTTPURLExposesPhoneActions
    Expected: test passes; actions are airDrop, showQRCode, copyURL
    Evidence: .sisyphus/evidence/task-2-valid-actions.txt

  Scenario: Missing URL disables feature
    Tool: Bash
    Steps: xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/PhoneLinkTransferServiceTests/testNilURLDisablesPhoneActions
    Expected: test passes; no enabled actions and no crash
    Evidence: .sisyphus/evidence/task-2-nil-url.txt
  ```

  **Commit**: YES | Message: `test(phone): add transfer decision seams` | Files: `Chowser/PhoneLinkTransferService.swift`, `ChowserTests/PhoneLinkTransferServiceTests.swift`, `Chowser.xcodeproj/project.pbxproj`

- [x] 3. Add QR generator with deterministic tests

  **What to do**: Implement QR fallback behind a testable generator.
  1. Add failing tests in `ChowserTests/PhoneLinkQRGeneratorTests.swift`.
  2. Add `Chowser/PhoneLinkQRGenerator.swift` and include it in the Xcode project.
  3. Use Core Image `CIQRCodeGenerator` to encode the exact URL absolute string as UTF-8 data.
  4. Return a display-ready `NSImage` or PNG-backed image value with deterministic size scaling suitable for SwiftUI rendering.
  5. Reject nil, empty, non-HTTP(S), and malformed URLs gracefully with a typed error/status used by UI.

  **Must NOT do**: Do not use a third-party QR library. Do not shorten, mutate, unshorten, or strip tracking parameters from the URL in this feature.

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: isolated generator with clear tests.
  - Skills: [`Swift Unit Testing Skill`, `swift-style`] - Test-first Swift implementation.
  - Omitted: [`macos-design-guidelines`] - No user-facing UI layout in this task.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Task 5 | Blocked By: Task 2

  **References** (executor has NO interview context - be exhaustive):
  - External: Apple Core Image `CIQRCodeGenerator` docs - input message is `Data`; correction levels are `L`, `M`, `Q`, `H`.
  - Pattern: `ChowserTests/LinkMetadataTests.swift` - pure parser/generator-style tests separated from network/system behavior.
  - API/Type: `Chowser/PhoneLinkTransferService.swift` - use the URL validation contract from Task 2.

  **Acceptance Criteria** (agent-executable only):
  - [ ] `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/PhoneLinkQRGeneratorTests` passes.
  - [ ] Test proves `https://example.com/path?q=1` generates non-empty image output.
  - [ ] Test proves the QR generator preserves the exact absolute URL string.
  - [ ] Test proves malformed/unsupported URL input returns a graceful error and no image.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: QR generated for HTTP URL
    Tool: Bash
    Steps: xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/PhoneLinkQRGeneratorTests/testGeneratesQRCodeForHTTPURL
    Expected: test passes; image data/extent is non-empty
    Evidence: .sisyphus/evidence/task-3-qr-success.txt

  Scenario: QR rejects invalid input
    Tool: Bash
    Steps: xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/PhoneLinkQRGeneratorTests/testRejectsInvalidURL
    Expected: test passes; typed error returned and no image emitted
    Evidence: .sisyphus/evidence/task-3-qr-invalid.txt
  ```

  **Commit**: YES | Message: `feat(phone): generate qr fallback` | Files: `Chowser/PhoneLinkQRGenerator.swift`, `ChowserTests/PhoneLinkQRGeneratorTests.swift`, `Chowser.xcodeproj/project.pbxproj`

- [x] 4. Add AirDrop, Copy URL, and Handoff adapters behind fakes

  **What to do**: Implement public Apple API adapters only through protocols from Task 2.
  1. Add failing tests in `ChowserTests/PhoneLinkSystemAdapterTests.swift`.
  2. Add `Chowser/PhoneLinkSystemAdapters.swift` and include it in the Xcode project.
  3. AirDrop adapter:
     - Use `NSSharingService(named: .sendViaAirDrop)`.
     - Use `canPerform(withItems: [url as NSURL])` for capability only.
     - Use `perform(withItems: [url as NSURL])` for production invocation.
     - In UI testing mode with `AppEnvironment.disableExternalOpen == true`, do not open real AirDrop UI; record a deterministic status instead.
  4. Pasteboard adapter:
     - Production writes exact `url.absoluteString` to `NSPasteboard.general`.
     - Tests use an in-memory fake pasteboard.
  5. Handoff adapter:
     - Use `NSUserActivity` with a Chowser-specific activity type, `webpageURL = url`, `isEligibleForHandoff = true`, `becomeCurrent()` on start/update, and `invalidate()` on stop.
     - Add `NSUserActivityTypes` to `Chowser/Info.plist` only if required by the chosen activity type.
     - Scope lifecycle to current picker URL: start when picker appears with valid HTTP(S), update when URL changes, stop when picker disappears.

  **Must NOT do**: Do not use CloudKit, associated domains, private AirDrop APIs, device discovery, or real system share UI in tests. Do not assert an iPhone exists or accepted the URL.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: system API boundaries and lifecycle behavior must be correct and testable.
  - Skills: [`macos-developer`, `Swift Unit Testing Skill`, `swift-concurrency`] - AppKit/Foundation adapters and main-actor lifecycle.
  - Omitted: [`swiftui-expert-skill`] - UI wiring is Task 5.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Task 5 | Blocked By: Task 2

  **References** (executor has NO interview context - be exhaustive):
  - External: Apple `NSSharingService` docs - supports sharing `NSURL` objects.
  - External: Apple `NSSharingService.Name.sendViaAirDrop` docs - AirDrop service sends item-provider contents to another device.
  - External: Apple `NSUserActivity.webpageURL` docs - requires HTTP(S) URL.
  - Runtime flags: `Chowser/AppEnvironment.swift` - `-UITesting_DisableExternalOpen` and test-mode helpers.
  - Pattern: `Chowser/BrowserManager.swift:1284-1352` - production URL opening with UI-test external-open guardrails.
  - Pattern: `ChowserTests/BrowserLaunchTests.swift` - adapter/plan tests that avoid launching real external apps.

  **Acceptance Criteria** (agent-executable only):
  - [ ] `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/PhoneLinkSystemAdapterTests` passes.
  - [ ] AirDrop tests prove adapter receives exact `https://example.com/path?q=1` without opening real AirDrop UI.
  - [ ] Copy tests prove exact URL string is written to fake pasteboard.
  - [ ] Handoff tests prove start, update, and invalidate lifecycle events occur for HTTP(S) URLs.
  - [ ] Handoff tests prove non-HTTP(S) URLs are ignored without throwing.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: AirDrop request is adapter-mediated
    Tool: Bash
    Steps: xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/PhoneLinkSystemAdapterTests/testAirDropUsesExactURLWithoutRealSystemUI
    Expected: test passes; fake AirDrop service records https://example.com/path?q=1
    Evidence: .sisyphus/evidence/task-4-airdrop-adapter.txt

  Scenario: Handoff lifecycle stops on picker close
    Tool: Bash
    Steps: xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests/PhoneLinkSystemAdapterTests/testHandoffInvalidatesWhenStopped
    Expected: test passes; fake activity records invalidate after stop
    Evidence: .sisyphus/evidence/task-4-handoff-stop.txt
  ```

  **Commit**: YES | Message: `feat(phone): add system transfer adapters` | Files: `Chowser/PhoneLinkSystemAdapters.swift`, `ChowserTests/PhoneLinkSystemAdapterTests.swift`, `Chowser/Info.plist`, `Chowser.xcodeproj/project.pbxproj`

- [x] 5. Add picker Send to iPhone action menu and QR sheet

  **What to do**: Wire the tested phone-transfer manager into Chowser’s picker UI.
  1. Modify `Chowser/ContentView.swift` in `urlBubble(url:)` to add a compact phone action beside existing URL mini-actions.
  2. Use visible label/icon semantics:
     - Button label/accessibility label: `Send to iPhone`
     - Recommended SF Symbol: `iphone`
     - Accessibility ID: `picker.sendToIPhoneButton`
  3. Tapping the button opens a menu/sheet with exactly three actionable controls:
     - `AirDrop…` (`iphoneAction.airDropButton`)
     - `Show QR Code` (`iphoneAction.showQRCodeButton`)
     - `Copy URL` (`iphoneAction.copyURLButton`)
  4. Include non-clickable explanatory Handoff text in the action UI: `Also available via Handoff on nearby Apple devices when supported.` with accessibility ID `iphoneAction.handoffStatusText`.
  5. QR sheet must include:
     - Root ID `iphoneQR.sheet`
     - Image ID `iphoneQR.image`
     - URL/domain text ID `iphoneQR.urlText`
     - Close button ID `iphoneQR.closeButton`
  6. Start Handoff advertisement on picker appear for valid current URL, update when URL changes, and stop on disappear.
  7. Ensure clicked links and clipboard URLs both work because they already set `BrowserManager.currentURL` before picker display.

  **Must NOT do**: Do not add a Settings toggle in v1. Do not add a separate clipboard-only UI path. Do not show the phone button when no valid HTTP(S) current URL exists. Do not say “paired iPhone detected”.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - Reason: SwiftUI picker UI, menus/sheets, accessibility, and visual fit.
  - Skills: [`swiftui-expert-skill`, `macos-design-guidelines`, `swift-style`] - Native Mac SwiftUI and HIG-consistent action design.
  - Omitted: [`swiftui-liquid-glass`] - No Liquid Glass adoption is requested.

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: Task 6 | Blocked By: Tasks 3 and 4

  **References** (executor has NO interview context - be exhaustive):
  - UI insertion: `Chowser/ContentView.swift:202-255` - URL bubble plus/copy mini-button area.
  - Picker layout: `Chowser/ContentView.swift:77-144` - panel structure.
  - Existing picker actions: `Chowser/ContentView.swift:917-942` - open/copy action helpers.
  - Existing keyboard/action handling: `Chowser/ContentView.swift:966-1119` - avoid conflicting with existing shortcuts.
  - Picker lifecycle: `Chowser/AppDelegate.swift:557-599` - `ChowserPanel` creation and hosting.
  - Clipboard flow: `Chowser/AppDelegate.swift:626-646` - clipboard URL validation routes into existing open flow.
  - Compact sheet pattern: `Chowser/ConfigureRuleView.swift:18-129` - in-picker compact modal style.
  - Accessibility pattern: `Chowser/SettingsView.swift`, `Chowser/AddRuleSheet.swift`, `ChowserUITests/ChowserUITests.swift` - stable IDs used by tests.

  **Acceptance Criteria** (agent-executable only):
  - [ ] `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests` passes after UI wiring.
  - [ ] `picker.sendToIPhoneButton` exists only when `BrowserManager.currentURL` is valid HTTP(S).
  - [ ] Action UI exposes exactly three actionable choices: `AirDrop…`, `Show QR Code`, `Copy URL`.
  - [ ] QR sheet exposes all required accessibility identifiers.
  - [ ] Production UI strings do not include `detected iPhone`, `paired iPhone`, or `same iCloud iPhone found`.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Current URL shows action menu
    Tool: Bash
    Steps: run targeted unit/UI checks with -UITesting -UITesting_OpenPicker -UITesting_DefaultURL https://example.com/path?q=1 -UITesting_DisableExternalOpen -UITesting_MockInstalledBrowsers
    Expected: picker.sendToIPhoneButton is present and opens AirDrop, Show QR Code, Copy URL choices
    Evidence: .sisyphus/evidence/task-5-action-menu.txt

  Scenario: Invalid current URL hides phone action
    Tool: Bash
    Steps: run test with missing or non-HTTP default URL
    Expected: picker.sendToIPhoneButton is absent or disabled; app does not crash
    Evidence: .sisyphus/evidence/task-5-invalid-url.txt
  ```

  **Commit**: YES | Message: `feat(picker): add send to iphone menu` | Files: `Chowser/ContentView.swift`, `Chowser/PhoneLinkTransferService.swift`, `Chowser/PhoneLinkSystemAdapters.swift`

- [x] 6. Add targeted UI smoke test and test-mode evidence hooks

  **What to do**: Add a narrowly scoped UI test that verifies the new picker controls without depending on real AirDrop, QR scanning, or iPhone availability.
  1. Extend `ChowserUITests/ChowserUITests.swift` with `testSendToIPhoneActionMenu`.
  2. Launch with:
     - `-UITesting`
     - `-UITesting_OpenPicker`
     - `-UITesting_DefaultURL https://example.com/path?q=1`
     - `-UITesting_DisableExternalOpen`
     - `-UITesting_MockInstalledBrowsers`
  3. Assert `picker.sendToIPhoneButton` exists.
  4. Activate it and assert `iphoneAction.airDropButton`, `iphoneAction.showQRCodeButton`, `iphoneAction.copyURLButton`, and `iphoneAction.handoffStatusText` exist.
  5. Activate `Show QR Code` and assert `iphoneQR.sheet`, `iphoneQR.image`, `iphoneQR.urlText`, and `iphoneQR.closeButton` exist.
  6. If existing UI infrastructure prevents execution, capture the failure output and classify it as pre-existing only if the failure occurs before any new `picker.sendToIPhoneButton` assertion.

  **Must NOT do**: Do not make UI test success depend on a real iPhone, AirDrop recipient, Handoff icon, QR scan, or system share sheet.

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: narrow UI smoke coverage using existing launch flags.
  - Skills: [`Swift Unit Testing Skill`] - XCTest/XCUI conventions.
  - Omitted: [`playwright-best-practices`] - This is native macOS XCUI, not browser automation.

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: Task 7 | Blocked By: Task 5

  **References** (executor has NO interview context - be exhaustive):
  - UI flags: `Chowser/AppEnvironment.swift` - `-UITesting`, `-UITesting_OpenPicker`, `-UITesting_DefaultURL`, `-UITesting_DisableExternalOpen`, `-UITesting_MockInstalledBrowsers`.
  - UI test patterns: `ChowserUITests/ChowserUITests.swift` - launch setup, helpers, accessibility assertions.
  - Picker IDs: `Chowser/ContentView.swift` - existing `picker.urlDisplay`, `picker.configureRuleButton`, and hidden UI-test label patterns.
  - Known risk: `RELEASE_VERIFICATION.md` - UI/E2E tests are historically unstable/waived.

  **Acceptance Criteria** (agent-executable only):
  - [ ] Targeted UI smoke command is executed and output saved:
    ```bash
    xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS' -only-testing:ChowserUITests/ChowserUITests/testSendToIPhoneActionMenu
    ```
  - [ ] If the targeted test passes, evidence is saved to `.sisyphus/evidence/task-6-ui-smoke.txt`.
  - [ ] If the targeted test fails before reaching new feature assertions, evidence is saved to `.sisyphus/evidence/task-6-ui-smoke-waiver.txt` with the exact pre-existing failure location.
  - [ ] If the targeted test fails at a new feature assertion, the task is not complete until fixed.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Action menu is reachable in picker UI
    Tool: Bash
    Steps: xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS' -only-testing:ChowserUITests/ChowserUITests/testSendToIPhoneActionMenu
    Expected: test passes or pre-existing UI infra waiver is documented before new feature assertions
    Evidence: .sisyphus/evidence/task-6-ui-smoke.txt

  Scenario: QR sheet is reachable from action menu
    Tool: Bash
    Steps: same targeted UI test activates Show QR Code
    Expected: iphoneQR.sheet, iphoneQR.image, iphoneQR.urlText, iphoneQR.closeButton exist
    Evidence: .sisyphus/evidence/task-6-qr-sheet.txt
  ```

  **Commit**: YES | Message: `test(ui): cover send to iphone picker action` | Files: `ChowserUITests/ChowserUITests.swift`, `Chowser/ContentView.swift`, `Chowser/PhoneLinkSystemAdapters.swift`

- [x] 7. Update user-facing docs and run final local verification

  **What to do**: Document the new capability and run the final command suite before review agents.
  1. Update `README.md` feature list with one concise bullet: `Send to iPhone — Transfer the current link by AirDrop, QR code, or copy, with best-effort Handoff support.`
  2. Do not add setup instructions for iCloud, CloudKit, or a companion iOS app.
  3. Run all unit tests and save output to `.sisyphus/evidence/task-7-unit-tests.txt`:
     ```bash
     xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests
     ```
  4. Run targeted UI smoke and save output to `.sisyphus/evidence/task-7-ui-smoke.txt` or waiver file as defined in Task 6:
     ```bash
     xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS' -only-testing:ChowserUITests/ChowserUITests/testSendToIPhoneActionMenu
     ```
  5. Run release build and save output to `.sisyphus/evidence/task-7-release-build.txt`:
     ```bash
     xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build
     ```
  6. Search for forbidden UX claims and save output to `.sisyphus/evidence/task-7-copy-guardrail.txt`.

  **Must NOT do**: Do not update App Store metadata, version numbers, changelog, or screenshots in this task. Do not claim guaranteed iPhone delivery in docs.

  **Recommended Agent Profile**:
  - Category: `writing` - Reason: documentation plus verification evidence synthesis.
  - Skills: [`swift-style`] - Keep commands and references consistent with repo style.
  - Omitted: [`document-release`] - This is a small README feature bullet, not a post-release documentation sweep.

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: Final Verification | Blocked By: Tasks 1-6

  **References** (executor has NO interview context - be exhaustive):
  - Docs pattern: `README.md` - existing feature bullets under “Features”.
  - Commands: `AGENTS.md` - canonical build/unit/UI test commands.
  - Guardrail copy: `.sisyphus/plans/send-to-iphone.md` Must NOT Have section.

  **Acceptance Criteria** (agent-executable only):
  - [ ] README contains exactly one new feature bullet for Send to iPhone.
  - [ ] README does not mention `paired iPhone detected`, `same iCloud iPhone found`, CloudKit, or companion app.
  - [ ] Unit-test command passes.
  - [ ] Release build command passes.
  - [ ] Targeted UI smoke either passes or is waived only for a pre-existing failure before new feature assertions.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Final unit and build verification
    Tool: Bash
    Steps: run unit tests and release build commands from this task
    Expected: both commands exit 0
    Evidence: .sisyphus/evidence/task-7-unit-tests.txt and .sisyphus/evidence/task-7-release-build.txt

  Scenario: Documentation copy avoids false detection claims
    Tool: Bash
    Steps: search README.md and Chowser/*.swift for forbidden phrases
    Expected: no forbidden phrase appears in user-facing copy
    Evidence: .sisyphus/evidence/task-7-copy-guardrail.txt
  ```

  **Commit**: YES | Message: `docs(readme): mention iphone link transfer` | Files: `README.md`

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.
- [x] F1. Plan Compliance Audit — oracle
- [x] F2. Code Quality Review — unspecified-high
- [x] F3. Real Manual QA — unspecified-high
- [x] F4. Scope Fidelity Check — deep

## Commit Strategy
- Commit 1: `chore(git): start send-to-iphone branch` only if the executor’s workflow records branch preflight metadata; otherwise no commit for Task 1.
- Commit 2: `test(phone): add handoff service coverage` after Tasks 2-4 pass unit tests.
- Commit 3: `feat(picker): add send to iphone actions` after Tasks 5-6 pass targeted checks.
- Commit 4: `docs(readme): mention iphone link transfer` after Task 7.

## Success Criteria
- User can open Chowser picker for `https://example.com/path?q=1` and invoke “Send to iPhone”.
- The action menu exposes AirDrop, Show QR Code, and Copy URL without claiming paired iPhone detection.
- QR fallback is visible and scannable from the app UI.
- Handoff activity starts for the current URL and invalidates when picker closes.
- Automated tests prove behavior through seams without requiring real Apple devices or system share UI.
