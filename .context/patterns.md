<!-- Last verified: 2026-02-28 against commit 892fcaf -->

# Code Patterns

Recurring patterns and conventions in the Chowser codebase. Each pattern includes at least one concrete example.

---

## 1. Observable Singleton

`BrowserManager` is the single source of truth for all mutable app state.

```
@MainActor @Observable
class BrowserManager {
    static let shared = BrowserManager()
    var configuredBrowsers: [BrowserConfig] = []
    var routingRules: [BrowserRoutingRule] = []
    ...
}
```

Views access it directly: `var browserManager = BrowserManager.shared`. There is no dependency injection for the manager — it's always the shared instance. This is acceptable because the app has a single data context; UI tests isolate via UserDefaults suite override, not DI.

**See also**: `DomainFrequencyTracker.shared`, `AppMetadataCache.shared`, `OnboardingManager.shared` — all follow the same singleton pattern.

---

## 2. Commit-on-Blur Editing

List row views (`BrowserConfigRow`, `RuleRowView`) keep local `@State` copies of editable fields to avoid re-rendering the entire list on each keystroke.

**Pattern**:
1. Initialize `@State` from model property in `init`
2. Bind text field to local `@State`
3. On focus loss (`.onChange(of: focusedField)`), commit local state to the manager via callback
4. On external model change (`.onChange(of: rule)`), update local state only if that field is not focused

**Example** (`BrowserConfigRow.swift`):
```swift
@State private var editingName: String  // local copy
@FocusState private var focusedField: Field?

.onChange(of: focusedField) { oldValue, _ in
    if let field = oldValue { commitField(field) }
}
.onChange(of: browser) { _, newBrowser in
    if focusedField != .name { editingName = newBrowser.name }
}
```

---

## 3. Equatable Views for List Performance

Row views conform to `Equatable` and use the `.equatable()` modifier. Callbacks are deliberately excluded from equality checks because closures are not Equatable.

**Example** (`RuleRowView.swift`):
```swift
extension RuleRowView: Equatable {
    static func == (lhs: RuleRowView, rhs: RuleRowView) -> Bool {
        lhs.rule == rhs.rule &&
        lhs.configuredBrowsers == rhs.configuredBrowsers &&
        lhs.hasSearchQuery == rhs.hasSearchQuery &&
        lhs.canMoveUp == rhs.canMoveUp &&
        lhs.canMoveDown == rhs.canMoveDown
    }
}
```

Only data properties are compared. This means rows only re-render when their underlying data changes, not when the parent list re-renders.

---

## 4. AppKit Window Hosting

SwiftUI views are hosted in manually managed AppKit windows rather than SwiftUI scenes.

**Picker**: `ChowserPanel` (NSPanel subclass) → `NSHostingController<ContentView>`
**Settings**: `NSWindowController` → `NSHostingController<SettingsView>`
**Onboarding**: `NSWindowController` → `NSHostingController<OnboardingView>`

The `@main` `ChowserApp` struct has only an `EmptyView()` in its `Settings` scene — all real windows are created and managed in `AppDelegate`.

---

## 5. Callback-Based Row Views

Row views receive mutation callbacks as closure parameters rather than holding a reference to BrowserManager. This decouples the view from the data source and allows factory functions in parent views to inject validation logic.

**Example** (`SettingsView+Rules.swift` creates `RuleRowView` with normalized host patterns):
```swift
ruleRow(rule, hasSearchQuery: hasRuleSearchQuery)
// Inside ruleRow():
RuleRowView(
    rule: rule,
    onUpdate: { updated in
        var final = updated
        let normalized = browserManager.normalizedRoutingHostPattern(updated.hostPattern)
        if browserManager.isValidRoutingHostPattern(normalized) {
            final.hostPattern = normalized
        }
        browserManager.updateRoutingRule(final)
    },
    isValidHostPattern: { browserManager.isValidRoutingHostPattern($0) },
    ...
)
```

Callbacks: `onUpdate`, `onDelete`, `onDuplicate`, `onMoveUp`, `onMoveDown`, `onUpdateName`, `onUpdateShortcut`, `onUpdateCustomArgs`, `isValidHostPattern`.

