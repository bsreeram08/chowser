# Arc Browser - Quick Reference Card

**Last Updated**: Feb 27, 2026

---

## TL;DR
- ✅ Arc profile **detection**: YES (Chromium pattern)
- ❌ Arc profile **launching**: NO (no CLI support)
- 🎯 **Recommendation**: Add Arc as single browser, no profiles

---

## Essential Facts

| Question | Answer |
|----------|--------|
| Bundle ID | `company.thebrowser.Browser` |
| Profile location | `~/Library/Application Support/Arc/User Data/` |
| Profile pattern | `Default`, `Profile 1`, `Profile 2` |
| Local State JSON | ✅ Yes (Chromium-based) |
| CLI profile launch | ❌ NO - not supported |
| Alternative | AppleScript for Spaces (NOT profiles) |

---

## File Locations

```
~/Library/Application Support/Arc/
├── User Data/
│   ├── Local State              ← Browser settings JSON
│   ├── Default/                 ← Default profile
│   ├── Profile 1/               ← Additional profiles
│   └── Profile 2/
└── StorableSidebar.json         ← Spaces data (JSON)
```

---

## Profiles vs Spaces

| Feature | Profiles | Spaces |
|---------|----------|--------|
| What | Separate browsing data | Tab organization |
| Similar to | Chrome profiles | Browser tabs/windows |
| Data isolation | Full (cookies, history, etc.) | None (within profile) |
| CLI launch support | ❌ NO | ❌ NO (AppleScript only) |
| Multiple per browser | Yes | Yes (many per profile) |

**Key**: One profile can have multiple Spaces.

---

## Implementation Checklist

### ✅ Phase 1: Basic Support (RECOMMENDED)
- [ ] Add `arc` case to `BrowserType` enum
- [ ] Detect `/Applications/Arc.app` existence
- [ ] Return single DetectedProfile (no profile name)
- [ ] Launch with: `open -n -a Arc <URL>`
- [ ] Update UI: handle browsers without profiles
- [ ] Add documentation about limitation
- [ ] Test: launches in default profile

**Effort**: 2-4 hours | **Value**: Medium | **Risk**: None

### ⏸️ Phase 2: Space Support (OPTIONAL)
- [ ] Parse `StorableSidebar.json` for Spaces
- [ ] Execute AppleScript to switch Spaces
- [ ] Handle Space rename/delete edge cases
- [ ] Add Space UI (separate from profiles?)
- [ ] Test multi-Space scenarios
- [ ] Document Spaces vs Profiles confusion

**Effort**: 2-3 days | **Value**: Low-Medium | **Risk**: High

**⚠️ Only implement if users request it**

---

## Code Snippets

### Detect Arc (Phase 1)
```swift
let arcPath = "/Applications/Arc.app"
guard FileManager.default.fileExists(atPath: arcPath) else {
    return []
}
return [DetectedProfile(
    browserType: .arc,
    name: "Arc Browser",
    profilePath: arcPath,
    profileName: nil,
    isDefault: true
)]
```

### Launch Arc (Phase 1)
```swift
case .arc:
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-n", "-a", "Arc", url.absoluteString]
    try task.run()
```

### Switch Space via AppleScript (Phase 2)
```applescript
tell application "Arc"
    tell front window
        tell space "Work" to focus
    end tell
    activate
end tell
```

---

## What Doesn't Work

```bash
# ❌ These DO NOT work with Arc:
open -a Arc --args --profile-directory="Profile 1"
arc --profile-directory="Work"
/usr/bin/open -n -a Arc --args --profile-directory="Profile 1"
```

**Reason**: Arc doesn't implement these flags.

---

## Comparison with Other Browsers

|  | Chrome/Edge | Firefox | Arc |
|--|-------------|---------|-----|
| Profile CLI launch | ✅ `--profile-directory` | ✅ `-P profile-name` | ❌ Not supported |
| Profile detection | ✅ Local State JSON | ✅ profiles.ini | ✅ Local State JSON |
| Alternative | N/A | N/A | AppleScript (Spaces) |

---

## User-Facing Documentation

**Add to README**:

> **Arc Browser Note**: Arc is supported but cannot launch with specific profiles due to Arc's architecture. Links always open in your default Arc profile. For Space-specific routing, configure Arc's "Air Traffic Control" feature in Settings → General.

---

## Decision Summary

**Question**: Should we support Arc browser profile detection/launching?

**Answer**: 
- ✅ **YES to detection** - Arc exists, users have it
- ❌ **NO to profile launching** - technically impossible
- 🎯 **Add as single browser** - like Safari (no profiles)
- 📝 **Document limitation** - set correct expectations

**Rationale**: Better to support Arc without profiles than not support Arc at all. Users can use Air Traffic Control for routing.

---

## Resources

- **Full research**: See `learnings.md` (366 lines)
- **Implementation decision**: See `decisions.md` (155 lines)
- **Known issues**: See `issues.md` (152 lines, 20 issues documented)
- **Executive summary**: See `RESEARCH_SUMMARY.md` (252 lines)

---

## Quick Wins

1. **5 minutes**: Add Arc as single browser (no profiles)
2. **30 minutes**: Test Arc launching in Chowser
3. **1 hour**: Document Arc limitation in UI/README
4. **Done**: Ship Arc support with clear expectations

---

**Status**: ✅ Research complete, ready to implement Phase 1

