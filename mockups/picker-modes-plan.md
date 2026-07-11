# Radial and Minimal Picker Modes — Implementation Plan

> Status: implemented on 2026-07-11. The interactive HTML beside this file remains a throwaway visual reference; production behavior lives in `Chowser/QuickPickerViews.swift`.

## Confirmed behavior

- Add two persisted picker layouts alongside **Icons** and **List**:
  - **Radial** — cursor-centered directional browser/profile selection.
  - **Minimal** — a very small app-switcher-style strip.
- Radial shows up to **8 browser/profile destinations plus More**.
- **More** opens a compact vertical list for all remaining destinations.
- Passive pointer movement highlights a destination. Click or Return confirms it.
- A new press-drag-release gesture inside the picker also confirms the highlighted destination.
- Radial is a full circle when space permits. Near an edge it becomes an inward-facing semicircle; near a corner it becomes a tighter cut-pie fan.
- Minimal supports pointer hover/movement, click, press-drag-release, arrows, number shortcuts, and Return.
- The picker no longer renders URL rewrite-trace rows. Rewrite processing and internal trace data remain intact.

## Production design

### 1. Make layout mode explicit

Replace scattered layout strings with a shared `PickerLayoutMode: String, Codable, CaseIterable` containing `icons`, `list`, `radial`, and `minimal`. Keep decoding backward-compatible with existing `icons`/`list` values and fall back to `icons` for unknown persisted data.

Touchpoints:

- `Chowser/BrowserManager.swift`
- `Chowser/SettingsView+Appearance.swift`
- `Chowser/MCPServer.swift`
- Existing manager and MCP tests

The MCP settings endpoint must advertise and accept `radial` and `minimal` without changing existing response keys.

### 2. Separate shared picker behavior from classic presentation

Keep browser launching, private-mode handling, dismissal, shortcuts, and selected browser identity shared. Split only the visual presentation:

- Existing Icons/List presentation: current URL header and classic controls.
- `RadialPickerView`: radial geometry and More list.
- `MinimalPickerView`: compact switcher strip and More list.

Use one shared selection model so mouse, drag, keyboard, numeric shortcuts, and accessibility actions cannot disagree about the selected browser.

Suggested new files:

- `Chowser/PickerLayoutMode.swift`
- `Chowser/RadialPickerGeometry.swift`
- `Chowser/RadialPickerView.swift`
- `Chowser/MinimalPickerView.swift`
- `Chowser/QuickPickerSelection.swift`

### 3. Place quick pickers relative to the cursor

`AppDelegate.configurePickerAndShow` currently centers the picker on the active screen. Change placement by mode:

- Icons/List: retain current centered behavior.
- Radial: place a bounded transparent panel around the captured mouse location. Clamp the panel to `NSScreen.visibleFrame` and pass the cursor’s panel-local anchor into the SwiftUI view.
- Minimal: place the narrow strip around the mouse location, clamped to the visible screen.

Capture the mouse location once per intercepted link so later pointer movement does not move the panel itself.

The geometry layer determines the radial shape from available space around that anchor:

- Enough room: 360° ring.
- One constrained edge: 180° inward-facing fan.
- Corner/two constrained edges: approximately 120° inward-facing cut-pie fan.

Keep this calculation pure and independent of SwiftUI so it can be unit tested.

### 4. Implement Radial interaction

- Build at most nine direct wedges: first eight configured browser/profile destinations and a More wedge when overflow exists.
- Maintain a small center dead zone to prevent accidental selection when the picker first appears.
- Convert pointer delta from the original anchor into an angle and select the nearest visible wedge.
- Highlight with a clear filled wedge, icon enlargement, and selected browser/profile caption.
- Click or Return launches the selected destination.
- A fresh pointer-down inside the center/selector starts drag selection; pointer-up launches only when a valid wedge is selected.
- Escape dismisses. Number keys continue to launch the corresponding configured destination. `P` continues to toggle private mode, reflected by purple selection styling.
- Activating More opens a compact vertical overflow list positioned inward and clamped inside the panel.

### 5. Implement Minimal interaction

- Render a small translucent switcher strip near the captured cursor.
- Show compact icons; show only the current destination’s browser/profile caption rather than permanent labels under every icon.
- Use the same first-eight-plus-More policy as Radial for predictable muscle memory.
- Pointer hover/movement selects an item. Left/right arrows cycle. Number keys select/launch their existing destinations. Return confirms.
- A new press-drag-release gesture selects and launches from the strip.
- More opens the same compact vertical overflow list component.

### 6. Remove rewrite traces from picker UI

In `Chowser/ContentView.swift`:

- Remove the `currentRewriteTrace` block from `urlBubble`.
- Remove the private `rewriteTraceView` presentation.
- Do **not** remove rewrite execution, `currentRewriteTrace` assignment, or diagnostics/pipeline state.

The normal optional webpage metadata preview remains available in Icons/List mode. Radial and Minimal intentionally render neither the URL header nor link preview.

### 7. Update Appearance settings and live preview

- Expand the segmented Layout picker to: **Icons / List / Radial / Minimal**.
- Disable icon-only controls when they do not apply, as today.
- In the Settings preview, provide a synthetic center anchor for Radial/Minimal so the real view remains interactive without depending on the Settings window’s global cursor position.
- Keep appearance tint, color scheme, accent, inactive-browser dimming, and private-mode color behavior consistent where applicable.

### 8. Accessibility and fallback behavior

- Represent every wedge/strip item as an accessibility button with browser and profile in its label.
- Announce selection changes without requiring pointer precision.
- Preserve full keyboard operation and existing shortcut keys.
- If there are no configured browsers, use the existing empty state rather than an empty ring/strip.
- If there are eight or fewer destinations, omit More and distribute the radial wedges evenly.

## Test plan

### Unit tests

- Full-circle, edge-fan, and corner-fan geometry.
- Angle-to-index mapping across the ±π boundary.
- Dead-zone behavior.
- Eight-item cutoff and overflow list ordering.
- Layout-mode persistence and unknown-value fallback.
- MCP acceptance/serialization of `radial` and `minimal`.

### UI tests

- Select each new layout in Settings and verify it persists.
- Radial keyboard selection + Return launches the expected browser.
- Minimal arrow selection + Return launches the expected browser.
- More opens and launches an overflow browser/profile.
- Escape dismisses both quick pickers.
- Picker no longer exposes `picker.rewriteTrace`.

### Manual checks

- Center, every screen edge, and all four corners.
- Multiple displays with different scaling and menu-bar/Dock positions.
- Full-screen Spaces.
- Trackpad, mouse, click confirmation, and press-drag-release.
- 1, 8, 9, and more than 9 configured destinations.
- Reduced transparency, light/dark mode, and VoiceOver.

## Safe implementation order

1. Add the typed layout mode and update persistence/MCP tests.
2. Add pure radial geometry and unit tests.
3. Add shared quick-picker selection and overflow list.
4. Implement Radial with cursor-relative window placement.
5. Implement Minimal using the same selection/overflow behavior.
6. Update Settings and preview.
7. Remove rewrite-trace rendering only.
8. Add UI tests and run the full macOS test suite.
