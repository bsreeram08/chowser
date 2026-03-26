# Learnings and Conventions

## Project Context
- This is the Electrobun version of Chowser (cross-platform using Bun + Electrobun framework)
- Goal: Feature parity with macOS native Chowser on Windows and Linux
- UI redesign from vanilla TS to Svelte 5 with iOS-quality aesthetics

## Key Decisions
- Framework: Electrobun (NOT Tauri) - user explicitly chose this
- UI: Svelte 5 (NOT SvelteKit - too heavy)
- Distribution: Self-extracting archives (acceptable to user)
- Source-app routing: Disabled on Windows/Linux (accuracy > availability)
- Testing: Unit tests + Playwright for E2E

## Technical Constraints
- Browser detection already works cross-platform (browserDetector.ts)
- Profile discovery works (Chrome Local State, Firefox profiles.ini)
- Browser launching is macOS-only - needs Windows/Linux Bun.spawn() implementation
- No onboarding flow exists yet (macOS has 5-step wizard)

---

## Task 2: Design System Tokens

**What we built:** `src/views/shared/tokens.css` with CSS custom properties for light/dark mode.

**Key patterns:**
- **Semantic naming:** `--color-background`, `--color-text-primary` (not color-specific like `--blue-500`)
- **Light mode default:** Base variables in `:root`, overrides in `@media (prefers-color-scheme: dark)`
- **Typography scale:** 6 sizes (xs-2xl) based on modular scale, 4 weights, 3 line-height options
- **Spacing unit:** 4px base (matches iOS/macOS `--spacing-1` = 0.25rem = 4px)
- **Border radius:** 5 values (sm=4px, md=8px, lg=12px, xl=16px, full=9999px)
- **Glass effects:** Dedicated opacity overlays for light/dark modes (`--color-glass-light`, `--color-glass-border-light`)

**Design decisions:**
1. Used `-apple-system` font stack for native feel (matches Swift Chowser)
2. Defined both `--color-accent` (blue) for primary, plus semantic colors (success, warning, error, info)
3. Shadow depths follow iOS pattern (sm→xl) for elevation consistency
4. Utility classes provided (`.text-primary`, `.bg-surface`, `.rounded-xl`) for quick adoption

**Next step considerations:**
- Import this in picker/settings HTML via `<link rel="stylesheet" href="../shared/tokens.css">`
- Use `var(--color-background)` in component CSS instead of hardcoded colors
- Test with `prefers-color-scheme: dark` in System Preferences to verify dark mode

## Task 6: Platform Detection Utilities

### Pattern Established
✓ Platform detection utilities created in `src/bun/platform.ts`
✓ Exports 6 functions: isWindows(), isLinux(), isMacOS(), getPlatformConfigPath(), getPlatformStartupPath(), getDefaultBrowserRegistryPath()

### Cross-Platform Path Conventions
- **macOS**: Uses ~/Library/Application Support, ~/Library/LaunchAgents
- **Windows**: Uses %APPDATA%, HKEY_CURRENT_USER registry paths
- **Linux**: Uses $XDG_CONFIG_HOME (with ~/.config fallback), ~/.config/autostart

### Code Pattern
- Use `process.platform` directly (cached as const PLATFORM)
- Switch on PLATFORM with "win32" | "linux" | default (darwin)
- Use node:os.homedir() and node:path.join() for cross-platform path safety
- Environment variable fallbacks: APPDATA, XDG_CONFIG_HOME

### Future Usage
- Other modules should import from `platform.ts` instead of duplicating platform checks
- Refactor `config.ts` resolveConfigDir() to use getPlatformConfigPath()

## Task 4: Cross-Platform Browser Launcher

### Pattern Established
✓ `launchBrowserNative()` added to `src/bun/browserLauncher.ts` for Windows and Linux
✓ `launchBrowser()` dispatches on `process.platform` — macOS keeps `/usr/bin/open`, others use `Bun.spawn()`

### Argument Order (Critical)
- Chromium: `<exe> [--profile-directory=<dir>] [--incognito] [customArgs] <url>`
- Firefox: `<exe> [-P <profile>] [-private-window] [customArgs] <url>`
- URL always last; profile before private flag

### Detaching the Process
- Use `Bun.spawn([exe, ...args], { stdio: ["ignore","ignore","ignore"] })`
- Call `proc.unref()` immediately after — releases child from parent so Chowser doesn't wait
- Without `unref()` Chowser would block until the browser window closes

### Private Mode Flags
- Chromium family → `--incognito`
- Firefox/Zen/LibreWolf → `-private-window`
- Safari → empty string (no CLI flag)
- Other → `--private`

### resolveExecutablePath() from browserDetector.ts
- Returns null on macOS (not needed there, macOS uses mdfind)
- Windows: probes known .exe paths from WINDOWS_BROWSERS spec list
- Linux: runs `which <exe>` then probes LINUX_SEARCH_DIRS

### LibreWolf prefix fix
- `privateFlag()` only checks `org.mozilla` and `app.zen-browser` prefixes
- LibreWolf appId is `io.gitlab.librewolf-community` — falls through to `--private` (correct)
- Profile args in `launchBrowserNative` correctly adds `io.gitlab.librewolf` check for `-P` flag

## Task 6: Shared Components (Button, Input, Toggle, Card, Icon)

### Key Learnings

**Svelte 5 Runes Pattern:**
- Used `$props()` for reactive prop destructuring with type safety
- Pattern: `let { prop = default } = $props<Interface>()`
- Reactive state via `let` declarations (no useState needed)
- Event binding via `on:click`, `on:change`, `on:input`

