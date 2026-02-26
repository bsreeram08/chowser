# Arc Browser Profile Storage Research - Executive Summary

**Research Date**: February 27, 2026
**Status**: ✅ COMPLETE
**Recommendation**: Add Arc as single browser (no profile support)

---

## Quick Answer to Original Questions

### 1. Arc browser bundle ID
✅ **Answer**: `company.thebrowser.Browser`

### 2. Where Arc stores profile data
✅ **Answer**: `~/Library/Application Support/Arc/User Data/`
- Profiles: `Default/`, `Profile 1/`, `Profile 2/`, etc.
- Sidebar/Spaces: `StorableSidebar.json`

### 3. Does Arc use Chromium-style Local State JSON?
✅ **Answer**: YES - Arc is Chromium-based
- File location: `~/Library/Application Support/Arc/User Data/Local State`
- Format: Standard Chromium JSON structure
- Contains: Browser-wide settings and profile metadata

### 4. What are Arc "Spaces" and how are they stored?
✅ **Answer**: Spaces are tab organization containers (NOT profiles)
- **Profiles**: Separate browsing data (cookies, history, logins)
- **Spaces**: Organize tabs within a profile (themes, pinned tabs, folders)
- Storage: `~/Library/Application Support/Arc/StorableSidebar.json` (JSON format)
- One profile can have multiple Spaces

### 5. Is there protobuf (StorableArchive) format?
❌ **Answer**: NO - Arc primarily uses JSON and SQLite
- "StorableArchive" refers to tab archiving feature (not profile storage)
- No evidence of Protocol Buffers for profile detection

### 6. How to launch Arc with specific Space/profile from command line
❌ **CRITICAL LIMITATION**: Arc does NOT support CLI profile launching

**What DOESN'T work:**
```bash
# These do NOT work with Arc:
open -a Arc --args --profile-directory="Profile 1"  # ❌ NOT SUPPORTED
arc -P "Work Profile"                                # ❌ NOT SUPPORTED
```

**What DOES work:**
```bash
# Only default profile:
open -n -a Arc "https://example.com"  # ✅ Always opens default profile
```

**Workaround for Spaces (not profiles):**
- AppleScript: `tell application "Arc"` → `tell space "Work" to focus`
- Air Traffic Control: Configure URL routing rules in Arc settings

---

## Key Findings

### ✅ What Works
1. **Profile detection**: Standard Chromium pattern (`Default`, `Profile N`)
2. **Bundle ID detection**: Standard macOS app bundle ID
3. **Local State parsing**: Same as Chrome/Edge
4. **Space switching**: AppleScript API available

### ❌ What Doesn't Work
1. **CLI profile launching**: Arc has no `--profile-directory` flag
2. **Direct Space launching**: Must use AppleScript after launch
3. **Stable Space IDs**: Spaces referenced by name (can change)

### ⚠️ Complications
1. **Profiles ≠ Spaces**: Two different concepts, users confuse them
2. **Undocumented formats**: `StorableSidebar.json` not officially documented
3. **AppleScript overhead**: Requires Arc running, adds latency

---

## Recommendation for Chowser

### Phase 1: Basic Arc Support (IMPLEMENT THIS)
**Add Arc as single browser, no profile support**

**Pros:**
- Simple implementation (similar to Safari)
- Honest about limitations
- Arc appears in browser picker
- No false expectations

**Implementation:**
```swift
// Detect Arc at /Applications/Arc.app
// Add as single browser config (no profiles)
// Launch with: open -n -a Arc <URL>
```

**User experience:**
- Arc shows in picker as "Arc Browser"
- No profile selection (profile dropdown N/A for Arc)
- Documentation explains limitation and suggests Air Traffic Control

**Effort**: Low (few hours)
**User value**: Medium (Arc users can use Chowser)
**Risk**: None

### Phase 2: Space Support (FUTURE, IF REQUESTED)
**Use AppleScript to switch Spaces after launch**

**Only implement if users strongly request it**

**Pros:**
- Actually provides Arc-specific routing
- Leverages Arc's unique feature

**Cons:**
- High complexity (JSON parsing + AppleScript)
- Fragile (depends on undocumented format)
- Slow (multi-step launch process)
- Confusing (Spaces vs Profiles)

**Effort**: High (several days)
**User value**: Low-Medium (niche feature)
**Risk**: High (fragile, hard to maintain)

### Phase 3: Air Traffic Control Integration (ALTERNATIVE)
**Document how to use Arc's built-in routing**

**Implementation:**
- Add documentation/help section
- Explain how to configure Arc's Air Traffic Control
- Show example rules for common use cases

**Effort**: Very Low (documentation only)
**User value**: Medium (empowers users)
**Risk**: None

---

## Implementation Code Snippets

### Detect Arc Browser
```swift
private func detectArcBrowser() -> [DetectedProfile] {
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
}
```

### Launch Arc (No Profile)
```swift
case .arc:
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-n", "-a", "Arc", url.absoluteString]
    try task.run()
```

### Detect Profiles (If Needed Later)
```swift
let arcUserDataPath = appSupportDirectory
    .appendingPathComponent("Arc/User Data")

let contents = try FileManager.default
    .contentsOfDirectory(at: arcUserDataPath, 
                         includingPropertiesForKeys: nil, 
                         options: .skipsHiddenFiles)

for item in contents {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: item.path, 
                                     isDirectory: &isDirectory),
       isDirectory.boolValue {
        // Check for "Default" or "Profile N"
        let name = item.lastPathComponent
        if name == "Default" || name.hasPrefix("Profile ") {
            profiles.append(name)
        }
    }
}
```

---

## Documentation for Users

**What to add to README/Help:**

> ### Arc Browser Support
> 
> Arc browser is supported but with limitations due to Arc's architecture.
> 
> **What works:**
> - Arc appears in the browser picker
> - Links open in Arc when selected
> 
> **What doesn't work:**
> - Profile selection (Arc doesn't support profile-specific launching via command line)
> - Links always open in your default Arc profile
> 
> **Alternative: Air Traffic Control**
> 
> To route URLs to specific Arc Spaces or Profiles, use Arc's built-in "Air Traffic Control" feature:
> 
> 1. Open Arc Settings → General → Air Traffic Control
> 2. Add rules like:
>    - `*.github.com` → Open in "Work" Space
>    - `*.youtube.com` → Open in "Personal" Space
> 3. Chowser will route to Arc, Arc will handle Space routing
> 
> This provides more powerful routing than Chowser could implement directly.

---

## Files Created

All research saved to `.sisyphus/notepads/arc-dia-profile-research/`:

1. **learnings.md** - Complete technical research findings
2. **decisions.md** - Implementation decision and rationale
3. **issues.md** - Known issues and limitations (20+ documented)
4. **RESEARCH_SUMMARY.md** - This executive summary

---

## Conclusion

**The Bottom Line:**
- Arc profile detection: ✅ Possible (Chromium pattern)
- Arc profile launching: ❌ Impossible (no CLI support)
- **Recommendation**: Add Arc as single browser, document limitation

**Implementation Priority**: Phase 1 only (basic support)
**Estimated Effort**: 2-4 hours
**User Impact**: Positive (adds Arc support) with clear expectations

**Next Steps:**
1. Add `.arc` case to `BrowserType` enum
2. Implement basic Arc detection (no profiles)
3. Add launch support (no profile args)
4. Update UI to handle browsers without profiles
5. Add documentation explaining limitation

