# Verification Evidence

**Baseline:** `70ea7855187a51c33a8c214ee1581ab7f05589e3`  
**Branch:** `work/catalog-trust-native-routing`  
**Date:** 2026-08-26

## Static evidence

- Coordinator inspected current source slices for incoming routing, shortlink resolution, recent-history persistence, native matching, MCP request framing, configuration mutation, and launch behavior.
- Two independent technical-review lanes and one test-review lane inspected the repository read-only.
- Coordinator cross-checked the priority findings against current `file:line` evidence before recording them.

## Executed evidence reported by review lanes

| Check | Reported outcome | Coordinator status |
|---|---|---|
| Direct unit tests (`ChowserTests`) | 309 tests in 19 suites passed | **Verified by fresh Coordinator run** |
| Direct Debug build | Passed with signing disabled | Advisory until rerun or build log retained |
| App Store Debug build | Passed with signing disabled | Advisory until rerun or build log retained |
| Committed rewrite catalog signature | Verified | Advisory until rerun |
| Committed native directory signature | Verified | Advisory until rerun |
| UI tests | Runner killed before establishing connection | Not verified |

## Reproducible commands

```bash
xcodebuild test -project Chowser.xcodeproj -scheme Chowser-osp \
  -destination 'platform=macOS' -only-testing:ChowserTests CODE_SIGNING_ALLOWED=NO

xcodebuild build -project Chowser.xcodeproj -scheme Chowser-osp \
  -configuration Debug CODE_SIGNING_ALLOWED=NO

xcodebuild build -project Chowser.xcodeproj -scheme Chowser-appstore \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Catalog verification commands are defined in `.github/workflows/deploy-docs.yml` and should remain the source of truth.

## Fresh Coordinator result

The unit command completed with exit code `0` on 2026-08-26:

- **309 tests in 19 suites passed** in 14.126 seconds.
- `xcodebuild` reported `** TEST SUCCEEDED **`.
- Result bundle: `~/Library/Developer/Xcode/DerivedData/Chowser-beahajwjvizoovalnuskecignryj/Logs/Test/Test-Chowser-osp-2026.08.26_12-25-34-+0530.xcresult`.
- Expected loopback connection-refused diagnostics occurred in the test that verifies a stopped MCP server refuses connections; the test passed.

## Remaining verification

- Focused catalog signature verification from the workflow commands.
- UI runner crash diagnosis before using UI tests as release evidence.
- Deterministic tests for overlapping incoming requests, invalid shortlink schemes, private history, and MCP framing limits.
- Signed Release/archive, notarization, and real LaunchServices checks remain outside this review.

<!-- Last verified: 2026-08-26 against commit 70ea785 -->