**Component Architecture:**
- Each component is minimal and focused (21-108 lines including styles)
- All props optional with sensible defaults
- Consistent callback pattern: `onchange?.(value)` for reactive updates
- Button: 3 variants (primary, secondary, ghost) × 3 sizes (sm, md, lg)
- Input: Label, placeholder, error state with red border and icon
- Toggle: iOS-style 44×24px, animated thumb (20px), 0.3s easing
- Card: Glass effect with `backdrop-filter: blur(20px)` + border
- Icon: SVG wrapper with size/color props, accepts slot children

**Design Token Integration:**
- All colors use CSS variables (no hardcoded hex)
- Spacing uses 4px base unit (--spacing-1 through --spacing-8)
- Border radius uses predefined vars (--radius-sm/md/lg/xl/full)
- Typography uses system fonts and modular scale
- Dark mode automatically supported via @media query

**Component Styling:**
- Inline `<style>` blocks with scoped CSS (no leakage)
- Focus states use accent color with subtle 2px shadow
- Disabled states use opacity + cursor: not-allowed
- Transitions: 0.2s for buttons/inputs, 0.3s for toggle
- Shadow tokens for depth (--shadow-sm used on Toggle thumb)

**Build Verification:**
- Vite build succeeded with 113 modules transformed
- No TypeScript errors
- Bundle: legacy.js 25.06 kB (9.86 gzip)

### Technical Decisions

1. **Button padding:** Uses spacing tokens directly in sm/md/lg classes (not props)
   - Ensures consistency and reduces prop surface area
2. **Input error handling:** Separate error prop + errorMessage for flexibility
   - Can show/hide errors independently from value validation
3. **Toggle track/thumb:** Absolute positioned for precise 20px translate animation
   - Simpler than transform-translate on entire button
4. **Card padding:** Accepts optional padding prop (defaults to --spacing-4)
   - Allows flexibility for different card sizes
5. **Icon:** SVG wrapper with viewBox hardcoded to 24×24 for standard icon size
   - Matches iOS/Material Design conventions

### Files Created
- `src/views/shared/components/Button.svelte` (108 lines)
- `src/views/shared/components/Input.svelte` (106 lines)
- `src/views/shared/components/Toggle.svelte` (75 lines)
- `src/views/shared/components/Card.svelte` (21 lines)
- `src/views/shared/components/Icon.svelte` (28 lines)

### Blockers for Wave 2
- Tasks 8-15 (all component views) now have these 5 shared components as dependencies
- No index.ts barrel export yet (will be created in Task 7)

## Task 4: PickerShell Component

**Pattern: 3-Section Layout with Conditional Dividers**
- Top section (url-section): Shows URL bubble; div rendered conditionally via `{#if $$slots.url}`
- Middle section (content-section): Default slot for browser list
- Bottom section (action-section): Shows keyboard hints; rendered conditionally
- Dividers only rendered when slots exist (reduces DOM bloat)

**Design Tokens Usage**
- Width: `400px` (macOS picker standard)
- Padding: `var(--spacing-4)` = 16px (from Card component)
- Divider color: `var(--color-separator)` with 50% opacity
- Section spacing: `var(--spacing-3)` = 12px top/bottom

**Glass Effect Strategy**
- Delegated entirely to Card component (`backdrop-filter: blur(20px)`)
- PickerShell only handles layout and slot composition
- Avoids duplication of backdrop-filter CSS

**Svelte 5 Rune Usage**
- `$props` destructuring with default: `let { width = 400 } = $props<PickerShellProps>();`
- Slot detection: `$$slots.url` and `$$slots.actions` to conditionally render dividers
- Named slots: `<slot name="url" />`, `<slot />` (default), `<slot name="actions" />`

**Component Hierarchy**
- PickerShell imports Card (shared/components/Card.svelte)
- Card applies glass effect background and border-radius
- PickerShell applies flex layout and section organization
- Dividers use design tokens for consistency

**Next Steps**
- Task 5 will create URLBubble component (slot name="url")
- Task 6 will create BrowserList component (default slot)
- Task 7 will create ActionBar component (slot name="actions")

## Task 9: BrowserIcon Component

### What we built
✓ `src/views/shared/components/BrowserIcon.svelte` — displays browser icon with optional shortcut badge and selection ring

### Key Design Decisions

**Size System:**
- 3 discrete sizes via `data-size` attribute: small=24px, medium=32px, large=48px
- Uses `sizeMap` object for reliable pixel mapping
- All sizes use same `border-radius: 4px` for consistency

**Visual States:**
1. **Placeholder icon** (until real icons fetched)
   - Gradient background: `linear-gradient(135deg, var(--color-accent) → var(--color-accent-pressed))`
   - Extracts browser initial from bundle ID (last component after final dot)
   - White text, centered, bold font
   
2. **Shortcut badge** (optional)
   - 16px circle positioned at bottom-right corner (`bottom: -4px; right: -4px`)
   - Accent background with white text
   - Includes shadow for depth: `0 1px 3px var(--color-shadow-light)`
   - Font: 10px bold, centered

3. **Selected state**
   - 2px solid accent color ring
   - 4px border-radius (matches icon corners)
   - Applied via `.selected` class

**Interactive:**
- Hover: `opacity: 0.8` on entire wrapper
- Smooth transitions: `0.2s ease` on all state changes

### Component Props

```typescript
interface BrowserIconProps {
  bundleId: string;          // required, e.g. "com.google.Chrome"
  size?: 'small' | 'medium' | 'large';  // default: 'medium'
  shortcutKey?: string;      // optional, e.g. "1" or "⌘1"
  isSelected?: boolean;      // default: false
}
```

### Pattern Notes

- **Svelte 5 syntax:** `let { prop } = $props<Interface>()`
- **Reactive compute:** `const iconSize = sizeMap[size]` derived from props
- **No click handlers** — component is presentational only (parent controls selection)
- **Grid-friendly:** Works as flex child with `display: inline-flex`

