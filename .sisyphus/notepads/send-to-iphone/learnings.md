# Learnings — send-to-iphone

## 2026-07-03 Task: planning
- Clicked URL and clipboard URL flows converge through `BrowserManager.currentURL` and `ContentView` picker rendering.
- Best picker insertion point is `ContentView.urlBubble(url:)` near existing URL mini-actions.
- Public APIs cannot reliably detect a same-iCloud paired iPhone. UX must not claim paired-device detection.
- Recommended public mechanisms: AirDrop via `NSSharingService.Name.sendViaAirDrop`, QR via `CIQRCodeGenerator`, Copy URL, best-effort Handoff via `NSUserActivity.webpageURL`.
- Unit tests are strong; UI tests exist but are historically unstable, so targeted UI smoke can be waived only for pre-existing failures before new feature assertions.

## 2026-07-03 Task 1 baseline
- Created and checked out `feature/send-to-iphone` before any source edits.
- Captured pre-branch git status in `.sisyphus/evidence/task-1-branch-status.txt` and active branch in `.sisyphus/evidence/task-1-branch-current.txt`.
- Baseline command `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests` completed with `** TEST SUCCEEDED **`; full output saved in `.sisyphus/evidence/task-1-baseline-unit-tests.txt`.

## 2026-07-03 Task 2 transfer service seam
- `PhoneLinkTransferManager` is a pure decision seam: HTTP(S) URLs expose only `airDrop`, `showQRCode`, and `copyURL`; Handoff stays represented by status/copy for later lifecycle wiring.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` for `Chowser` and `ChowserTests`; new Swift files are included by folder sync rather than explicit per-file source build entries. The targeted build compiled both new files successfully.

## 2026-07-03 Task 3 QR generator
- `PhoneLinkQRGenerator` mirrors Task 2 transfer URL validity: only `http`/`https` URLs with non-empty hosts are QR-eligible.
- QR payloads use `Data(url.absoluteString.utf8)` directly; the generator does not rewrite, normalize, strip, unshorten, or otherwise mutate URL strings.
- The Xcode project uses synchronized root groups (`PBXFileSystemSynchronizedRootGroup`), so new `Chowser/` and `ChowserTests/` Swift files compiled without pbxproj edits.


## 2026-07-03 Task 4 system adapters
- Added `PhoneLinkSystemAdapters.swift` as the system seam for AirDrop, Copy URL, and Handoff so future UI wiring can depend on protocols instead of direct AppKit/Foundation calls.
- AirDrop uses the public `NSSharingService(named: .sendViaAirDrop)` API with `canPerform(withItems: [url as NSURL])` for capability and `perform(withItems: [url as NSURL])` for live invocation.
- `AppEnvironment.shouldDisableExternalURLOpen` is checked before resolving/invoking AirDrop sharing during transfer, returning `.skippedForUITesting` so automated tests do not open real system UI.
- Copy URL production writes exactly `url.absoluteString` to `NSPasteboard.general`; tests verify this through an in-memory fake.
- Handoff uses custom activity type `in.sreerams.Chowser.phone-link`, sets `webpageURL`, marks `isEligibleForHandoff`, calls `becomeCurrent()` on start/update, and `invalidate()` on stop.
- Added `NSUserActivityTypes` to `Chowser/Info.plist` because the chosen Handoff activity type is Chowser-specific and should be declared by the app.
