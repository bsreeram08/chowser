# Chowser Distribution

Chowser has two products built from the same source tree. Their distribution-specific code and dependencies are separated at the Xcode target boundary.

| Product | Scheme | Sandbox | Profiles | Updater |
|---|---|---:|---|---|
| Direct download | `Chowser` | No | Full supported-browser profile launching | Sparkle through GitHub Releases |
| Mac App Store | `Chowser-AppStore` | Yes | `NSWorkspace` launch fallback | Mac App Store / TestFlight only |

## Direct-download product

The direct target defines `DIRECT_DISTRIBUTION`, uses `Chowser.entitlements`, and is the only target that links Sparkle. Its finished app contains:

- `Sparkle.framework`
- stable and opt-in beta update policy
- `Check for Updates…` menu actions
- General Settings controls for automatic checks, automatic downloads, and beta releases
- the signed appcast URL and Sparkle public EdDSA key

### Release track

Releases are explicit and tag-driven:

```text
reviewed version commit on main
  -> v3.10.0 tag
  -> signed/notarized stable GitHub Release
  -> signed default-channel appcast item

reviewed version commit on main
  -> v3.10.0-beta.1 tag
  -> signed/notarized GitHub prerelease
  -> signed beta-channel appcast item
```

A normal push or merge to `main` does not publish a release.

Stable and beta entries share one appcast. Sparkle always considers the default channel; users who enable beta releases additionally allow the `beta` channel. Stable releases therefore bring beta users back to the production line naturally.

### Prepare a release

First add a reviewed `CHANGELOG.md` section for the exact version. Then run:

```bash
SPARKLE_PUBLIC_ED_KEY=<public-key> ./scripts/release.sh 3.10.0

# or
SPARKLE_PUBLIC_ED_KEY=<public-key> ./scripts/release.sh 3.10.0-beta.1
```

The preparation script requires a clean worktree, updates all Xcode marketing/build versions, runs unit tests, builds both products, and verifies their binary boundaries. It does not stage files, commit, tag, push, sign, or publish.

After reviewing and merging the version commit to `main`, create and push only the intended tag:

```bash
git tag -s v3.10.0 -m "Chowser v3.10.0"
git push origin v3.10.0
```

### GitHub release workflow

`.github/workflows/release-macos.yml` fails closed. It will not create a public release unless it can:

1. Validate the tag, committed version/build, and changelog.
2. Confirm every release secret exists.
3. Run unit tests.
4. Build and inspect the App Store product to prove Sparkle is absent.
5. Developer ID-sign and archive the direct product.
6. Notarize and staple both the app and DMG.
7. Verify code signing, Gatekeeper assessment, entitlements, bundle metadata, and Sparkle metadata.
8. Generate the DMG, SHA-256 checksum, reviewed notes, provenance attestation, and signed appcast.
9. Upload every required asset to a draft GitHub Release.
10. Publish only after the draft contains the complete verified asset set.
11. Publish the signed appcast to the `updates` branch after the public DMG is reachable and checksum-identical.

All release and recovery feed writers share one repository-wide concurrency lock, so two tags cannot overwrite each other's appcast history.

Required release assets:

- `Chowser-<version>.dmg`
- `Chowser-<version>.md`
- `SHA256SUMS`

### Required GitHub Environment and secrets

Create a GitHub Environment named `release`. Store these secrets in that environment or at repository level:

| Secret | Purpose |
|---|---|
| `APPLE_CERTIFICATE_P12` | Base64-encoded Developer ID Application certificate |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the `.p12` |
| `APPLE_ID` | Notarization Apple ID |
| `APPLE_ID_PASSWORD` | App-specific password for `notarytool` |
| `APPLE_TEAM_ID` | Apple Developer team ID |
| `SPARKLE_PRIVATE_KEY` | Exported EdDSA private key consumed through stdin by `generate_appcast` |
| `SPARKLE_PUBLIC_ED_KEY` | Matching public key embedded in the direct app |

The private Sparkle key must never be committed. Back it up separately before the first public updater build; every installed updater trusts the matching public key.

### Appcast hosting

The signed feed is published at:

```text
https://raw.githubusercontent.com/bsreeram08/chowser/updates/appcast.xml
```

Each enclosure points to an immutable versioned GitHub Release URL. Stable entries use a one-day phased-rollout interval. Manual checks bypass Sparkle's phased rollout, as expected. Beta entries are unphased.

The feed may later move behind `chowser.sreerams.in`, but the new URL must be shipped in an app update before switching hosting.

## Mac App Store product

The App Store target defines `APP_STORE`, uses `ChowserAppStore.entitlements`, enables the app sandbox, and does not link or embed Sparkle. It has no GitHub feed keys or updater menu actions.

Build or archive it with the dedicated scheme:

```bash
xcodebuild archive \
  -project Chowser.xcodeproj \
  -scheme Chowser-AppStore \
  -configuration Release \
  -archivePath release/Chowser-AppStore.xcarchive
```

Uploads remain manual through Xcode Organizer:

1. Open Xcode -> Window -> Organizer.
2. Select the `Chowser-AppStore` archive.
3. Choose Distribute App -> App Store Connect -> Upload.
4. Use TestFlight for beta distribution.

The public listing is:

<https://apps.apple.com/in/app/chowser/id6760034779>

## Artifact verification

Use the same verifier locally and in CI:

```bash
scripts/verify-distribution-artifact.sh direct /path/to/Chowser.app
scripts/verify-distribution-artifact.sh app-store /path/to/Chowser.app
```

Unsigned local builds may opt out of signature checks only:

```bash
ALLOW_UNSIGNED=1 scripts/verify-distribution-artifact.sh direct /path/to/Chowser.app
```

The direct verifier requires Sparkle, signed-feed metadata, a numeric build number, and no app sandbox. The App Store verifier requires Sparkle and all `SU*` updater metadata to be absent, rejects updater helpers and implementation markers, and requires a signed bundle with the app sandbox. Release verification also enforces universal architecture, hardened runtime, and Developer ID authority where applicable.

## Recovery and rollback

Published assets and tags are never replaced.

- **Release published, feed update failed:** rerun feed publication for the existing verified release; users remain on the previous feed until it succeeds.
- **Bad release not yet in the feed:** leave or remove the release as policy allows, but do not publish its appcast entry.
- **Bad release already offered:** remove the bad feed item if necessary, then publish a corrected version with a higher numeric build.
- **Lost Sparkle key:** stop publishing updates and follow Sparkle's Developer ID-backed key-rotation procedure before issuing another feed.
- **Notarization outage:** leave the release unpublished and retry later; never fall back to an unsigned or unstapled DMG.

Rollback is always roll-forward. Sparkle orders updates by `CFBundleVersion`, so a correction must have a higher numeric build even when the marketing version is unchanged.