### TODO: Real Icon Fetching

Next task (Task 16) will:
- Replace gradient placeholder with actual app icon from bundleId
- Use NSWorkspace API (via IPC) or pre-cached icon data
- Handle missing icons with fallback gradient
- This component stays size-agnostic

### Blockers for Task 16
- Task 16 depends on this component being complete and rendering correctly
- Icon fetching mechanism will be built in a separate icon service

## Task 10: BrowserListItem Component

### What we built
✓ `src/views/shared/components/BrowserListItem.svelte` — list row with browser icon, name, profile, and shortcut

### Key Design Decisions

**Layout Structure:**
- Flex row: icon (24px, flex-shrink: 0) | name+profile (flex: 1) | shortcut (right-aligned)
- Height: 44px (iOS touch target minimum)
- Padding: `var(--spacing-3)` = 12px on all sides
- Gap between elements: `var(--spacing-3)` = 12px

**Visual States:**

1. **Default (unselected)**
   - Background: transparent
   - Text: `var(--color-text-primary)`
   
2. **Hover (unselected)**
   - Background: `var(--color-control-background)` (light gray)
   - Smooth 0.15s transition
   
3. **Selected**
   - Background: `var(--color-accent)` (blue)
   - Text: white
   - Profile name: white with 0.8 opacity
   - Shortcut badge: white with 0.2 opacity overlay
   - Higher visual weight via higher contrast

**Component Props:**

```typescript
interface BrowserListItemProps {
  browserName: string;           // required, e.g. "Chrome"
  profileName?: string;          // optional, e.g. "Work"
  shortcutKey?: string;          // optional, e.g. "1"
  bundleId: string;              // passed to BrowserIcon
  isSelected?: boolean;          // default: false
  onclick?: () => void;          // click handler
}
```

**Info Section (Middle):**
- Flex column with 2px gap
- Browser name: semibold, normal font size
- Profile name (if provided): smaller (--font-size-xs), 0.8 opacity
- Both use tight line-height (1.2) for compact appearance

**Shortcut Display (Right):**
- 28px min-width center-aligned
- Smaller font (--font-size-xs), bold weight
- Light background: `rgba(0,0,0,0.1)` normally, `rgba(255,255,255,0.2)` when selected
- Opacity: 0.6 normally, 1.0 when selected
- Subtle rounded corners: `var(--radius-sm)`

**Icon Integration:**
- Imports BrowserIcon from `./BrowserIcon.svelte`
- Passes `bundleId`, `shortcutKey`, `isSelected` directly
- Uses `size="small"` (24px) for list context
- Icon wrapped in flex container to prevent shrinking

### Styling Patterns

- **Button element:** Type="button" with `text-align: left` for semantic HTML
- **Accessibility:** `aria-pressed={isSelected}` for screen readers
- **Transitions:** 0.15s ease for hover background changes (faster than components for responsiveness)
- **Color inheritance:** Selected state colors cascade to children (profile-name, shortcut-display)
- **No hardcoded colors:** All use CSS variables for dark mode support

### Svelte 5 Patterns Used

- `$props<Interface>()` with all props destructured
- Conditional rendering: `{#if profileName}` and `{#if shortcutKey}`
- Class binding: `class:selected={isSelected}`
- Direct onclick handler: `on:click={onclick}`

### Files Created
- `src/views/shared/components/BrowserListItem.svelte` (96 lines including styles)

### Next Steps
- Task 11 will use this component in BrowserListView (loops over browsers)
- Task 17 (PickerView) will render BrowserList and wire onclick to select browsers
- Design considerations for reordering/drag-drop to be determined in Task 11

## Task 19: SettingsShell Component

### What we built
✓ `src/views/settings/components/SettingsShell.svelte` — sidebar navigation with content area for settings tabs

### Key Design Decisions

**Layout Architecture:**
- Grid-based: `display: grid; grid-template-columns: 200px 1fr;`
- Sidebar (left): Fixed 200px width, flex column with gap
- Content (right): flex-1 (fills remaining space), overflow-y auto

**Sidebar Items:**
- 4 tabs: Browsers, Rules, General, Hidden Apps
- Each item: 40px height, padding: `var(--spacing-3)` (12px)
- Consistent spacing between items via `gap: var(--spacing-1)` (4px)

**Visual States:**
1. **Inactive state**
   - Background: transparent
   - Hover: `var(--color-control-background)` (raised effect)
   - Text: `var(--color-text)` (standard contrast)
   
2. **Active state**
   - Background: `var(--color-accent)` (blue)
   - Text: white (inverted)
   - No hover change needed (already highlighted)

**Component Props:**
```typescript
interface Props {
  activeTab: string;           // e.g. "Browsers"
  onTabChange: (tab: string) => void;  // callback on tab click
  children: Snippet;          // Svelte 5 snippet for content area
}
```

**Svelte 5 Patterns Used:**
- `$props()` for destructuring with type safety
- Named export `interface Props` matching destructured params
- Snippet type: `children: Snippet` for slot-equivalent in Svelte 5
- `{@render children()}` to invoke snippet in content div
- Array iteration: `{#each tabs as tab}` for sidebar buttons

**Integration Points:**
- Sidebar border-right: `var(--color-border)` for visual separation
- Uses design tokens for all colors, spacing, radius
- Content padding: `var(--spacing-4)` = 16px
- Smooth transitions: `all 150ms ease` for hover effects

### Files Created
- `src/views/settings/components/SettingsShell.svelte` (72 lines)

### Next Steps (Task 20+)
- Task 20: SettingsPanel wrapper (holds SettingsShell + tab panels)
- Tasks 21-24: Individual tab panels (BrowsersPanel, RulesPanel, GeneralPanel, HiddenAppsPanel)
- Each panel will pass content via children snippet

