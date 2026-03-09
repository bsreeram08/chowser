
## Browser Profile Detection Research - Current Implementation

**Date**: 2026-02-27
**Task**: Explored BrowserProfileDetector.swift and related files

### Current Implementation Overview

#### File: BrowserProfileDetector.swift
**Location**: `/Users/sreeram/workspace/Sreeram/projects/Chowser/Chowser/BrowserProfileDetector.swift`

The profile detector is an **enum** (not a class) with static methods and a cache:

```swift
enum BrowserProfileDetector {
    private static var profileCache: [String: [BrowserProfile]] = [:]
    
    static func detectProfiles(for bundleId: String) -> [BrowserProfile]
    static func clearCache()
    private static func detectProfilesUncached(for bundleId: String) -> [BrowserProfile]
    private static func detectChromiumProfiles(bundleId: String) -> [BrowserProfile]
    private static func detectFirefoxProfiles(bundleId: String) -> [BrowserProfile]
}
```

#### Profile Structure
```swift
struct BrowserProfile {
    let id: String      // Profile directory name (e.g., "Profile 1", "Default")
    let name: String    // Display name from browser config
}
```

### Chromium-Based Browser Detection

**Supported Bundle IDs** (hard-coded in switch statement, line 36-41):
- `com.google.Chrome` → `Google/Chrome/Local State`
- `com.brave.Browser` → `BraveSoftware/Brave-Browser/Local State`
- `com.microsoft.edgemac` → `Microsoft Edge/Local State`
- `com.vivaldi.Vivaldi` → `Vivaldi/Local State`

**Detection Logic** (line 25-26):
```swift
if bundleId.contains("Chrome") || 
   bundleId == "com.brave.Browser" || 
   bundleId == "com.microsoft.edgemac" || 
   bundleId == "com.vivaldi.Vivaldi"
```

**JSON Path Structure**:
```
~/Library/Application Support/{BrowserName}/Local State
└── profile (object)
    └── info_cache (object)
        ├── "Default" (object)
        │   └── name: "Person 1"
        ├── "Profile 1" (object)
        │   └── name: "Work"
        └── "Profile 2" (object)
            └── name: "Personal"
```

**Parsing** (lines 45-56):
1. Read `Local State` file as JSON
2. Navigate to `json["profile"]["info_cache"]`
3. Each key in `info_cache` is a profile directory name
4. Extract `name` property from each profile object
5. Fallback to directory name if `name` is missing
6. Sort profiles alphabetically by name

### Firefox-Based Browser Detection

**Supported Bundle IDs** (line 27-28, 63):
- `org.mozilla.firefox` → `Firefox/profiles.ini`
- `app.zen-browser.zen` → `Zen/profiles.ini`

**Detection Logic** (line 27-28):
```swift
if bundleId == "org.mozilla.firefox" || 
   bundleId == "app.zen-browser.zen"
```

**INI File Format**:
```ini
[Profile0]
Name=default-release
...

[Profile1]
Name=Work Profile
...
```

**Parsing** (lines 66-81):
1. Read `profiles.ini` as text
2. Split into lines
3. Look for `[Profile*]` section headers
4. Extract `Name=` value from each section
5. Use name as both ID and display name
6. Sort profiles alphabetically by name

### Browser Family Detection (BrowserManager.swift)

**Location**: Lines 612-630 in `BrowserManager.swift`

**Arc is Already Recognized as Chromium**:
```swift
private static func browserFamily(for bundleId: String) -> BrowserFamily {
    if bundleId.localizedCaseInsensitiveContains("Chrome") ||
       bundleId.localizedCaseInsensitiveContains("Brave") ||
       bundleId.localizedCaseInsensitiveContains("Edge") ||
       bundleId.localizedCaseInsensitiveContains("Vivaldi") ||
       bundleId.localizedCaseInsensitiveContains("Arc") ||      // Line 617
       bundleId == "company.thebrowser.Browser" ||             // Line 618
       bundleId.localizedCaseInsensitiveContains("Chromium") ||
       bundleId.localizedCaseInsensitiveContains("Opera") {
        return .chromium
    }
    // ...
}
```

**Arc Bundle ID**: `company.thebrowser.Browser` (confirmed in tests)

### Key Observations

1. **Arc is partially supported**: 
   - Recognized as Chromium-based browser (line 617-618)
   - Tests reference Arc with bundle ID `company.thebrowser.Browser`
   - **BUT**: Not in the profile detection switch statement
   - Profile detection will return empty array for Arc

2. **Detection is browser-family based**:
   - Chromium browsers checked first (contains "Chrome" OR specific IDs)
   - Firefox browsers checked second (exact matches)
   - Unknown browsers return empty array

