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