## Task 36: UrlBubble Component

### What we built
✓ `src/views/picker/components/UrlBubble.svelte` — URL display with copy and unshorten actions

### Key Design Decisions

**Layout: Horizontal flex with sections**
- Left section: Link icon + truncated URL text
- Right section: Action buttons (unshorten, copy)
- Gap between sections: `var(--spacing-4)` = 16px
- Background: `var(--color-background-secondary)` (light gray in light mode, dark gray in dark mode)
- Border-radius: `var(--radius-lg)` = 12px
- Padding: `var(--spacing-3)` = 12px all sides

**URL Truncation Algorithm**
- If URL ≤ 60 chars: display as-is
- If URL > 60 chars: show first 30 + ellipsis + last 20 chars
- Rationale: Preserves domain (usually in first 30) and TLD (usually in last 20)
- Example: `https://very-long-domain.co.uk/path/to/page` → `https://very-long-domain.co.u…/path/to/page`
- Full URL shown in `title` attribute for hover tooltips

**Action Buttons**
1. **Unshorten button** (conditional, hidden when `isUnshortening=true`)
   - Uses ghost variant with Icon component
   - Text hint: "(H)" in 12px secondary color after icon
   - Calls `onUnshorten?.()` callback
   
2. **Loading spinner** (conditional, shown when `isUnshortening=true`)
   - 14px × 14px rotating spinner
   - Uses 2px border with accent top color
   - Animation: `spin 0.8s linear infinite`
   - Centered in 32px wrapper (matches button size)

3. **Copy button** (always visible)
   - Uses ghost variant
   - Calls `navigator.clipboard.writeText(url)` directly
   - Triggers `onCopy?.()` callback on success
   - Icon: clipboard SVG

**Component Props**
```typescript
interface UrlBubbleProps {
  url: string;               // full URL to display
  isUnshortening?: boolean;  // shows spinner when true
  onCopy?: () => void;       // callback after clipboard write
  onUnshorten?: () => void;  // callback when unshorten clicked
}
```

**Svelte 5 Patterns**
- `$props()` rune with destructuring and defaults
- `$derived` for computed truncation: `const displayUrl = truncateUrl(url)`
- Conditional rendering: `{#if isUnshortening}...{:else}...{/if}`
- Async function: `async function handleCopy()` with try/catch

**Icon Strategy**
- Link icon (top-left): 16px, secondary color — uses path data directly
- Copy icon: 14px (inside button)
- Unshorten icon: 14px with path data (arrows indicating expansion)
- All icons wrapped in Icon component (size + color control)

**Design Token Integration**
- Colors: `--color-background-secondary`, `--color-text-primary`, `--color-text-secondary`, `--color-accent`
- Spacing: `--spacing-2` (8px gap between icon/text), `--spacing-3` (12px padding), `--spacing-4` (16px content gap)
- Border-radius: `--radius-lg` (12px)
- Animation keyframe: `@keyframes spin` for 360° rotation

**Dependencies**
- Imports: Button, Icon from shared/components
- No external libraries; uses native `navigator.clipboard` API
- Error handling: console.error() on clipboard failure (silent fallback)

### Files Created
- `src/views/picker/components/UrlBubble.svelte` (120 lines)

### Next Steps
- Task 37 will use this component in PickerView to display the intercepted URL
- Task 38+ will handle click actions (copy triggers toast, unshorten triggers loading state)

## Task 20: BrowserConfigRow Component

### What we built
✓ `src/views/settings/components/BrowserConfigRow.svelte` — editable row for browser configuration in Settings → Browsers tab

### Key Design Decisions

**Layout Structure:**
- Grid: `24px (drag handle) | 32px (icon) | 1fr (info) | 60px (shortcut) | auto (delete button)`
- Height: 60px with padding `var(--spacing-3)` (12px)
- Drag handle: "⋮⋮" (U+205E) in gray, pointer-events: none (visual only, no drag logic yet)
- Border-bottom: 1px separator between rows

**Icon Section:**
- Imports BrowserIcon component
- Passes bundleId, size="medium" (32px), and shortcutKey
- Flex-shrink: 0 to prevent squishing

**Info Section (Left-aligned, flex-1):**
- Browser name: semibold base font, primary text color
- Profile name (if provided): xs font, secondary color
- Bundle ID: 10px monospace, tertiary color, truncated with ellipsis
- All use tight 1.2 line-height for compact appearance
- Flex column with 2px gaps

**Shortcut Key Input (60px fixed width):**
- Sanitizes input: 1-9 only, 1 char max via regex `/[^1-9]/g`
- Updates immediately on input/change
- Calls `onUpdate({ shortcutKey: sanitized })` on valid change
- Uses Input component (inherits design tokens)

**Custom Arguments Section (Expandable):**
- Hidden by default unless `browser.customArguments` has content OR toggle clicked
- Toggle button: "▼/▶ Custom Arguments" (secondary text, hover underline)
- Textarea: monospace font (Courier New), 60px min-height, 1px border, focus ring
- Updates on blur (debounced via local state to avoid full-list re-renders)
- Calls `onUpdate({ customArguments: value })` on blur

**Delete Button:**
- Ghost variant, emoji icon (🗑️)
- Calls `onDelete()` — parent component handles confirmation logic
- No inline confirmation dialog

**Visual States:**
- Default: `--color-control-background` with transparent background
- Hover: `--color-background-secondary` for raised effect
- Transitions: 0.15s ease for hover changes

### Component Props

```typescript
interface BrowserConfigRowProps {
  browser: {
    id: string;
    name: string;
    appId: string;
    shortcutKey: string;
    profile?: string;
    customArguments?: string;
  };
  onUpdate: (updates: Partial<typeof browser>) => void;  // called on field changes
  onDelete: () => void;                                   // called when delete clicked
}
```

