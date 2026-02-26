# Chowser Issues Fix Plan

## TL;DR

> Fix 6 issues in the Chowser picker and settings: close button bug, copy URL feature, rules case sensitivity, rules performance, memory investigation, and settings navigation improvements.

> **Deliverables**: Working X close button, URL copy button, case-insensitive path matching, optimized rule lookup, memory profiling, and improved settings UI

> **Estimated Effort**: Medium | **Parallel Execution**: YES - 3 waves | **Critical Path**: X button → URL copy → Rules fixes → Settings improvements

---

## Context

### Original Request
Fix these issues:
1. Settings page doesn't open to the quick browser selector panel → **Keep separate window but make more accessible (B)**
2. Close (X) button doesn't work in picker (keyboard ESC works)
3. Add option to copy URL to clipboard
4. Rules are slow + case sensitivity bug (e.g., github.com/Dinesynk)
5. Check if app consumes lots of RAM over time
6. ~~Arc/Dia profile detection~~ → Separate research plan
7. Settings page harder to navigate (many hidden options)

### Interview Summary
**Key Discussions**:
- Issue 1: User wants better settings access from picker, not in-panel sheet
- Issue 2: X button click doesn't work, ESC keyboard works → button click handling issue in NSPanel
- Issue 4: Path matching is case-sensitive when it should be case-insensitive
- Issue 6: Deferred to separate research plan

**Research Findings**:
- Issue 2: `.buttonStyle(.plain)` + non-activating NSPanel = click events may not propagate
- Issue 4: `hostMatches()` lowercases host, but `pathMatches()` doesn't lowercase path (line 807)
- Issue 4: O(n) linear scan with pattern normalization on every match = slow with 30+ rules

---

## Work Objectives

### Core Objective
Fix 6 issues in Chowser picker and settings:

### Concrete Deliverables
- [ ] Issue 2: X close button works in picker panel
- [ ] Issue 3: Copy URL button in picker URL display
- [ ] Issue 4a: Case-insensitive path matching in rules
- [ ] Issue 4b: Optimized rule lookup (pre-normalize patterns, index by host)
- [ ] Issue 5: Memory investigation with profiling setup
- [ ] Issue 7: Improved settings navigation (more visible options)

### Definition of Done
- [ ] Clicking X button dismisses picker panel
- [ ] Copy button appears in URL section, copies URL to clipboard
- [ ] Rule `*.github.com/Dinesynk` matches URL `https://github.com/DINESYNK/page`
- [ ] 30+ rules don't cause noticeable delay
- [ ] Memory profiler shows baseline and can be run
- [ ] Settings sidebar has quick-access to common options

### Must Have
- Backward compatible (existing rules work as before)
- No regression in keyboard navigation
- Tests pass after changes

### Must NOT Have
- Don't change rule storage format (migration complexity)
- Don't remove any existing functionality
- Don't break import/export

---

## Verification Strategy

### Test Infrastructure
- **Framework**: Xcode test (existing)
- **Location**: ChowserTests/
- **Run**: `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests`

### QA Policy
Every task includes agent-executed QA:
- Build verification: `xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Debug build`
- Test suite: Run existing tests after each change
- Manual verification for UI fixes

---

## Execution Strategy

### Wave 1 (UI Fixes - can run parallel)
```
├── Task 1: Fix X close button in picker panel
├── Task 2: Add copy URL button to picker
└── Task 3: Add quick settings access from picker
```

### Wave 2 (Rules Performance + Case Sensitivity)
```
├── Task 4: Fix case-insensitive path matching
├── Task 5: Optimize rule lookup (pre-normalize, index)
└── Task 6: Add tests for case sensitivity edge cases
```

### Wave 3 (Settings + Memory)
```
├── Task 7: Improve settings navigation (more visible options)
├── Task 8: Memory investigation - add profiling support
└── Task 9: Final verification and cleanup
```

### Dependency Matrix
- **1-3**: — — 4-6, 7
- **4-6**: 1-3 — 8-9
- **7-8**: 4-6 — 9

---

## TODOs

- [ ] 1. Fix X close button in picker panel

  **What to do**:
  - Change X button from `.buttonStyle(.plain)` to explicit hit testing
  - Or use NSButton with proper action wiring instead of SwiftUI Button
  - Add `.contentShape(Rectangle())` for larger hit area
  - Verify click works in non-activating NSPanel

  **Must NOT do**:
  - Don't break keyboard ESC handling

  **References**:
  - ContentView.swift:171-181 - Current X button implementation
  - AppDelegate.swift:179-200 - NSPanel creation (non-activating)

  **Acceptance Criteria**:
  - [ ] Click X button → picker closes
  - [ ] ESC key → picker still closes
  - [ ] Build passes