3. **Path construction pattern**:
   - All paths relative to `~/Library/Application Support/`
   - Chromium: `{BrowserName}/Local State`
   - Firefox: `{BrowserName}/profiles.ini`

4. **Cache management**:
   - Profiles cached by bundle ID
   - `clearCache()` called when Settings window opens
   - Allows picking up newly created profiles

5. **Test coverage**:
   - Tests exist for Brave profile detection
   - Tests verify profile IDs follow Chromium naming ("Profile 1", "Default")
   - Tests check Safari returns empty (no profile support)

### Integration with BrowserManager

**Location**: Line 556 in `BrowserManager.swift`

When discovering installed browsers:
```swift
let profiles = BrowserProfileDetector.detectProfiles(for: bundleId)
if profiles.isEmpty {
    // Add browser without profile
} else if profiles.count == 1 {
    // Add browser with single profile
} else {
    // Add separate entry for each profile: "Chrome - Work", "Chrome - Personal"
}
```

### Missing Pieces for Arc/Dia

**What needs to be researched**:

1. **Arc**:
   - Does Arc use standard Chromium `Local State` format?
   - If yes: Just add case to switch statement
   - If no: What's the actual profile storage format?
   - Where is `~/Library/Application Support/Arc/` structured?

2. **Dia**:
   - Bundle ID unknown
   - Profile storage location unknown
   - Is it Chromium-based, Firefox-based, or custom?

**Next Steps**:
- Inspect actual Arc filesystem structure
- Check if Arc has `Local State` file with standard format
- Find Dia bundle ID and profile structure
- Test if Arc profiles use Chromium directory naming


## Session Update: 2026-02-26 (Evening)

### Dia Browser - RESEARCH COMPLETE

**CONFIRMED via web research:**

1. **Bundle ID**: `company.thebrowser.dia`
2. **Storage Location**: `~/Library/Application Support/Dia/User Data/`
3. **Format**: **Chromium-style** - uses Local State JSON (same as Chrome/Edge)
4. **Profile Structure**:
   - `~/Library/Application Support/Dia/User Data/Local State` (JSON)
   - `~/Library/Application Support/Dia/User Data/Default/`
   - `~/Library/Application Support/Dia/User Data/Profile 1/`

5. **Profile Detection**: Can reuse existing Chromium logic from BrowserProfileDetector
6. **Launch Command**:
   ```bash
   /usr/bin/open -n -a "Dia" --args --profile-directory="Default"
   ```

**Implementation**: Adding Dia support is **TRIVIAL** - just add a case to the switch statement like other Chromium browsers.

### Arc Browser - IN PROGRESS

- Uses "Spaces" concept (not traditional profiles)
- Has AppleScript API for controlling spaces
- There was an `arc-cli` project (archived)
- Need to verify if Arc uses standard Chromium Local State

---

**Updated**: 2026-02-26T21:25:00Z
## Arc Browser Profile Storage Research - COMPLETE (2026-02-27)

### Bundle ID
- **Primary**: `company.thebrowser.Browser`

### Data Locations
```
~/Library/Application Support/Arc/
├── User Data/
│   ├── Local State          # Chromium-style global settings JSON
│   ├── Default/             # Default profile directory
│   ├── Profile 1/           # Additional profile directories
│   └── Profile 2/
└── StorableSidebar.json     # Spaces configuration (tabs, folders, etc.)
```

### Architecture
- **Based on Chromium**: Uses standard Chromium profile structure
- **Local State JSON**: EXISTS - contains browser-wide settings and profile metadata
- **Profile pattern**: "Default", "Profile 1", "Profile 2", etc.

### Spaces vs Profiles - CRITICAL DISTINCTION
**IMPORTANT:**
- **Profiles**: Separate browsing data (cookies, history, extensions, logins) - like Chrome profiles
- **Spaces**: Organize tabs within a profile (pinned/unpinned, themes, icons) - Arc-specific feature
- Profiles can be assigned to Spaces, but they are separate concepts
- One profile can have multiple Spaces

### Space Storage Format
- Primary file: `StorableSidebar.json` at `~/Library/Application Support/Arc/StorableSidebar.json`
- Format: **JSON** (not protobuf)
- Contains: Space IDs, names, tabs (pinned/unpinned), folders, URLs, titles, hierarchy
- Additional storage: 
  - SQLite databases for history/bookmarks
  - IndexedDB at `Profile N/Web storage/76/Indexed DB/indexddb.blob/2/`

### Protobuf Usage
- **NO protobuf for profile detection**
- "StorableArchive" mentioned in community discussions refers to Arc's tab archiving feature
- Most data is JSON and SQLite, not protobuf

