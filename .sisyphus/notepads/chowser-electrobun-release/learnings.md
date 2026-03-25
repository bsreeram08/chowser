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
