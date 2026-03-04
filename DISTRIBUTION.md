# Chowser — Distribution Guide

Chowser is distributed through two channels:

| Channel | Sandbox | Profiles | Updates | Price |
|---------|---------|----------|---------|-------|
| **Direct Download** (DMG) | No | Full profile support | Sparkle auto-update | Free |
| **Mac App Store** | Yes | No (NSWorkspace only) | App Store updates | ₹500 |

---

## Prerequisites

- macOS with Xcode installed
- **Paid Apple Developer account** ($99/yr) — required for signing, notarization, and App Store
- Developer ID Application certificate (direct download)
- Apple Distribution certificate (App Store)

---

## Channel 1: Direct Download (Signed + Notarized DMG)

Full-featured build with browser profile support, distributed as a signed and notarized DMG via GitHub Releases. Auto-updates via Sparkle.

### Release Flow

```
main branch → git tag v2.12.0 → GitHub Actions → signed DMG → GitHub Release + Sparkle appcast
```

For beta releases:
```
main branch → git tag v2.12.0-beta.1 → GitHub Actions → signed DMG → GitHub Pre-release + beta appcast
```

### Manual Release

```bash
# Standard release
./scripts/release.sh 2.12.0

# Beta release
./scripts/release.sh 2.12.0-beta.1

# With notarization
NOTARIZE=YES APPLE_ID="you@email.com" APPLE_ID_PASSWORD="xxxx" ./scripts/release.sh 2.12.0
```

### Auto-Updates (Sparkle)

Users are automatically notified of new versions every 4 hours. They can also check manually via the menu bar → **Check for Updates…**

Beta users who opt in via Settings → General → **Join Beta Program** receive beta channel updates.

Appcast files:
- Stable: `https://chowser.sreerams.in/appcast.xml`
- Beta: `https://chowser.sreerams.in/appcast-beta.xml`

### Sparkle EdDSA Key Setup (One-Time)

1. Clone Sparkle and build the key generation tool:
   ```bash
   git clone https://github.com/sparkle-project/Sparkle.git /tmp/Sparkle
   cd /tmp/Sparkle && swift build -c release --product generate_keys
   .build/release/generate_keys
   ```
2. Copy the **public key** to `Info.plist` → `SUPublicEDKey`
3. Store the **private key** as GitHub Secret: `SPARKLE_PRIVATE_KEY`
4. Build the signing tool for CI:
   ```bash
   swift build -c release --product sign_update
   cp .build/release/sign_update /path/to/chowser/scripts/sign_update
   ```

### Required GitHub Secrets (Direct Download)

| Secret | Description |
|--------|-------------|
| `APPLE_CERTIFICATE_P12` | Base64-encoded Developer ID Application .p12 certificate |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the .p12 file |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_ID_PASSWORD` | App-specific password ([generate here](https://appleid.apple.com)) |
| `APPLE_TEAM_ID` | `TH2VPAUX6Y` |
| `SPARKLE_PRIVATE_KEY` | Sparkle EdDSA private key for update signing |

---

## Channel 2: Mac App Store

Sandboxed build without browser profile support (uses `NSWorkspace` for all launches). Distributed via App Store Connect with TestFlight for beta testing.

### Release Flow

```
pre-release branch → push → GitHub Actions → App Store Connect → TestFlight
pre-release branch → merge to main → tag → App Store submission
```

### Pricing & Promo Codes

- **Price**: ₹500 (set in App Store Connect → Pricing and Availability)
- **Promo Codes**: Generate up to 100 promo codes per version in App Store Connect → Marketing → Promo Codes
- Promo codes allow free downloads for reviewers, friends, and beta testers

### TestFlight Beta

1. Push to `pre-release` branch — CI automatically builds and uploads to App Store Connect
2. Go to [App Store Connect → TestFlight](https://appstoreconnect.apple.com) to manage beta testers
3. Add internal testers (up to 100) or create public beta links
4. Beta testers install via TestFlight app on macOS

### Required GitHub Secrets (App Store)

| Secret | Description |
|--------|-------------|
| `APPLE_DISTRIBUTION_P12` | Base64-encoded Apple Distribution .p12 certificate |
| `APPLE_DISTRIBUTION_PASSWORD` | Password for the distribution .p12 |
| `MAC_PROVISIONING_PROFILE` | Base64-encoded Mac App Store provisioning profile |
| `APPLE_ID` | Apple ID email |
| `APPLE_ID_PASSWORD` | App-specific password |
| `APPLE_TEAM_ID` | `TH2VPAUX6Y` |

---

## Apple Developer Portal Setup

### 1. Register App ID

Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources):

- **Identifier**: `in.sreerams.Chowser`
- **Platform**: macOS
- **Capabilities**: None required (URL schemes are Info.plist only)

### 2. Create Certificates

- **Developer ID Application** — for direct download signing + notarization
- **Apple Distribution** — for App Store / TestFlight

### 3. App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → My Apps → New App
2. **Bundle ID**: `in.sreerams.Chowser`
3. **Platform**: macOS
4. **Price**: ₹500 (Tier appropriate for Indian market)
5. **Category**: Utilities
6. Fill in app metadata, screenshots, description
7. Set up TestFlight → add internal/external testers

### 4. Export Certificates as .p12

```bash
# From Keychain Access: right-click certificate → Export → .p12
# Then base64 encode for GitHub Secrets:
base64 -i DeveloperIDApplication.p12 | pbcopy
base64 -i AppleDistribution.p12 | pbcopy
```

---

## Conditional Compilation

The two builds share the same codebase. The `APP_STORE` Swift compilation condition controls differences:

| Feature | Direct Download | App Store (`APP_STORE`) |
|---------|----------------|------------------------|
| Browser profiles | `Process` + `/usr/bin/open` | `NSWorkspace.open()` |
| Auto-updates | Sparkle (menu bar + Settings) | App Store managed |
| Sandbox | Disabled | Enabled |
| Entitlements | `Chowser.entitlements` | `ChowserAppStore.entitlements` |

---

## Setting Up as Default Browser

After installing, users should:
1. Open Chowser (it appears in the menu bar)
2. Click the menu bar icon → **Set as Default Browser**
3. Or go to **System Settings → Desktop & Dock → Default Web Browser → Chowser**

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "App is damaged" | Right-click → Open, or `xattr -cr Chowser.app` |
| Not appearing as browser option | Run once, then check System Settings |
| Menu bar icon missing | Check if app is running in Activity Monitor |
| Sparkle update fails | Check `SUFeedURL` in Info.plist and network connectivity |
| App Store rejection | Ensure `APP_STORE` flag is set and sandbox is enabled |
