## Arc Browser Integration - Known Issues and Limitations

### Primary Limitation: No CLI Profile Support
**Issue**: Arc browser does not support launching with a specific profile via command line
**Impact**: Cannot implement profile routing for Arc (core Chowser feature)
**Status**: Permanent limitation (Arc design decision)
**Workaround**: None for profiles. AppleScript can switch Spaces (different concept)

### Detection Challenges

#### Issue 1: Profiles vs Spaces Confusion
**Problem**: Arc users think of "Spaces" but Arc actually has "Profiles" too
**Impact**: User confusion - what should Chowser show?
**Example**: User has Profile "Work" with Spaces ["Email", "Documents", "Slack"]
**Resolution**: Only show browser-level (no profiles), document Space routing via Air Traffic Control

#### Issue 2: StorableSidebar.json is Undocumented
**Problem**: Space data is in undocumented JSON format
**Impact**: Any Space detection would be fragile, could break with Arc updates
**Risk**: High
**Mitigation**: Don't parse it for now, wait for official API

#### Issue 3: Local State JSON Exists But Can't Be Used
**Problem**: Arc has Chromium-style Local State JSON with profile info
**Impact**: We can detect profiles but can't launch them (confusing)
**Resolution**: Detect Arc presence, ignore profiles

### AppleScript Alternative Issues

#### Issue 4: AppleScript Requires Arc to Be Running
**Problem**: AppleScript `tell application "Arc"` requires Arc to already be running
**Workflow**: Launch Arc → Wait → Run AppleScript → Switch Space → Open URL
**Impact**: Slow, multi-step process. Not seamless like other browsers
**User experience**: Poor compared to Chrome/Firefox profile launching

#### Issue 5: AppleScript Security/Sandbox Concerns
**Problem**: Running AppleScript from sandboxed app has restrictions
**Impact**: May require entitlements or user approval
**Complexity**: High

#### Issue 6: Space Names Can Change
**Problem**: Spaces are user-named, can be renamed/deleted anytime
**Impact**: Stored Space name in config could become invalid
**Mitigation**: Need Space ID fallback, but IDs not exposed via AppleScript

### Air Traffic Control Issues

#### Issue 7: Air Traffic Control is User-Configured in Arc
**Problem**: Routing rules are set in Arc, not Chowser
**Impact**: Chowser can't programmatically set routing rules
**User workflow**: User must configure Arc separately
**Documentation**: Need clear guide on setting up ATC for Chowser workflows

#### Issue 8: Air Traffic Control Rules are URL-based
**Problem**: ATC matches URL patterns, not general routing
**Impact**: Can't say "open link in Work Space", must match URL patterns
**Limitation**: Less flexible than Chowser's routing rules

### Sandbox and Permission Issues

#### Issue 9: Reading Arc Data Requires File Access
**Problem**: `~/Library/Application Support/Arc/` requires file system permission
**For sandboxed app**: Need user permission via NSOpenPanel
**Impact**: Extra setup step for users
**Resolution**: Same as other browsers (already handled in BrowserProfileDetector)

#### Issue 10: Arc Can Update Storage Format
**Problem**: Arc's internal storage format not guaranteed stable
**Impact**: Future Arc updates could break detection
**Mitigation**: Use official APIs when available (AppleScript is semi-official)

### Implementation Complexity Issues

#### Issue 11: Two-Step Launch Process for Spaces
**Problem**: Launch Arc → Switch Space requires coordination
**Challenges**:
- Detecting when Arc finished launching
- Timing AppleScript execution
- Handling if Arc already running
- Handling if Space doesn't exist
**Complexity**: High

#### Issue 12: No Space ID Access via AppleScript
**Problem**: AppleScript uses Space names, not IDs
**Impact**: Space renames break saved configs
**Example**: User renames "Work" to "Work Stuff" → config invalid
**Mitigation**: Re-scan Spaces periodically? Fuzzy matching?

### Testing Issues

#### Issue 13: Arc-Specific Test Environment
**Problem**: Testing Space switching requires Arc running with specific Spaces
**Impact**: Hard to automate tests
**CI/CD**: Can't easily test Arc integration in CI
**Resolution**: Mock Arc detection, manual testing for Space features

#### Issue 14: Multiple Arc Configurations
**Problem**: Users might have different Space setups
**Testing**: Need to test various Space configurations
**Edge cases**: 
- No Spaces created
- 10+ Spaces
- Spaces with special characters in names
- Deleted default Space

### User Experience Issues

#### Issue 15: Explaining Profiles vs Spaces
**Problem**: Users coming from Chrome expect "profiles"
**Arc terminology**: "Spaces" and "Profiles" both exist but different
**Documentation challenge**: Explaining Arc's unique model
**Resolution**: Clear documentation, possibly glossary

#### Issue 16: Feature Parity Expectations
**Problem**: Users expect Arc to work like Chrome/Firefox
**Reality**: Arc has different architecture and limitations
**Impact**: User disappointment when profile switching doesn't work
**Mitigation**: Clear messaging about limitations upfront

### Performance Issues

#### Issue 17: Parsing StorableSidebar.json on Every Launch
**Problem**: If we implement Space detection, need to parse JSON frequently
**Size**: StorableSidebar.json can be large (many tabs/spaces)
**Impact**: Potential performance hit
**Mitigation**: Cache parsed data, only re-parse when file modified

#### Issue 18: AppleScript Execution Delay
**Problem**: Running AppleScript adds latency to link opening
**User experience**: Noticeable delay vs direct launch
**Impact**: Slower than other browsers
**Measurement needed**: Profile actual delay (estimate 200-500ms)

### Maintenance Issues

#### Issue 19: Keeping Up with Arc Updates
**Problem**: Arc is actively developed, changes frequently
**Risk**: Storage format changes, AppleScript API changes
**Maintenance burden**: Need to monitor Arc updates
**Mitigation**: Join Arc community, monitor GitHub discussions

#### Issue 20: No Official Developer Documentation
**Problem**: Arc doesn't have official developer docs for integration
**Impact**: Relying on reverse engineering and community knowledge
**Risk**: Implementation based on undocumented behavior
**Resolution**: Stick to officially documented AppleScript API only

### Conclusion
The primary issue is Arc's lack of CLI profile support. All other issues stem from working around this limitation. The recommended approach (single Arc browser, no profiles) avoids most of these issues by not attempting complex workarounds.

For Phase 2 (Space support), expect to deal with issues #4-#20 above. Complexity is HIGH for marginal benefit.

