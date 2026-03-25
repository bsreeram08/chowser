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
