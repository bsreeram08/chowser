# TestFlight Notes for Chowser 3.1.5 (Build 202606110001)

## Beta notes

This TestFlight build reactivates Chowser as a native macOS menu-bar app. It focuses on reliability, safer local automation, and current macOS visuals without expanding into the post-TestFlight backlog.

What to test:

- Native macOS link routing from other apps into Chowser, including picker fallback and saved routing rules.
- Browser profile discovery after granting access to browser profile folders from the app UI. Profile access grants should be recoverable if permission is missing, reset, or revoked.
- App Store and TestFlight profile/private launch behavior should stay honest: browser selection and URL delivery are supported, but sandboxed builds do not promise delivery of profile, private, or custom launch arguments when macOS ignores those arguments.
- MCP local API remains opt-in, localhost-only, and token-protected. Test with the API disabled by default, then enable it intentionally and use the visible token.
- Liquid Glass polish appears only on selected custom picker/card/chip surfaces on the latest macOS, with readable fallbacks on macOS 14+ and with Reduce Transparency enabled.

Out of scope for this beta:

- Electrobun, Windows, and Linux builds.
- Browser extensions, URL rewrite scripting, Focus/Shortcuts automation, mail/file handlers, rule history, and rule tester flows.
- Public App Store release readiness. This build is for TestFlight reactivation and manual QA.

## Manual Xcode Organizer upload checklist

Do not use CI upload automation, Fastlane, altool, notarytool, or App Store Connect API keys for this T12 flow. Upload from Xcode Organizer only after the local checks pass.

### 1. Confirm release metadata

- Marketing version: `3.1.5`
- Build number: `202606110001`
- Bundle ID: `in.sreerams.Chowser`
- Team ID: `TH2VPAUX6Y`
- App Store entitlements: `Chowser/ChowserAppStore.entitlements`
- App Store compilation condition: `APP_STORE`

### 2. Run pre-upload commands

Release build:

```bash
xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build
```

Unit tests:

```bash
xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests
```

UI/E2E tests:

Skipped for this release continuation by user instruction: “do not do e2e anymore”. Do not run UI/E2E tests before upload for this flow, and do not represent them as passing. The historical failed UI-test attempts and waiver are recorded in `RELEASE_VERIFICATION.md`.

App Store/TestFlight archive:

```bash
xcodebuild archive -project Chowser.xcodeproj -scheme Chowser -configuration Release \
  ENABLE_APP_SANDBOX=YES CODE_SIGN_ENTITLEMENTS=Chowser/ChowserAppStore.entitlements \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APP_STORE' \
  -archivePath release/Chowser.xcarchive
```

### 3. Upload manually from Xcode

1. Open Xcode.
2. Choose Window > Organizer.
3. Select the Chowser archive.
4. Choose Distribute App > App Store Connect > Upload.
5. Wait for App Store Connect processing.
6. Add internal testers or beta groups in App Store Connect > TestFlight after processing completes.

### 4. Final human sanity check

- Confirm the uploaded build number is `202606110001` and the version is `3.1.5`.
- Paste the beta notes above into TestFlight.
- Keep public App Store release messaging disabled until T14 manual QA evidence is complete.
