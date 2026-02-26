# Arc and Dia Browser Profile Research

## Status
Research in progress — findings based on file system inspection and community documentation.
Neither browser is currently supported for profile detection in `BrowserProfileDetector.swift`.

---

## Arc Browser

**Bundle ID:** `company.thebrowser.Browser`

### Profile / Space Storage

Arc does **not** use Chromium's standard `Local State` + `profile_info_cache` structure.
Arc stores its UI state (Spaces, profiles, pinned tabs) in a proprietary format:

- `~/Library/Application Support/Arc/StorableSidebar.json` — primary spaces/sidebar data
- `~/Library/Application Support/Arc/` — additional Arc-specific state files

Arc "Spaces" are conceptually similar to browser profiles but are stored differently.
The `info_cache` key that Chromium, Brave, Edge, and Vivaldi use does **not** exist in Arc's data.

### Launch Arguments

Arc does accept `--profile-directory=<Name>` when launched via the command line, but:
- The profile directory names differ from Chromium's `Profile 1`, `Profile 2` naming scheme.
- The correct directory name for an Arc Space needs to be discovered from `StorableSidebar.json`
  or by inspecting the profile directories under `~/Library/Application Support/Arc/`.

**Recommended `open` command to target a specific Arc Space:**
```bash
open -n -a "Arc" --args --profile-directory="<SpaceProfileDir>" "https://example.com"
```

### Recommended Changes to BrowserProfileDetector.swift

1. Add an `arc` case to `detectProfilesUncached(for:)` checking for `company.thebrowser.Browser`.
2. Parse `StorableSidebar.json` — extract space names and their corresponding profile directory names.
3. Key fields to look for in `StorableSidebar.json`:
   - `sidebarSyncState` or `spaces` array with `title` and `id` fields.

### Recommended Changes to BrowserManager.launchInfo()

The existing `isChromium` check already includes `bundleId == "company.thebrowser.Browser"`,
so the `--profile-directory=<profile>` argument path is already used. Once
`BrowserProfileDetector` correctly extracts the profile directory names from Arc's data,
no changes to `launchInfo()` are needed.

---

## Dia Browser

**Bundle ID:** Unknown — needs discovery on a machine with Dia installed.

### Discovery Method

```swift
let diaURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "<bundleId>")
// Or search via:
let candidates = NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!)
// Filter for apps named "Dia"
```

Alternatively, on a machine with Dia installed:
```bash
mdls -name kMDItemCFBundleIdentifier /Applications/Dia.app
```

### Architecture

Dia is built on the same engine as Arc (The Browser Company). Its profile/space structure
is expected to be similar or identical to Arc's `StorableSidebar.json` pattern.

### Research Path

1. Install Dia and inspect `~/Library/Application Support/Dia/` (or similar path).
2. Confirm whether it uses `StorableSidebar.json` or a newer format.
3. Check Dia's launch arguments — Arc's `--profile-directory` flag may apply directly.

---

## Recommended Implementation Order

1. **Arc (short-term):** Parse `StorableSidebar.json` to extract Space names and directory IDs.
   Add `detectArcSpaces(bundleId:)` to `BrowserProfileDetector` and wire it into `detectProfilesUncached`.

2. **Dia (after Arc):** Once Arc support is working, adapt the same logic for Dia
   once its bundle ID and profile storage path are confirmed.

---

## References

- Arc source (not public) — inspect file system only.
- Community findings: https://github.com/nickcoutsos/dotfiles/discussions (Arc profile directories)
- Arc CLI discussion: https://www.reddit.com/r/ArcBrowser/
