# Chowser Pi knowledge

This directory is the project-local memory surface for Pi. It records current intent, durable decisions, a concise architecture map, verified review findings, verification evidence, and the actionable backlog.

## Read order

1. [`pi-workbench/Intent.md`](pi-workbench/Intent.md) — current objective and completion criteria.
2. [`pi-workbench/project-context.md`](pi-workbench/project-context.md) — system map, trust boundaries, and source-of-truth pointers.
3. [`pi-workbench/codebase-review.md`](pi-workbench/codebase-review.md) — current-HEAD findings and strengths.
4. [`pi-workbench/backlog.md`](pi-workbench/backlog.md) — ordered follow-up work.
5. [`pi-workbench/verification.md`](pi-workbench/verification.md) — commands and evidence status.
6. [`pi-workbench/decisions.md`](pi-workbench/decisions.md) — chronological user and council decisions.
7. [`pi-workbench/maintenance.md`](pi-workbench/maintenance.md) — update triggers and staleness rules.

## Source hierarchy

When documents disagree, use this order:

1. Current source code and executable tests.
2. User-approved decisions in `pi-workbench/decisions.md`.
3. Accepted ADRs in `docs/adr/`.
4. Domain language in `CONTEXT.md`.
5. Project operating guidance in `AGENTS.md`.
6. `.context/` onboarding documents, which are derived caches and may be stale.
7. `ADVANCED_ROUTING_PRD.md`, which is a historical draft unless a decision explicitly makes a section binding.

## Managed files

`pi-workbench/qmd.json` and `pi-workbench/session.json` are Workbench state. Treat them as tool-managed. Human-authored knowledge belongs in Markdown files beside them.

<!-- Last verified: 2026-08-26 against commit 70ea785 -->
