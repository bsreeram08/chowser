# Pi Knowledge Maintenance

## Update triggers

| Change | Review these files |
|---|---|
| Incoming URL order, command handling, shortlinks, native routing | `project-context.md`, `codebase-review.md`, `CONTEXT.md`, ADR 0001/0005 |
| Browser/rule/rewrite persistence or import | `project-context.md`, `codebase-review.md`, `.context/architecture.md`, `.context/gotchas.md` |
| MCP routes, authentication, or framing | `project-context.md`, `codebase-review.md`, `AGENTS.md` |
| App/Menu Bar mode or window lifecycle | `project-context.md`, `AGENTS.md`, `.context/architecture.md`, `.context/decisions.md` |
| Direct/App Store targets, Sparkle, entitlements | `project-context.md`, `verification.md`, `DISTRIBUTION.md` |
| Tests or CI workflows | `verification.md`, `backlog.md`, `AGENTS.md` |
| A finding is fixed or rejected | `codebase-review.md`, `backlog.md`, `decisions.md`, Workbench memory |

## Verification discipline

1. Record the exact commit.
2. Verify changed claims against source and executable tests.
3. Update `Last verified` metadata.
4. Keep one source of truth; prefer pointers over copied implementation detail.
5. Mark runtime behavior unverified when tests or platform checks did not execute.
6. Preserve only durable, evidence-backed facts in Workbench memory.
7. Re-index changed knowledge files after material updates.

## Staleness rules

- A review is a snapshot, not a permanent verdict.
- Line references are approximate after source changes; the commit hash is the reproducibility anchor.
- `qmd.json` and `session.json` are tool-managed.
- `.context/` is a derived onboarding cache and must not outrank current source or ADRs.
- `ADVANCED_ROUTING_PRD.md` remains historical unless a decision explicitly promotes requirements from it.

<!-- Last verified: 2026-08-26 against commit 70ea785 -->