### Local State Management

- `shortcutInput`: Tracks typed value before update
- `showCustomArgs`: Toggle for expanded custom args section
- `customArgsInput`: Tracks textarea value before blur/commit

**Debounce pattern:** Uses local state + blur handler to avoid propagating every keystroke to parent (matches RuleRowView pattern from Swift version)

### Svelte 5 Patterns Used

- `$props()` with interface destructuring
- `$state()` for reactive local variables
- Conditional rendering: `{#if browser.profile}` and `{#if showCustomArgs}`
- Function binding: `onchange={handleShortcutChange}` with inline logic
- Textarea with focus handling: `on:blur={handleCustomArgsBlur}`

### Design Token Integration

- All colors: `--color-*` semantic variables
- Spacing: `--spacing-1` through `--spacing-4` (4px unit)
- Border-radius: `--radius-md` (8px)
- Font sizes: `--font-size-sm`, `--font-size-base`, `--font-size-xs`
- Monospace: Courier New fallback (no custom mono font loaded)

### Files Created
- `src/views/settings/components/BrowserConfigRow.svelte` (170 lines)

### Next Steps
- Task 21 will create BrowsersPanel using this component in a loop
- Parent (BrowsersPanel) will manage browser array, handle reordering, and pass onUpdate/onDelete callbacks
- Drag-drop reordering logic will be added in Task 21 or later

## Task 8: Modal Component

### What we built
✓ `src/views/shared/components/Modal.svelte` — reusable modal/sheet overlay with animations

### Key Design Decisions

**Overlay Architecture:**
- Fixed positioning: `position: fixed; top: 0; left: 0; right: 0; bottom: 0`
- Dark backdrop: `background: rgba(0, 0, 0, 0.5)` (50% opacity)
- Z-index: 1000 (ensures visibility above all content)
- Click handler: `on:click={onClose}` for dismiss-on-background-tap

**Modal Content Container:**
- Card component wrapper: inherits glass effect + border
- Max-width: 600px (desktop standard)
- Width: 90% on mobile (responsive)
- Max-height: 90vh with `overflow-y: auto` (prevents overflow on small screens)
- Centered: `display: flex; align-items: center; justify-content: center` on overlay
- Positioned absolutely within flex context (no top/left calc needed)

**Header Section:**
- Flex row: title (flex: 1) | close button (flex-shrink: 0)
- Border-bottom: `1px solid var(--color-separator)` for visual division
- Margin-bottom: `var(--spacing-4)` = 16px
- Title: `font-size: var(--font-size-lg)`, `font-weight: semibold`
- Close button: ghost variant (transparent, accent on hover), uses "✕" character (U+2715)

**Animations:**
1. **Overlay fade-in** (0.2s ease)
   - `@keyframes fadeIn`: opacity 0 → 1
   - Applied to `.modal-overlay`
   - Smooth backdrop darkening effect

2. **Content slide-up** (0.2s ease)
   - `@keyframes slideUp`: `translateY(20px) opacity(0)` → `translateY(0) opacity(1)`
   - Applied to `.modal-content`
   - Parallels iOS sheet/modal presentation behavior

**Body Content Slot:**
- Default `<slot />` for flexible content
- Padding/margin inherited from parent Card (all children receive consistent spacing)
- Color: `var(--color-text-primary)` inherited from CSS cascade

**Body Scroll Prevention:**
- Escape key closes modal (via keydown event listener)
- `document.body.style.overflow = 'hidden'` when open (prevents background scroll)
- Cleanup in `$effect` return: removes listener + resets overflow on unmount
- Pattern: React-style cleanup function in Svelte 5

### Component Props
```typescript
interface ModalProps {
  isOpen: boolean;           // controls visibility (renders nothing if false)
  onClose: () => void;       // callback on close (Escape key or background click)
  title: string;             // modal header text
}
```

### Svelte 5 Patterns Used
- `$props()` for destructuring with type safety
- `$effect()` with cleanup function for keyboard + scroll management
- Conditional rendering: `{#if isOpen}` (no DOM when closed)
- Event stop propagation: `on:click={(e) => e.stopPropagation()}` on content (prevents bubbling to overlay)
- Slot: `<slot />` for body content

### Accessibility
- `role="presentation"` on overlay (not interactive, just visual)
- Close button: `aria-label="Close modal"` for screen readers
- Escape key: standard keyboard interaction
- Focus trap: parent component responsibility (not implemented in Modal itself)

### Design Token Integration
- Colors: `--color-separator`, `--color-text-primary`, `--color-background-secondary` (via Card)
- Spacing: `--spacing-3` (header padding), `--spacing-4` (content gaps)
- Border-radius: inherited from Card component
- Shadow: inherited from Card component
- Animations: custom keyframes (fadeIn 0.2s, slideUp 0.2s)

### Dependencies
- Imports: Button, Card from shared/components
- No external libraries
- Uses native DOM APIs: `document.addEventListener`, `document.body.style`

### Files Created
- `src/views/shared/components/Modal.svelte` (93 lines)

### Next Steps (Tasks 19, 20, 21, 24)
- Task 19: SettingsShell will use Modal for browser/rule edit dialogs
- Task 20: SettingsPanel will wire Modal open/close state
- Task 21: BrowsersPanel will render Modal for add/edit browser
- Task 24: RulesPanel will render Modal for add/edit rule
- Task 24+: ConfigureRuleView (in-modal form) depends on Modal being ready

## Task 14: RuleRow Component

### What we built
✓ `src/views/settings/components/RuleRow.svelte` — editable row for routing rule in Settings Rules tab

### Key Design Decisions