- [ ] 2. Add copy URL button to picker

  **What to do**:
  - Add copy button in urlDisplay section (after URL text, before spacer)
  - Use NSPasteboard.general for clipboard
  - Show brief visual feedback (checkmark or tooltip)

  **References**:
  - ContentView.swift:189-216 - URL display section
  - Use Image(systemName: "doc.on.doc") for icon

  **Acceptance Criteria**:
  - [ ] Copy button visible next to URL
  - [ ] Click copies full URL to clipboard
  - [ ] Visual feedback on copy

- [ ] 3. Add quick settings access from picker

  **What to do**:
  - Add tooltip or hint in picker that mentions keyboard shortcut for settings
  - Or add a subtle "Settings" link in picker footer
  - Keep settings in separate window (not sheet)

  **References**:
  - ContentView.swift:255-269 - pickerHintBar

  **Acceptance Criteria**:
  - [ ] User knows how to access settings from picker
  - [ ] Clicking opens settings window

- [ ] 4. Fix case-insensitive path matching

  **What to do**:
  - Modify `pathMatches()` in BrowserManager.swift to lowercase both path and prefix
  - Line 802-808: Add `.lowercased()` to path comparison
  - Also lowercase in `normalizedPathPrefix()` if needed

  **References**:
  - BrowserManager.swift:802-808 - pathMatches function
  - BrowserManager.swift:776-787 - normalizedPathPrefix

  **Acceptance Criteria**:
  - [ ] Rule `*.github.com/Dinesynk` matches URL with `/DINESYNK`
  - [ ] Rule `/docs` matches `/Docs` and `/DOCS`
  - [ ] Existing tests pass

- [ ] 5. Optimize rule lookup performance

  **What to do**:
  - Pre-normalize patterns when rules are loaded/edited (not on every match)
  - Add simple index: group rules by domain suffix for faster lookup
  - Or at minimum, cache normalized pattern in rule struct

  **References**:
  - BrowserManager.swift:56-60 - routingRules property (save/load)
  - BrowserManager.swift:410-425 - resolvedRoute function

  **Acceptance Criteria**:
  - [ ] 30+ rules: match time < 50ms
  - [ ] No regression in matching behavior

- [ ] 6. Add tests for case sensitivity

  **What to do**:
  - Add unit tests for case-insensitive path matching
  - Test edge: URL path case differs from rule path prefix

  **References**:
  - ChowserTests/BrowserManagerTests.swift - Existing test patterns

  **Acceptance Criteria**:
  - [ ] New tests pass
  - [ ] Existing tests still pass

- [ ] 7. Improve settings navigation

  **What to do**:
  - Make "Advanced" options visible by default or add "Show all" toggle
  - Add keyboard shortcuts hint in settings header
  - Consider reorganizing General section with collapsible groups

  **References**:
  - SettingsView.swift:259-281 - Browser DisclosureGroup
  - SettingsView.swift:629-770 - General section

  **Acceptance Criteria**:
  - [ ] Common options more visible
  - [ ] No functional regression
  - [ ] Still builds

- [ ] 8. Memory investigation setup

  **What to do**:
  - Add a "Memory" debug section in General settings (hidden behind flag)
  - Add ability to export memory stats
  - Document expected memory footprint
  - Not required to find actual issues, just setup for investigation

  **References**:
  - SettingsView.swift:743-766 - About section (template for new section)

  **Acceptance Criteria**:
  - [ ] Memory info accessible for debugging
  - [ ] Doesn't impact normal usage

- [ ] 9. Final verification

  **What to do**:
  - Run full test suite
  - Build verification
  - Verify all acceptance criteria met

  **Acceptance Criteria**:
  - [ ] All tests pass
  - [ ] Build succeeds
  - [ ] All 6 issues resolved

---

## Final Verification Wave

- [ ] F1. Build check: `xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Debug build` → SUCCESS
- [ ] F2. Test suite: `xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests` → ALL PASS
- [ ] F3. Manual verification: Open picker, test X button, copy URL, test case-insensitive rule

---

## Success Criteria

- All 6 issues (excluding Arc/Dia research) resolved
- Backward compatible with existing rules
- Tests pass
- Build succeeds
