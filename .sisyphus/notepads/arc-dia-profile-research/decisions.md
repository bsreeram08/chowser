## Arc Browser Integration Decision (2026-02-27)

### Research Conclusion
After extensive research into Arc browser's profile system, architecture, and CLI capabilities, here are the key findings:

### The Problem
**Arc browser does NOT support profile-specific launching via command line.**
- No `--profile-directory` flag support (unlike Chrome/Edge)
- No `-P profile-name` support (unlike Firefox)
- `open -n -a Arc` always launches default profile only

### Why This Matters for Chowser
Chowser's core feature is browser profile routing - opening links in specific browser profiles. Arc's limitation means we cannot:
1. Launch Arc with a specific profile from the command line
2. Use the same mechanism we use for Chrome, Edge, Firefox profile switching
3. Offer Arc profile selection in the browser picker

### What Arc DOES Support
1. **Profile detection**: Standard Chromium Local State JSON format
2. **Space switching**: Robust AppleScript API for switching between Spaces
3. **Air Traffic Control**: Built-in URL routing rules (configured in Arc settings)

### Important: Profiles ≠ Spaces
- **Profiles**: Separate browsing data (like Chrome profiles)
- **Spaces**: Tab organization within a profile (Arc-specific feature)
- Users often confuse these - Arc's UI emphasizes Spaces over Profiles

### Implementation Options

#### Option 1: No Arc Support (Simplest)
- Don't add Arc to supported browsers list
- Let macOS handle Arc as system default browser
- **Pros**: No work, no false expectations
- **Cons**: Users with Arc can't route links through Chowser picker

#### Option 2: Single Arc Browser (No Profiles) - RECOMMENDED
- Detect Arc at `/Applications/Arc.app`
- Add as single browser config (no profile detection)
- Launch with: `open -n -a Arc <URL>`
- **Pros**: 
  - Arc appears in picker
  - Users can select Arc as destination
  - Honest about limitations
- **Cons**: 
  - No profile support (but Arc doesn't support it anyway)
  - Users might expect profile selection

#### Option 3: Detect Profiles But Can't Launch Them
- Detect profiles from `~/Library/Application Support/Arc/User Data/`
- Show in UI with disclaimer: "Arc doesn't support profile switching"
- Always launch default profile regardless of selection
- **Pros**: User sees profiles exist
- **Cons**: 
  - Confusing UX (shows profiles but can't use them)
  - Misleading - looks like it should work

#### Option 4: Space Support via AppleScript (Complex)
- Parse `StorableSidebar.json` for Spaces
- Use AppleScript to switch Spaces after launch
- Requires running AppleScript from Swift
- **Pros**: Actually provides Space switching
- **Cons**: 
  - Complex implementation
  - Spaces ≠ Profiles (different concept)
  - Requires parsing JSON and AppleScript execution
  - May be fragile (StorableSidebar.json is undocumented)

#### Option 5: Document Air Traffic Control (Hybrid)
- Add Arc as single browser
- In documentation/UI, recommend using Arc's Air Traffic Control
- Let Arc handle routing based on URL patterns
- **Pros**: 
  - Simple Chowser implementation
  - Leverages Arc's built-in feature
  - Users can set up powerful routing rules
- **Cons**: 
  - Routing happens in Arc, not Chowser
  - Less centralized control

### RECOMMENDATION: Option 2 (Single Arc Browser)

**Rationale:**
1. **Technical reality**: Arc doesn't support CLI profile launching
2. **User expectation**: Better to be honest about limitation than show non-functional UI
3. **Simplicity**: Same detection pattern as other browsers, just skip profile enumeration
4. **Future-proof**: If Arc adds CLI profile support, easy to add profile detection later
5. **Useful**: Users can still select Arc in picker, just without profile granularity

### Implementation Plan

**BrowserProfileDetector.swift changes:**
```swift
// Add Arc detection similar to Chrome/Edge
private func detectArcProfiles() -> [DetectedProfile] {
    let arcPath = "/Applications/Arc.app"
    guard FileManager.default.fileExists(atPath: arcPath) else {
        return []
    }
    
    // Return single profile - Arc doesn't support profile-specific launching
    return [DetectedProfile(
        browserType: .arc,
        name: "Arc Browser",
        profilePath: arcPath,
        profileName: nil,  // No profile name since we can't switch
        isDefault: true
    )]
}
```

**BrowserConfig.swift changes:**
```swift
enum BrowserType: String, Codable {
    case chrome = "Chrome"
    case firefox = "Firefox"
    case edge = "Edge"
    case arc = "Arc"  // ADD THIS
    case safari = "Safari"
    case custom = "Custom"
}
```

**BrowserManager.swift changes:**
```swift
// Launch Arc (no profile support)
case .arc:
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-n", "-a", "Arc", url.absoluteString]
    try task.run()
```

**UI considerations:**
- Arc appears in detected browsers list
- Shows as "Arc Browser" (no profile suffix)
- If user tries to add multiple Arc "profiles", show warning: "Arc does not support profile-specific launching"

### Documentation Notes
Add to README/docs:
> **Arc Browser Support**: Arc browser is supported but does not allow profile selection. Links will always open in your default Arc profile. To route URLs to specific Arc Spaces, configure Arc's built-in "Air Traffic Control" feature in Arc Settings → General → Air Traffic Control.

### Future Enhancements (Phase 2)
If there's strong user demand:
1. Implement Space detection via `StorableSidebar.json`
2. Add AppleScript execution to switch Spaces
3. Show Spaces as pseudo-profiles in UI
4. Launch URL → Switch Space via AppleScript → Open URL

**Complexity assessment**: Medium-High
**User value**: Medium (Spaces are Arc-specific concept, not familiar to most)
**Risk**: High (depends on undocumented internal format)

### Conclusion
Add Arc as a single browser option without profile support. This provides value (Arc in picker) without making impossible promises (profile switching). Document the limitation clearly. Consider Space support as future enhancement if users request it.

