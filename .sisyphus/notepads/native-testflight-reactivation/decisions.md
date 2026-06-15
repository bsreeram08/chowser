# Native TestFlight Reactivation Decisions

## 2026-06-11 Task: plan-initialization
- Work directly in current repo unless user later requests a worktree.
- Ignore stale Boulder state for `chowser-electrobun-release`; new active plan is `native-testflight-reactivation`.
- Use tests-after plus agent QA.

## 2026-06-11 Task: T1 baseline release inventory
- Treat `https://apps.apple.com/in/app/chowser/id6760034779` as the canonical public App Store URL because it resolves publicly to Chowser and the alternate ID returns 404.
- Keep TestFlight deployment manual for this task and document the Xcode Organizer path rather than adding CI automation.
- Remove the staged zero-byte `Icon\r` artifact because it is unrelated release noise and safe to delete.

## 2026-06-11 Task: T2 exploration synthesis
- Implement T2 with one explicit Application Support grant first, because it matches existing detector path layout and avoids per-browser grant complexity.
- Prefer read-only app-scoped security-scoped bookmarks; do not request Full Disk Access.
- Do not rely on temporary exception entitlements as proof of sandbox profile support.

## 2026-06-11 Task: T3 launch architecture
- Keep `#if APP_STORE` behavior isolated to launch execution/lowering, not mixed into browser argument policy.
- Prefer an explicit, testable representation of whether profile/private arguments are supported for each launch mode over silently pretending sandboxed App Store arguments are reliable.
- Do not expand browser support beyond existing native browser families during T3; focus on reliability and honest behavior for current Chrome-family and Firefox-family paths.

## 2026-06-12 Task: T14 UI/E2E release-scope decision
- User decision recorded exactly: “do not do e2e anymore”.
- Do not run or fix UI/E2E tests for this release continuation.
- Treat UI/E2E as waived/skipped by explicit user instruction, not passed. T14/F4 reviewers should rely on Release build, unit tests, App Store/TestFlight archive, archive metadata, and remaining human QA/upload evidence.
- Preserve prior failed UI-test evidence: the direct `ChowserUITests` attempt missed the host app, and the two-step host flow executed 11 tests with 11 UI assertion failures.
- Cleanup: restored `ChowserUITests/ChowserUITests.swift` to remove aborted E2E/UI-test recovery edits; UI/E2E remains waived/skipped per user instruction.
