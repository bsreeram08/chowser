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
