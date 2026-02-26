# Research Plan: Arc and Dia Browser Profile Detection

## TL;DR

> Research how Arc and Dia browsers store their profiles so Chowser can detect and use them.

> **Goal**: Document Arc/Dia profile storage format and create implementation plan

---

## Context

### Background
Chowser currently detects browser profiles for:
- **Chromium-based**: Chrome, Brave, Edge, Vivaldi (via `Local State` JSON → `profile.info_cache`)
- **Firefox-based**: Firefox, Zen (via `profiles.ini`)

Arc and Dia browsers are NOT currently supported.

### Issue
Arc (bundle ID: `company.thebrowser.Browser`) and Dia browsers need profile detection added.

---

## Research Objectives

### 1. Arc Browser Profiles
- [ ] Find where Arc stores profile data in `~/Library/Application Support/Arc/`
- [ ] Determine if it uses Chromium-style Local State JSON
- [ ] Find Arc's "Spaces" (their profile concept) storage location
- [ ] Check for protobuf format (StorableArchive) vs JSON
- [ ] Document bundle ID and profile directory structure

### 2. Dia Browser Profiles
- [ ] Find Dia's bundle ID
- [ ] Locate profile storage in `~/Library/Application Support/Dia/`
- [ ] Determine if it uses Chromium or Firefox-style storage
- [ ] Document profile directory structure

### 3. Profile Launch Arguments
- [ ] Research how to launch Arc with specific Space/profile
- [ ] Research how to launch Dia with specific profile
- [ ] Find command-line flags for profile selection

---

## Research Methods

### File System Investigation
```bash
# Check Arc Application Support
ls -la ~/Library/Application\ Support/Arc/

# Check Arc Local State format
cat ~/Library/Application\ Support/Arc/User\ Data/Local\ State | head -100

# Check for profile info
ls -la ~/Library/Application\ Support/Arc/User\ Data/
```

### Documentation Search
- Arc browser documentation
- Arc community discussions about profiles
- Dia browser documentation
- GitHub issues about Arc profiles

### Code Research
- Look for existing Arc profile detection projects
- Check Chromium source for Arc detection
- Search for "Arc Browser Space" API

---

## Expected Deliverables

1. **Research Report** documenting:
   - Arc profile storage format and location
   - Dia profile storage format and location
   - Profile launch command-line arguments
   - Implementation complexity assessment

2. **Implementation Plan** (if feasible):
   - Code changes needed in `BrowserProfileDetector.swift`
   - New bundle IDs to add
   - Profile detection method for each browser

3. **Alternative Approaches** (if direct detection not feasible):
   - Manual profile path input
   - Custom arguments approach
   - Document as "not supported" with workaround

---

## Acceptance Criteria

- [ ] Clear documentation of Arc profile storage
- [ ] Clear documentation of Dia profile storage (if applicable)
- [ ] Implementation approach identified (or documented limitation)
- [ ] No implementation required - research only

---

## Notes

- This is a RESEARCH PLAN only - no code changes
- Implementation would be a separate work plan after research completes
- If Arc uses proprietary protobuf, may need alternative approach
