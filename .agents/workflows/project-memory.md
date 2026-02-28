---
description: Generate a standalone project memory bank in .context/ for onboarding and AI context
---

# Project Memory

I will help you create a `.context/` directory that captures the architectural decisions, patterns, gotchas, and operational knowledge that source code alone cannot convey. This memory bank is designed for both human onboarding and AI-assisted development.

## Guardrails
- Thoroughly explore the codebase before writing anything — never generate from assumptions
- Every claim must be verified against actual source code with file and line references
- Focus on the "why" — code already shows the "what"
- Never duplicate content that belongs in README or CLAUDE.md; link to those instead
- Every file must include a "Last verified" date so staleness is detectable
- Keep files concise; prefer tables and bullets over prose

## Steps

### 1. Explore the Codebase

Before generating any documentation:
- Read every source file (or at minimum every file's public interface)
- Map the dependency graph (what imports what)
- Identify entry points, data flow, and system boundaries
- Check git history for significant refactors and the reasoning behind them
- Read existing docs (README, CLAUDE.md, CONTRIBUTING, ADRs) to avoid duplication

### 2. Create `.context/` Directory

Generate six files in `.context/`:

#### `architecture.md` — System Map
- High-level component diagram (ASCII or description)
- Data flow from entry point to output
- Complete file-to-responsibility mapping (every source file, grouped by role)
- Data models and their relationships
- Persistence strategy and storage locations
- External dependencies and integration points

#### `decisions.md` — Decision Log
- One section per significant architectural decision
- Each entry must include:
  - **Context**: What problem was being solved
  - **Options considered**: At least 2 alternatives
  - **Decision**: What was chosen and why
  - **Trade-offs**: What was gained and what was sacrificed
  - **References**: File paths and line numbers where the decision manifests
- Focus on decisions that would surprise a new contributor

#### `patterns.md` — Code Conventions
- Recurring patterns with concrete examples (file + line references)
- Naming conventions, file organization rules
- State management approach
- Error handling strategy
- Testing patterns and conventions
- Anti-patterns that are intentionally avoided (and why)

#### `gotchas.md` — Known Pitfalls
- Platform-specific bugs or quirks that required workarounds
- Subtle interactions between components
- Things that look wrong but are intentional
- Common mistakes new contributors make
- Race conditions, timing issues, or ordering dependencies

#### `quick-reference.md` — Developer Cheat Sheet
- Build, test, and release commands
- Key file paths and directory layout
- Configuration keys and environment variables
- Support matrices (platforms, versions, features)
- Keyboard shortcuts and accessibility identifiers
- Common debugging commands

#### `_maintenance.md` — Self-Maintenance Guide
- What triggers an update to each file
- How to verify each file is still accurate
- Staleness indicators (e.g., "if file X is modified, check section Y")
- Relationship to other doc files (README, CLAUDE.md, etc.)

### 3. Verify Accuracy

For each generated file:
1. Pick 3 random claims and verify them against source code
2. Confirm all file paths referenced actually exist
3. Confirm all line-number references are approximately correct
4. Check that no information contradicts existing docs

### 4. Add Maintenance Metadata

Every `.context/` file must start with:

```markdown
<!-- Last verified: YYYY-MM-DD against commit <short-hash> -->
```

This enables future `docs-sync` runs to detect staleness.

## Principles
- Memory decays — every file needs a verification date
- Onboarding is the primary use case — write for someone seeing the project for the first time
- Link, don't duplicate — if README already covers something, reference it
- Prefer "why" over "what" — the code shows what; context files explain why
- Tables beat prose for reference material
- Keep files independently useful — each should stand alone without requiring the others

## Reference
- Combine with the `docs-sync` workflow to keep `.context/` files up to date
- Use `git log --all --oneline -- <file>` to find when decisions were made
- Use `git blame` to understand why specific code patterns exist