### Command-Line Launching - MAJOR LIMITATION
**Arc does NOT support `--profile-directory` flag like Chrome/Edge**

This means:
- ❌ Cannot launch Arc with specific profile from CLI
- ❌ Cannot use `/usr/bin/open -a Arc --args --profile-directory="Profile 1"`
- ✅ Can only launch default profile: `open -n -a Arc`

**Workarounds:**
1. **AppleScript (RECOMMENDED for Space switching)**: Arc has robust AppleScript support
   - Focus Spaces: `tell space "Personal" to focus`
   - Open URLs in Spaces: AppleScript after launch
   - Get Space info: `id`, `title`, `index` properties
   
2. **Air Traffic Control** (built-in): URL routing rules to automatically open URLs in specific Spaces
   - Set in Arc settings
   - Rules match domain/URL patterns

3. **Third-party tools**:
   - `GeorgeSG/arc-cli` (archived Feb 2025, TypeScript, uses AppleScript)
   - `kkoscielniak/arc-applescript-api` (Node.js wrapper for AppleScript)

### Profile Detection Implementation
**For Chowser's BrowserProfileDetector:**
```swift
// Arc profiles follow standard Chromium pattern
// Detection code similar to Chrome/Edge:
let arcUserDataPath = appSupportDirectory.appendingPathComponent("Arc/User Data")
let localStatePath = arcUserDataPath.appendingPathComponent("Local State")

// Profile directories: "Default", "Profile 1", "Profile 2", etc.
// Parse Local State JSON for profile metadata (names, etc.)
```

**IMPORTANT**: While detection works, **launching with specific profile does NOT work**

### AppleScript Integration Details
Arc's AppleScript dictionary (`/Applications/Arc.app`):
- **Space object**: properties `id`, `title`, `index`
- **Tab object**: properties `title`, `id`, `url`, `isLoading`, `location` ("pinned"|"unpinned"|"topApp"), `spaceId`
- **Commands**: 
  - `tell space <name> to focus` - Switch to Space
  - `tell tab <n> to select` - Select tab (pinned tabs are indexed from 1)
  - `make new tab with properties {URL:"..."}` - Open URL
  - Execute JavaScript in current tab

Example AppleScript:
```applescript
tell application "Arc"
    tell front window
        tell space "Personal" to focus
        tell tab 1 to select
    end tell
    activate
end tell
```

### Sandbox Considerations
- Sandboxed apps need user permission for `~/Library/Application Support/`
- Use `NSOpenPanel` for explicit user consent
- Consider security-scoped bookmarks for persistent access across launches

### Recommended Implementation for Chowser

**Phase 1: Basic Arc Support (NO profile support)**
1. **Detection**: Detect Arc by checking if `/Applications/Arc.app` exists
2. **Config**: Add Arc as single browser (no profiles)
3. **Launching**: Use `open -n -a Arc <URL>` - always opens in default profile
4. **Limitation**: Document that Arc profile switching is not supported

**Phase 2: Space Support (Future, requires AppleScript)**
1. Parse `StorableSidebar.json` to discover Spaces
2. Use AppleScript to open URLs in specific Spaces
3. More complex: requires running AppleScript from Swift

**Phase 3: Air Traffic Control (Alternative)**
- Let users configure Arc's built-in Air Traffic Control rules
- Chowser just opens URLs in Arc, Arc handles routing

### Key Takeaways for Implementation
1. ✅ Arc profile detection is straightforward (Chromium pattern)
2. ❌ Arc does NOT support CLI profile launching (unlike Chrome/Edge/Firefox)
3. ✅ Arc has excellent AppleScript support for Space management
4. ⚠️ Profiles ≠ Spaces (many users confuse these)
5. 🎯 **Recommendation**: Add Arc as single browser initially, no profile support
6. 📝 **Document limitation**: "Arc does not support profile selection via command line"

### Comparison with Other Browsers
| Feature | Chrome/Edge | Firefox | Arc |
|---------|-------------|---------|-----|
| Profile detection | ✅ Local State JSON | ✅ profiles.ini | ✅ Local State JSON |
| CLI profile launch | ✅ --profile-directory | ✅ -P profile-name | ❌ NOT SUPPORTED |
| Profile directory pattern | Profile N | xxx.profile-name | Profile N |
| Alternative launch method | N/A | N/A | ✅ AppleScript for Spaces |

### Sources Referenced
- Arc official community forum discussions
- GeorgeSG/arc-cli GitHub (archived)
- kkoscielniak/arc-applescript-api GitHub
- Reddit r/ArcBrowser discussions
- Community automation scripts (joschua.io, etc.)
- Direct research of Arc's file structure