---

## 6. UserDefaults Test Isolation

UI tests override the UserDefaults suite to prevent test state from polluting the real app.

**Pattern**:
1. `AppEnvironment.isUITesting` checks for `-UITesting` process argument
2. If true, `AppEnvironment.defaultsSuiteName` returns `"in.sreerams.Chowser.UITests"`
3. `BrowserManager` uses `UserDefaults(suiteName:)` instead of `.standard`
4. `-UITesting_ClearData` flag triggers `clearPersistedBrowserList()` and `clearPersistedRoutingRules()` on init

**See**: `AppEnvironment.swift` for all flags, `BrowserManager.swift` init for suite selection.

---

## 7. Browser Family Detection

Browsers are classified into families for launch-argument selection:

| Family | Bundle ID patterns | Launch args |
|--------|-------------------|-------------|
| `.chromium` | `com.google.Chrome`, `com.brave.Browser`, `com.microsoft.edgemac`, `com.vivaldi.Vivaldi`, `company.thebrowser.Browser`, `company.thebrowser.dia`, `org.chromium.Chromium`, `com.operasoftware.Opera` | `--profile-directory=X`, `--incognito` |
| `.firefox` | `org.mozilla.firefox`, `app.zen-browser.zen`, `org.mozilla.librewolf`, `net.waterfox.waterfox` | `-P X`, `-private` |
| `.other` | Everything else | No profile args |

**Note**: Arc and Dia use Chromium profile logic but have special storable sidestates; Zen use Firefox profile logic.

### 8. SwiftUI Performance Patterns
- **List Identity**: Use `.id(UUID())` on `List` containers in `SettingsView` subviews to force re-evaluation of the list when backing data changes. This resolves issues with stale row rendering and selection state.
- **Row Identity**: Use `.id(item.id)` on individual rows within `ForEach` to ensure SwiftUI correctly tracks row identity during reordering or search filtering.
- **Equatable Views**: Wrap expensive rows (like `BrowserConfigRow` and `RuleRowView`) in `.equatable()` to prevent unnecessary body re-computations when non-visual properties change.

The `browserFamily` enum is used in `launchInfo()` to determine which CLI flags to pass.

**See**: `BrowserManager.swift` `BrowserFamily` enum and `launchInfo()` method.

---

## 8. Keyboard Event Monitoring

The picker uses `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` rather than SwiftUI keyboard shortcuts, because the panel is non-activating and SwiftUI keyboard events may not fire reliably.

**Keycode map** (ContentView.swift):
- `18-25, 26, 28` → number keys 1-9
- `83-92` → numpad 1-9
- `53` → Escape, `48` → Tab, `36/76/49` → Return/Enter/Space
- `123-126` → arrow keys
- Letter keys matched by `characters` string

**Pattern**: The monitor captures raw keycodes, maps them to actions, and returns `nil` to consume the event (prevents system beeps).

---

## 9. Identity-Based Browser Matching

Browsers are uniquely identified by `"\(bundleId)|\(profile ?? "")"` — the `identity` computed property on `BrowserConfig`. This allows multiple entries for the same browser with different profiles (e.g., "Chrome - Work" and "Chrome - Personal").

**Used in**:
- `AddBrowserSheet` to filter already-configured browsers
- `RuleRowView` browser picker binding
- `ConfigureRuleView` browser selection
- Import dedup logic

---

## 10. Process-Lifetime Caches

`AppMetadataCache` and `BrowserProfileDetector` use static dictionaries that persist for the app's lifetime. They are never written to disk.

**AppMetadataCache**: Caches `NSImage` icons, display names, and `URL` paths keyed by bundle ID. Also tracks a `missing` set for bundle IDs that don't exist, avoiding repeated NSWorkspace lookups.

**BrowserProfileDetector**: Caches `[BrowserProfile]` arrays keyed by bundle ID. `clearCache()` is called when Settings opens (to pick up newly created profiles).

**Pattern**: Cache is a `static var` dictionary on a class with a `static let shared` singleton. No locking — relies on `@MainActor` isolation.
