# Native TestFlight Release Inventory

## 2026-06-11 T1 baseline

### Git state at start

- `.sisyphus/boulder.json` was modified before T1 work started.
- `Icon\r` was staged as a new zero-byte file and matched the known accidental artifact.
- `.sisyphus/drafts/native-testflight-reactivation.md`, `.sisyphus/plans/native-testflight-reactivation.md`, `.sisyphus/notepads/native-testflight-reactivation/`, and `AGENTS.md` were untracked before T1 work started.
- `AGENTS.md` was left untouched as required.

### Public App Store URL check

- Live: `https://apps.apple.com/in/app/chowser/id6760034779` returned the Chowser Mac App Store page.
- Stale: `https://apps.apple.com/in/app/chowser/id6741527291` returned 404.
- README already used the live `id6760034779` URL.
- Docs site code used stale `id6741527291` URLs and was updated to the live ID.

### Xcode release settings

| Setting | Value |
|---------|-------|
| `MARKETING_VERSION` | `3.1.5` |
| `CURRENT_PROJECT_VERSION` | `202603130606` |
| App bundle ID | `in.sreerams.Chowser` |
| Team ID | `TH2VPAUX6Y` |
| App target Debug deployment target | `14.0` |
| `MACOSX_DEPLOYMENT_TARGET` | `14.0` for the app project settings; screenshot test settings also show `26.2` |
| App Store entitlements | `Chowser/ChowserAppStore.entitlements` |
| App Store compilation condition | `$(inherited) APP_STORE` |
| App Store sandbox | `ENABLE_APP_SANDBOX = YES` in Release |
| Direct build entitlements | `Chowser/Chowser.entitlements` |
| Direct build sandbox | `ENABLE_APP_SANDBOX = NO` in Debug |

### App Store entitlements inventory

`Chowser/ChowserAppStore.entitlements` enables:

- App Sandbox
- Network client
- Network server
- User-selected read-write files
- App-scope security-scoped bookmarks
- Temporary read-only home-relative exceptions for Chrome, Brave, Edge, Vivaldi, Arc, Dia, Firefox, and Zen profile folders

### Archive and upload path

```bash
xcodebuild archive -project Chowser.xcodeproj -scheme Chowser -configuration Release \
  -archivePath build/Chowser.xcarchive \
  ENABLE_APP_SANDBOX=YES CODE_SIGN_ENTITLEMENTS=Chowser/ChowserAppStore.entitlements \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APP_STORE'
```

Manual upload path:

1. Open Xcode → Window → Organizer.
2. Select the Chowser archive.
3. Choose **Distribute App** → **App Store Connect** → **Upload**.
4. Manage testers in App Store Connect → TestFlight after processing completes.

### Workflow inventory

- `.github/workflows/ci.yml`: CI builds native macOS and also runs Electrobun jobs, but T1 made no Electrobun edits.
- `.github/workflows/release-macos.yml`: tag-based native DMG release flow, not TestFlight upload.
- `.github/workflows/deploy-docs.yml`: docs site deploy flow.
- No `.github/workflows/` file currently implements `pre-release` branch upload to App Store Connect.

## 2026-06-11 T12 release metadata

### Version metadata

| Setting | Value | Notes |
|---------|-------|-------|
| `MARKETING_VERSION` | `3.1.5` | Unchanged for TestFlight reactivation; no new external version intent found locally. |
| `CURRENT_PROJECT_VERSION` | `202606110001` | Deterministic date-style build number greater than inventory build `202603130606`. |

App Store Connect was not queried from this environment because T12 explicitly avoids App Store Connect automation, API keys, and upload tooling. The selected build number assumes no higher build has already been uploaded outside the repo.

### Release note artifact

- Created `release/TESTFLIGHT_NOTES.md` with TestFlight beta notes and a manual Xcode Organizer upload checklist.
- Notes cover native macOS, browser profile access grants, MCP opt-in token hardening, and selective Liquid Glass on latest macOS.
- Notes do not promise Electrobun, Windows/Linux, browser extensions, URL rewrite scripting, Focus/Shortcuts automation, mail/file handlers, rule history, or rule tester features.
- Checklist uses Xcode > Window > Organizer > Distribute App > App Store Connect > Upload and includes Release build, unit tests, UI tests, and App Store archive commands.


### T12 artifact correction

- Final tracked TestFlight notes/checklist artifact: `TESTFLIGHT_NOTES.md`.
- Removed ignored duplicate `release/TESTFLIGHT_NOTES.md` because `.gitignore` excludes `release/` as generated release output.
- Version metadata remains unchanged: `MARKETING_VERSION` `3.1.5`, `CURRENT_PROJECT_VERSION` `202606110001`.

## 2026-06-11 T13 market-gap backlog

- Tracked backlog artifact: `MARKET_GAP_BACKLOG.md`.
- Scope boundary: native macOS/TestFlight only, no Electrobun/Windows/Linux, no CI upload automation, and no public App Store launch claim.
- Backlog-only market gaps: browser extensions, rule tester/history, tracking stripping, URL rewrites/native app targets, short URL expansion, Focus/Shortcuts, and mail/file handlers.
- Each backlog item is marked Post-TestFlight and out of scope for 3.1.5 TestFlight reactivation.
- Correction: existing `RuleTesterView` and menu-bar Focus Mode are pre-existing native functionality, not T13 implementation scope; the backlog rows now frame future work as history/deeper tester workflows and Shortcuts/deeper Focus integration.

## 2026-06-12 T14 timeout recovery

- Recovery found no `release/*.xcarchive`; `release/` only contained the older `Chowser-3.0.0.dmg` artifact.
- Quick metadata check still reports `MARKETING_VERSION = 3.1.5` and `CURRENT_PROJECT_VERSION = 202606110001`.
- Created root `RELEASE_VERIFICATION.md` as the tracked recovery evidence document with all T14 automated and manual gates marked pending until rerun/observed.