**Layout: 4-Column Grid**
- Column 1 (44px): Toggle switch for enable/disable
- Column 2 (flex-1): Rule name + host pattern (vertical stack)
- Column 3 (auto, ~120px min): Browser name (target browser)
- Column 4 (auto): Action buttons (edit, duplicate, delete)
- Grid gaps: `var(--spacing-3)` = 12px between columns
- Row height: 60px (comfortable touch target)
- Padding: `var(--spacing-3)` = 12px all sides

**Visual States:**

1. **Default (unselected)**
   - Background: `var(--color-background)` (white)
   - Border-bottom: 1px `var(--color-separator)` (light gray)
   
2. **Hover**
   - Background: `var(--color-background-secondary)` (light gray)
   - Smooth transition: 0.2s ease

**Name & Pattern Section (Column 2):**
- Rule name: 14px semibold, primary text color, single line
- Host pattern: 12px monospace, secondary text color, truncated at 40 chars with ellipsis
- Full pattern shown in `title` attribute for hover tooltip
- Flex column with `gap: var(--spacing-1)` = 4px

**Browser Name (Column 3):**
- 14px regular weight, secondary color (gray)
- Min-width: 120px to prevent wrapping
- Aligns with flex layout

**Action Buttons (Column 4):**
- Three ghost variant buttons (Edit ✏️, Duplicate 📋, Delete 🗑️)
- Small size (32px height)
- Emoji icons for quick visual recognition
- Gap between buttons: `var(--spacing-2)` = 8px
- Hover state inherited from Button component

**Component Props**
```typescript
interface RuleRowProps {
  rule: {
    id: string;
    name: string;
    hostPattern: string;
    browserName: string;
    isEnabled: boolean;
  };
  onToggle: (ruleId: string, enabled: boolean) => void;
  onEdit: (ruleId: string) => void;
  onDuplicate: (ruleId: string) => void;
  onDelete: (ruleId: string) => void;
}
```

**Toggle Integration:**
- Imports Toggle component directly
- Calls `onToggle(rule.id, !rule.isEnabled)` on toggle change
- Width: 44px (matches Toggle width)
- Center-aligned in column via flexbox

**Button Integration:**
- All buttons use ghost variant (transparent background, blue text)
- Small size for compact appearance
- Callbacks: `onEdit(rule.id)`, `onDuplicate(rule.id)`, `onDelete(rule.id)`
- Note: Parent (RulesTab) handles modal open/delete confirmation

**Svelte 5 Patterns Used:**
- `$props()` with destructuring and type safety
- Helper function: `truncatePattern()` for ellipsis formatting
- Class styling with CSS Grid for layout
- Conditional rendering not needed (all UI always present)

**Design Token Integration:**
- Colors: `--color-background`, `--color-background-secondary`, `--color-separator`, `--color-text-primary`, `--color-text-secondary`
- Spacing: `--spacing-1` (column internal), `--spacing-2` (button gaps), `--spacing-3` (row padding)
- Font sizes: `--font-size-xs` (pattern), `--font-size-sm` (name)
- Font family: `--font-family-mono` for host pattern (clarity)
- Transitions: 0.2s ease on background (hover state)

**Dependencies**
- Imports: Toggle, Button from shared/components
- No external libraries or custom utilities

### Files Created
- `src/views/settings/components/RuleRow.svelte` (90 lines including styles)

### Next Steps
- Task 21 will create RulesTab.svelte that loops over rules and renders RuleRow for each
- RuleRow is purely presentational; RulesTab handles state management and callbacks
- Edit/delete modals will be built in parent component (Task 21)

## Task 13: IconsLayout Component

### What we built
✓ `src/views/picker/layouts/IconsLayout.svelte` — horizontal scrollable browser icon grid with keyboard navigation

### Key Design Decisions

**Layout Architecture:**
- Flex row with horizontal overflow scrolling
- Container: flex-direction: row, overflow-x: auto, scroll-behavior: smooth
- Icons: flex-shrink: 0 to prevent collapsing in scrollable context
- Gap: `var(--spacing-3)` = 12px between icons (matches Swift version)

**Size System:**
- Delegates to BrowserIcon component prop (small/medium/large)
- Small = 24px, medium = 32px, large = 48px
- Icon label width: 48px (accommodates largest icon + padding)

**Visual States:**
1. **Unselected**
   - Transparent background on button
   - BrowserIcon has no accent ring

2. **Selected**
   - `class:selected` binding passed to BrowserIcon
   - BrowserIcon renders 2px accent ring automatically
   - Button opacity remains 1.0

3. **Hover**
   - Button opacity: 0.8
   - Smooth 0.2s transition

**Keyboard Navigation:**
- ArrowRight: Move to next browser (wraps to first at end)
- ArrowLeft: Move to previous browser (wraps to last at start)
- Uses `$derived` for reactive selected index tracking
- `scrollIntoView()` uses `inline: 'center'` to center selected icon in viewport

**Component Props:**
```typescript
interface IconsLayoutProps {
  browsers: Browser[];             // array of browser objects
  selectedBrowserId: string | null; // ID of currently selected browser
  size?: 'small' | 'medium' | 'large';  // icon size (default: 'medium')
  showLabels?: boolean;             // show/hide labels below icons (default: false)
  onSelect: (browser: Browser) => void;  // callback when icon clicked or arrow key navigates
}
```

**Labels:**
- Hidden by default (showLabels: false)
- Rendered below icon when enabled
- Font: --font-size-xs (12px), medium weight
- Truncation: text-overflow: ellipsis for overflow text
- Width: 48px centered, allows single-line overflow handling

**Scrollbar Styling:**
- Firefox: scrollbar-width: thin, scrollbar-color uses --color-control-border
- Chrome/Safari: ::-webkit-scrollbar* pseudo-elements with 6px height
- Matches design system (thin, subtle)

