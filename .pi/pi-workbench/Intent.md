> Status: Approved
> Updated: 2026-08-26T06:51:58Z

# Intent: Establish Pi Project Knowledge and Review Current Chowser

## Outcome

Create a durable, searchable Pi knowledge surface for Chowser and perform an evidence-backed review of the current implementation at commit `70ea7855187a51c33a8c214ee1581ab7f05589e3` on branch `work/catalog-trust-native-routing`.

## In Scope

- Record current architecture, trust boundaries, source-of-truth hierarchy, verification evidence, and an actionable backlog under `.pi/`.
- Review correctness, privacy, maintainability, test coverage, catalog trust, native routing, persistence, MCP, AppKit lifecycle, and distribution separation.
- Preserve durable evidence-backed project facts in Workbench memory.
- Index project documentation and relevant source for focused retrieval.
- Keep prior decisions in `decisions.md`; do not silently convert historical recommendations into approved product decisions.

## Non-Goals

- No production code fixes in this pass.
- No release-readiness, notarization, or App Store submission verdict.
- No claim that UI behavior is verified unless UI tests execute successfully.
- No wholesale duplication of source or `.context/` into `.pi/`; use concise summaries and pointers.

## Evidence Standard

- Every finding must cite current `file:line` evidence.
- Separate confirmed defects, maintainability risks, stale documentation, and unverified runtime behavior.
- Source and executable tests outrank derived documentation.
- A delegated claim is advisory until the Coordinator verifies it against the workspace or a reproducible command.

## Success Criteria

- `.pi/README.md` explains the memory surface and authority order.
- Architecture, review, backlog, verification, decisions, and maintenance documents exist under `.pi/pi-workbench/`.
- High-priority findings are evidence-backed and ordered.
- Relevant project content is indexed and searchable.
- Durable project memories are recorded without secrets or transient chatter.
- Verification status and remaining uncertainty are explicit.

<!-- Last verified: 2026-08-26 against commit 70ea785 -->
