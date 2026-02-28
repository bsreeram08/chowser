<!-- Last verified: 2026-02-28 against commit 892fcaf -->

# Maintenance Guide

When and how to update each `.context/` file, and how they relate to other documentation.

## Update Triggers

| File | Update when... |
|------|---------------|
| `architecture.md` | A new source file is added or removed; data models change; a new persistence key is added; the URL handling flow changes |
| `decisions.md` | A significant architectural choice is made (new pattern, technology swap, intentional deviation); an existing decision is reversed |
| `patterns.md` | A new recurring pattern emerges (used in 2+ places); an existing pattern is abandoned; a convention changes |
| `gotchas.md` | A new platform quirk is discovered; a workaround is added or removed; a gotcha is resolved by an OS update |
| `quick-reference.md` | A new UI testing flag is added; a keyboard shortcut changes; a browser is added to the support matrix; an accessibility identifier is added; build commands change |
| `_maintenance.md` | A new `.context/` file is added; the relationship between docs changes; update triggers change |

## Verification Steps

### Quick Check (< 5 min)
1. Open `architecture.md` — verify the file map covers all `.swift` files in `Chowser/`
2. Open `quick-reference.md` — verify the UI testing flags match `AppEnvironment.swift`
3. Open `gotchas.md` — pick any 2 entries and confirm the referenced code still exists

### Full Audit (15-30 min)
1. Run `find Chowser -name '*.swift' | sort` and compare against `architecture.md` file map
2. Check each UserDefaults key in `quick-reference.md` against `BrowserManager.swift` and `OnboardingManager.swift`
3. Verify browser support matrix against `BrowserManager.swift` `BrowserFamily` enum
4. Read `decisions.md` and confirm each "References" section points to existing code
5. Verify `patterns.md` examples compile conceptually against current code

### Staleness Indicators

| Indicator | Check |
|-----------|-------|
| New `.swift` file not in `architecture.md` | `diff <(find Chowser -name '*.swift' \| sort) <(grep -oP '`[^`]+\.swift`' .context/architecture.md \| sort)` |
| New UserDefaults key | Search for `UserDefaults` or `forKey:` in source, compare with `quick-reference.md` |
| New `AppEnvironment` flag | Compare `AppEnvironment.swift` properties with `quick-reference.md` flags table |
| New keyboard shortcut | Compare `ContentView.swift` keycode handling with `quick-reference.md` shortcuts table |
| New accessibility ID | Search for `accessibilityIdentifier` in source, compare with `quick-reference.md` |

## Relationship to Other Docs

| Doc file | Scope | Overlap with `.context/` |
|----------|-------|-------------------------|
| `CLAUDE.md` | AI-assistant guidance: build commands, key files, critical patterns | `architecture.md` (file map subset), `quick-reference.md` (commands) — CLAUDE.md is a curated summary; `.context/` is exhaustive |
| `README.md` | End-user documentation: features, installation, usage | Minimal overlap — README is user-facing; `.context/` is developer-facing |
| `.agents/workflows/` | Reusable workflow templates | `docs-sync.md` can be used to update `.context/` files; `project-memory.md` describes how `.context/` was generated |

### Division of Responsibility

- **CLAUDE.md** answers: "How do I build this? What are the key files? What patterns must I follow?"
- **README.md** answers: "What is this app? How do I install it? What can it do?"
- **`.context/`** answers: "Why was it built this way? What will surprise me? What are the exact details?"

When updating docs, apply changes to the narrowest scope:
- New feature visible to users → `README.md`
- New file or changed flow an AI needs to know → `CLAUDE.md`
- Architectural decision, pattern, or gotcha → `.context/`
- If a change spans multiple docs, update all of them in the same commit

## File Dependencies

```
_maintenance.md (this file)
  └── references all other .context/ files

architecture.md
  └── referenced by decisions.md (for file locations)
  └── referenced by patterns.md (for examples)

decisions.md
  └── cross-references gotchas.md (related pitfalls)
  └── references specific files from architecture.md

patterns.md
  └── references architecture.md file map for locations
  └── cross-references decisions.md for "why" behind patterns

gotchas.md
  └── cross-references decisions.md for design rationale
  └── references quick-reference.md for workaround details

quick-reference.md
  └── standalone; no dependencies on other .context/ files
```