**Event Handling:**
- Click: `handleIconClick()` → `onSelect(browser)`
- Keyboard: `handleKeydown()` attached via `$effect` with cleanup
- Both trigger scroll into view after selection change

**Svelte 5 Patterns:**
- `$props()` for destructuring with type safety
- `$derived` for computed selectedIndex (updates reactively when browsers/selectedBrowserId change)
- `$state` for containerRef (DOM element reference)
- `$effect` with cleanup function for keyboard listener
- Named slot via `<slot />` mechanism (not needed here; content generated from props)
- Conditional rendering: `{#if showLabels}` for optional labels
- Class binding: `class:selected={...}` for reactive styles

**Design Token Integration:**
- Colors: --color-control-border (scrollbar), --color-accent (focus ring)
- Spacing: --spacing-2 (icon-to-label gap), --spacing-3 (inter-icon gap)
- Border-radius: --radius-md (button focus ring)
- Typography: --font-size-xs, --font-weight-medium (labels)
- Animations: 0.2s ease transitions, smooth scroll-behavior

**Dependencies:**
- Imports: BrowserIcon from ../../shared/components/BrowserIcon.svelte
- No external libraries; uses native DOM APIs (scrollIntoView, addEventListener)
- CSS imports: tokens.css for design variables

### Component Behavior Flow

1. **Render:**
   - For each browser in array, render icon-item container
   - Inside: button wrapping BrowserIcon + optional label div

2. **Click on icon:**
   - `handleIconClick()` called
   - Calls `onSelect(browser)` callback
   - Parent updates selectedBrowserId
   - Icon highlights via `isSelected` prop propagation

3. **Keyboard navigation:**
   - User presses ArrowLeft/ArrowRight
   - `handleKeydown()` computes next/prev index (with wrap-around)
   - Calls `onSelect()` to update selection
   - Calls `scrollIntoView()` to center selected icon
   - Listener attached on mount, removed on unmount

4. **Scroll behavior:**
   - When users have many browsers (>8), horizontal scroll appears
   - Scrollbar is thin and subtle
   - Keyboard navigation auto-scrolls selected icon into center of viewport

### Files Created
- `src/views/picker/layouts/IconsLayout.svelte` (198 lines)

### Next Steps
- Task 17 will integrate this into PickerView (alongside ListLayout for dual-mode support)
- Task 18 will wire keyboard shortcuts (1-9) to directly select browsers
- Parent component (PickerView) manages selectedBrowserId state and layout mode preference
- Layout mode is user-configurable (icons vs list) from Settings

### Technical Notes

**Accessibility:**
- `aria-label` on button (browser name) for screen readers
- `aria-pressed` reflects selection state
- `title` attribute shows full browser name on hover (fallback tooltip)
- Focus ring uses 2px accent color for high contrast

**Performance:**
- BrowserIcon is small component (memoization not needed)
- Keyboard listener attached once via $effect (cleanup prevents leaks)
- No complex animations or transitions (only 0.2s opacity)
- Derived selected index updates reactively without re-renders

**Cross-browser compatibility:**
- scrollIntoView() options: behavior: 'smooth' + block/inline parameters (widely supported)
- ::-webkit-scrollbar* only works in Chrome/Safari (Firefox uses scrollbar-width/color)
- Flex layout is standard CSS (good browser support)


## Task 24: QuickRuleSheet Component

### What we built
✓ `src/views/picker/components/QuickRuleSheet.svelte` — modal for creating routing rules from the picker with automatic host pre-fill

### Key Design Decisions

**Form Fields (Matching Swift ConfigureRuleView)**
1. **Host Pattern Input** (top priority)
   - Auto-filled from URL via `new URL(url).hostname`
   - Editable (user can manually adjust pattern)
   - Required for save validation
   - Uses Input component for consistency

2. **Browser Dropdown**
   - Native `<select>` element (custom styled with SVG arrow indicator)
   - Defaults to first browser in list
   - Always visible
   - Required field (no save without selection)

3. **Profile Dropdown** (conditional)
   - Only rendered if selected browser has `profiles` array
   - Defaults to empty (use default profile)
   - Native `<select>` with custom styling

4. **Private Mode Toggle**
   - iOS-style Toggle component (44×24px)
   - Positioned right-aligned next to label
   - Defaults to unchecked

**Svelte 5 Patterns Used**
- `$props()` with destructured interface (all 5 props)
- `$state()` for mutable form fields (host, selectedBrowserId, selectedProfile, isPrivate)
- `$derived()` for computed values:
  - `selectedBrowser`: find browser by id
  - `hasProfiles`: check if selected browser has profiles array
  - `canSave`: validation (host non-empty AND browser selected)
- `$effect()` for initialization (parse URL hostname on modal open)
- `$effect()` for reset profile when browser changes

**State Management Logic**
1. On `isOpen` change to true:
   - Parse hostname from URL using `new URL(url).hostname`
   - Set first browser as default if not already selected
   - Reset private mode to false
   - Fallback to empty host if URL parse fails

2. When browser selection changes:
   - Clear profile selection (reset to default profile)
   - Prevents stale profile from different browser

3. On save or cancel:
   - Reset all form state (host, browserId, profile, isPrivate)
   - Call respective callbacks (onSave/onCancel)

**Styling Strategy**
- Flex column layout with `var(--spacing-4)` (16px) gaps between sections
- Select dropdowns use custom SVG arrow (down chevron)
- Arrow color updates for dark mode (light blue in dark mode, regular blue in light)
- Focus state: border accent color + 2px shadow (matches Input component)
- Toggle positioned right with flex layout for horizontal alignment

**Component Interface**
```typescript
interface QuickRuleSheetProps {
  isOpen: boolean;
  url: string;
  browsers: Browser[];
  onSave: (rule: {
    host: string;
    browserId: string;
    profile?: string;
    isPrivate: boolean;
  }) => void;
  onCancel: () => void;
}
```

