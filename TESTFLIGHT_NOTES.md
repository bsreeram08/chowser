# TestFlight Notes for Chowser 3.9.3 (Build 202607061600)

## Beta notes

This build covers everything shipped since 3.9.0: Advanced Routing (fallback, multi-source rules, URL rewrites), network privacy defaults, App Mode, a much larger MCP API surface for AI-driven configuration, a predefined rewrite-rule catalog, a Handoff fix, and a privacy fix to diagnostic logging/bug reports.

What to test:

- **Fallback routing** (Settings → Behavior): set a fallback browser/profile, then open a link that matches no routing rule — it should open directly instead of showing the picker. Existing installs should default to picker-first (no fallback) until you turn it on.
- **Multi-source routing rules**: create a rule matching several source apps (e.g. Slack + Mail). If you had rules before updating, check the one-time merge-review prompt offering to combine duplicate rules that only differed by source app.
- **URL rewrites** (Settings → Rewrites): create a rewrite (strip a tracking param, force HTTPS, replace a host), use the live tester to confirm the before/after trace, then open a matching link and confirm the rewritten URL is what actually opens.
- **Predefined rewrite catalog**: Settings → Rewrites → menu → "Check for Predefined Rewrites…" should fetch and offer to add the starter set (HTTPS upgrade, UTM/fbclid/gclid/msclkid/ttclid stripping). This was broken in 3.9.1 (decode failure on every check) — confirm it now works.
- **Network privacy defaults**: on a fresh install or upgrade, shortlink resolution and link-preview fetches should be off by default, with a one-time notice explaining the change. Turn them back on in Settings → Behavior and confirm previews/unshortening resume.
- **Picker URL editing**: in the picker, edit the shown URL before choosing a browser — confirm the edited URL is what opens.
- **App Mode** (Settings → General, or during onboarding for fresh installs): switch between App (Dock icon) and Menu Bar (no Dock icon) — confirm activation policy actually changes and picking a mode sticks across relaunch. Existing installs upgrading from before 3.9.0 should see a one-time prompt asking which mode they want.
- **Handoff**: open the "Send to Phone" menu on a link with a nearby paired Apple device signed into the same iCloud account — the Handoff icon should appear on the other device. This was silently unreliable before 3.9.3's activation-timing fix.
- **MCP local API** (Settings → General → Local API Server): confirm it's off by default, token-protected, and localhost-only. With it running, `GET /settings` should return the full settings surface (App Mode, fallback policy, network privacy, launch-at-login, hidden apps, picker appearance) and `POST /settings` should actually change them in the running app. Also test `open "chowser://mcp/start"` / `open "chowser://mcp/stop"` from Terminal — the server should start/stop without opening Settings, and `~/Library/Application Support/Chowser/mcp-session.json` should appear/disappear with it.
- **Bug reports** (Settings → General → About → Report a Bug): generate a report and confirm the log contains routing/launch events (rule name, destination browser) but never a visited hostname or local file path.
- **Link previews with network lookups off** (the default): the picker should now explain why no preview shows and point to Settings → Behavior, instead of showing nothing.

Out of scope for this beta:

- Electrobun, Windows, and Linux builds.
- Public App Store release readiness beyond this TestFlight round — this build is for beta testing and manual QA.

## Manual Xcode Organizer upload checklist

Do not use CI upload automation, Fastlane, altool, notarytool, or App Store Connect API keys for this flow. Upload from Xcode Organizer only after the local checks pass.

### 1. Confirm release metadata

- Marketing version: `3.9.3`
- Build number: `202607061600`
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

- Confirm the uploaded build number is `202607061600` and the version is `3.9.3`.
- Paste the beta notes above into TestFlight's "What to Test" field.
