# Native TestFlight Reactivation Issues

## 2026-06-11 Task: plan-initialization
- Staged `Icon\r` exists and appears likely accidental; verify before removing.
- App Store URL IDs differ between README and docs.
- `DISTRIBUTION.md` claims TestFlight automation that does not appear to exist.
- Sandbox profile discovery and App Store launch behavior are the first release-blocking gates.

## 2026-06-11 Task: T1 baseline release inventory
- Resolved: staged `Icon\r` was a zero-byte accidental artifact and was removed from the index and working tree.
- Resolved: docs site App Store URL constants pointed at stale `id6741527291`; updated to live `id6760034779`.
- Resolved: `DISTRIBUTION.md` no longer claims missing `pre-release` TestFlight automation.
- Still release-blocking for later tasks: sandbox/TestFlight profile discovery and private-mode behavior need runtime validation and fixes outside T1.

## 2026-06-11 Task: T2 exploration synthesis
- Temporary home-relative App Store entitlement exceptions currently mask whether the security-scoped bookmark path actually works.
- `BrowserProfileDetector` cannot distinguish “no profiles” from “no permission”; UI needs a recovery path.
- Existing profile detector covers Chrome/Brave/Edge/Vivaldi/Arc/Dia/Firefox/Zen paths, while docs/launch code mention additional families like LibreWolf/Waterfox/Opera; avoid expanding scope unless needed for stated TestFlight support.

## 2026-06-11 Task: T2 sandbox profile-access implementation
- LSP diagnostics for most Swift files still report project-indexing false positives (`Cannot find type ...`) when run per-file; `xcodebuild` compiled the same files successfully.
- Existing unrelated working-tree changes remain from prior plan/T1/doc work (`DISTRIBUTION.md`, docs files, `.sisyphus/*`, `AGENTS.md`); T2 did not alter `chowser-electrobun/`.

- Transient verification note: running `xcodebuild test` and Release `xcodebuild` concurrently hit Xcode's DerivedData `build.db` lock; rerunning the targeted test sequentially passed.

## 2026-06-11 Task: T3 launch research synthesis
- Existing `BrowserLaunchTests` fail because their URL-in-arguments expectations no longer match `BrowserManager.open(...)` runtime behavior.
- `NSWorkspace.OpenConfiguration.arguments` is ignored for sandboxed callers per Apple docs, making current APP_STORE profile/private launch behavior likely unreliable despite compiling.
- Custom launch argument whitespace splitting can break `{profile}` values such as `Profile 1`.
- Arc/Dia profile discovery/exposure conflicts with onboarding copy saying direct profile switching is unsupported.

## 2026-06-12 Task: T14 release verification
- UI tests were attempted with the required isolated DerivedData command but failed before executing tests: `ChowserUITests` could not read the bundle identifier for `/var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UIDerivedData/Build/Products/Debug/Chowser.app` because that host app path did not exist.
- Manual QA remains pending for MCP curl with UI-visible token, onboarding lifecycle/reset, external-app routing, signed sandbox/TestFlight browser profile access, private/profile browser behavior, settings persistence, Liquid Glass/fallback visual states, and oldest-supported macOS.

## 2026-06-12 Task: T14 UI-test recovery
- `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserUITests -derivedDataPath /var/folders/qr/y7mw06t17dl1yhmxfh0sn_7r0000gn/T/opencode/ChowserT14UIHostDerivedData` failed immediately because `ChowserUITests` is not a member of the `Chowser` scheme or test plan.
- The fallback same-DerivedData flow did build the Debug host app and execute `ChowserUITests`, but the suite failed: 11 tests executed, 11 failures, 0 unexpected. Failures were UI assertions such as `Settings UI did not appear`, `Picker UI should be visible`, and `Add rule button not found`.
- Before the later user waiver, T14 was blocked on UI-test runtime failures, no longer merely the earlier missing-host-app artifact.

## 2026-06-12 Task: T14 scope-change issue update
- Superseded blocker status: UI/E2E tests are still not green, but they are no longer an active release blocker after the user said “do not do e2e anymore”.
- The failed UI-test evidence remains relevant history and should not be deleted or rewritten as a pass.
- Remaining T14 follow-up is human QA and upload readiness under the updated gate set: Release build, unit tests, archive, archive metadata, and manual QA evidence.
