# Issues — send-to-iphone

## 2026-07-03 Task: planning
- Existing active boulder state pointed at completed `native-testflight-reactivation`; start-work redirected to `send-to-iphone` because the prior active plan was fully checked and user selected Start Work for the new plan.

## 2026-07-03 Task 1 baseline
- Baseline `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests` exited successfully and printed `** TEST SUCCEEDED **`, but the captured output also reports `Executed 0 tests`; later implementation tasks should verify whether the `-only-testing:ChowserTests` selector is expected to discover tests in this scheme.

## 2026-07-03 Task 3 QR generator
- The required QR-only xcodebuild selector initially failed before running QR tests because parallel Task 4 added `ChowserTests/PhoneLinkSystemAdapterTests.swift`, which currently references missing fake adapter types. Task 3 verification passed after rerunning the same QR selector with `EXCLUDED_SOURCE_FILE_NAMES=PhoneLinkSystemAdapterTests.swift`; no adapter/system files were edited.
- `lsp_diagnostics` succeeded for `Chowser/PhoneLinkQRGenerator.swift`; SourceKit still reports `No such module Testing` for Swift Testing files in this environment, so `xcodebuild` remains authoritative.


## 2026-07-03 Task 4 system adapters
- LSP diagnostics are not authoritative in this environment: SourceKit could not resolve the app target from the standalone file (`AppEnvironment` unresolved), Swift Testing was unavailable to LSP, and no plist LSP server is configured. The required xcodebuild selector passed and is the verification source of truth.
- The initial red run failed on concurrently-added QR generator tests before adapter implementation; after Task 4 implementation, the required adapter-only selector passed without modifying QR generator files.
- Forbidden API grep returned false positives from Swift access control/test fake names and existing negative assertion strings only; no device discovery/private-framework implementation was introduced.