**Validation**
- Save button disabled unless: `host.trim().length > 0 && selectedBrowserId.length > 0`
- Profile is optional (profile defaults to undefined if empty string)
- Prevents save with empty host or missing browser

### Technical Decisions

1. **URL Parsing**
   - Uses `new URL(url).hostname` for RFC-compliant hostname extraction
   - Wrapped in try/catch (fallback to empty string if parse fails)
   - Matches Swift version pattern

2. **Profile Conditional Rendering**
   - Only rendered if `selectedBrowser?.profiles` exists AND has length > 0
   - Uses optional chaining to prevent errors
   - Prevents UI clutter when browser has no profiles

3. **Select Element Styling**
   - Native `<select>` (not custom component) for native look/feel
   - Custom SVG arrow overlay (background-image)
   - `appearance: none` to remove native arrow
   - `padding-right: var(--spacing-6)` for arrow space
   - Arrow color changes for dark mode via @media query

4. **Form Reset**
   - Resets after both save AND cancel (user expects clean slate on next open)
   - Prevents form state bleeding between uses

### Design Token Integration
- All colors: semantic variables (--color-accent, --color-text-primary, etc.)
- Spacing: 4px unit system (--spacing-1 through --spacing-6)
- Typography: --font-size-sm/base, --font-weight-medium/semibold
- Border radius: --radius-md (8px)
- Transitions: 0.2s ease

### Dependencies
- Modal (wrapper)
- Input (host field)
- Button (cancel/save)
- Toggle (private mode)
- All styled with design tokens (no hardcoded colors)

### Files Created
- `src/views/picker/components/QuickRuleSheet.svelte` (256 lines)

### Verification
✓ Build passed: `npm run build` with zero errors
✓ No TypeScript errors
✓ All Svelte 5 runes used correctly ($props, $state, $derived, $effect)
✓ Form validation working (save button disabled until valid)
✓ URL hostname parsing working
✓ Conditional profile rendering working
✓ Dark mode SVG arrow color change via @media query

### Next Steps
- Task 18 will wire this to PickerView (R key opens QuickRuleSheet)
- Task 18 will pass intercepted URL and browsers array as props
- Task 18 will handle onSave callback (create rule + close picker)
- Task 18 will handle onCancel callback (close sheet)

## Task 18: Picker Keyboard Handling + App.svelte Full Implementation

### What we built
✓ `src/views/picker/App.svelte` — Complete picker entry point with Electrobun RPC wiring and all keyboard shortcuts

### Electrobun Webview RPC Pattern
```typescript
// 1. Define schema (mirrors PickerSchema in src/bun/index.ts)
type PickerSchema = ElectrobunRPCSchema & {
  bun: { requests: { methodName: { params: T; response: R } }; messages: Record<string, never> };
  webview: { requests: Record<string, never>; messages: { refreshPicker: undefined } };
};

// 2. Create RPC with message handlers
const rpc = Electroview.defineRPC<PickerSchema>({
  handlers: { messages: { refreshPicker: () => loadPickerData() } }
});

// 3. Instantiate Electroview
const electroview = new Electroview({ rpc });

// 4. Make requests
const data = await rpc.request('methodName', params);
```

### Keyboard Handling Architecture Decision
- **All shortcuts in `App.svelte` only** — do NOT duplicate arrow key logic
- Arrow keys are deliberately NOT handled in App.svelte (delegated to layouts)
  - `IconsLayout.svelte` handles left/right arrows
  - `ListLayout.svelte` handles up/down arrows
- When `showQuickRuleSheet` is true, early return at top of `handleKeydown` — modal manages its own keys

### Keyboard Shortcut Map
| Key | Action |
|-----|--------|
| 1-9 | Open browser matching `shortcutKey` |
| Enter / Space | Open `selectedBrowserId` |
| Option+Enter | Open `selectedBrowserId` in private mode |
| Escape | `rpc.request('dismissPicker', undefined)` |
| P | Toggle `isPrivateMode` |
| H / S | Trigger `handleUnshorten()` |
| R | Set `showQuickRuleSheet = true` |
| Tab / Shift-Tab | Cycle selection (wraps around) |
| Letter key | Find first browser where `name.toLowerCase().startsWith(key)` |

### Pre-existing Build Issues Fixed (not in App.svelte)
1. **`IconsLayout.svelte` line 3**: Had malformed `import '@import "../../shared/tokens.css";'` — removed
2. **`BrowserIcon.svelte` lines 32, 37**: Had JSX-style comments `{/* ... */}` — converted to `<!-- -->`

### PickerShell Named Slot Usage in Svelte 5
PickerShell still uses old `$$slots.url` detection / `<slot name="url">` API. In Svelte 5, pass named content with snippet syntax:
```svelte
<PickerShell>
  {#snippet url()}
    <UrlBubble ... />
  {/snippet}
  <!-- default slot content here -->
</PickerShell>
```
This is backward-compatible with the old Svelte 4 slot API inside PickerShell.

### QuickRuleSheet Browser Prop Mapping
QuickRuleSheet expects `{ id, name, appId }` objects, not full `BrowserConfig`. Map before passing:
```svelte
browsers={browsers.map(b => ({ id: b.id, name: b.name, appId: b.appId }))}
```

### Build Output
- `build/views/picker.js` 29.59 kB (gzip: 11.80 kB)
- `build/views/picker.css` 16.29 kB (gzip: 3.39 kB)
- 142 modules transformed, zero errors

### Files Modified
- `src/views/picker/App.svelte` — Complete rewrite (360 lines)
- `src/views/picker/layouts/IconsLayout.svelte` — Fixed syntax error (malformed import line 3)
- `src/views/shared/components/BrowserIcon.svelte` — Fixed JSX comment syntax
