# Pi Workbench Decisions

Decisions are appended here. Each entry records what the user chose and why.

## User checkpoint — 2026-07-12T19:36:38.694Z

**Topic:** review codebase

**User input:**
1. architecture/maintainability, Advanced Routing conformance
2. a version
3. a review

## Council synthesis — 2026-07-12T19:43:16.264Z

## 2026-07-12 — Define the code-review objective

### User-approved decision

Review Chowser for:

- Architecture and maintainability.
- Advanced Routing conformance.
- A particular version.
- A review outcome rather than immediate implementation.

The exact version and review method were not decided.

### Context

The original request, “review codebase,” did not identify the decision to support, target revision, specification boundary, or evidence standard. Early council proposals emphasized release readiness and security, but the user checkpoint selected architecture/maintainability and Advanced Routing conformance instead.

### Alternatives considered

- General whole-codebase health assessment.
- Release-readiness and security audit.
- Architecture orientation only.
- Advanced-Routing-centered architecture and conformance review.
- Current working tree versus an immutable release tag.
- Static inspection versus fresh build and test verification.

### Rationale

A version-specific architecture and conformance review best matches the user’s clarified priorities and avoids diluting the result with unrelated release or style observations.

### Council recommendation — not yet user-approved

- Review immutable tag `v3.9.6`.
- Evaluate Advanced Routing Phases 1–4 and associated cross-cutting requirements.
- Mark Phases 5–7 deferred.
- Prefer ADRs over contradictory Draft PRD text.
- Begin with static inspection and mark runtime behavior unverified.
- Provide a codebase-wide architecture overview with an Advanced Routing deep dive.

### Consequences

- No release-readiness verdict will be implied.
- PRD deviations cannot automatically be called defects while the PRD remains Draft.
- Runtime-dependent conformance will remain unverified unless execution is approved.
- Findings will require evidence of maintenance or conformance impact, not merely stylistic preference.

### Unresolved questions

- Exact tag or commit.
- Binding PRD phases.
- Authority order among user decisions, ADRs, and the Draft PRD.
- Static versus executed verification.
- Architecture-review breadth.
- Status of implementation extensions such as `excludeHostPatterns`.

**User approval:** Approved the edited Intent.md.

## User checkpoint — 2026-07-13T09:40:49.359Z

**Topic:** review codebase

New user context:
verify the implemented changes

**User input:**
Add context, correct assumptions, redirect the council, or write `skip to synthesis`.

## Council synthesis — 2026-07-13T09:48:21.452Z

# Decision Record — Implementation Verification Review

## User-Approved Decisions

The user approved reviewing Chowser for:

- Architecture and maintainability.
- Advanced Routing conformance.
- A particular version.
- A review outcome rather than immediate implementation.

The user then added the context: “verify the implemented changes.”

## Council Recommendation — Not Yet User-Approved

- Review tag `v3.9.6` at `4614a884c97555f314c9e73f287638f047f7d19f`.
- Treat Phases 1–4 as applicable and Phases 5–7 as deferred.
- Prefer user requirements, then ADRs, then the Draft PRD.
- Perform static review plus authorized build/unit verification.
- Treat `excludeHostPatterns` and similar additions as extensions pending confirmation.

## Context

The current request is ambiguous about baseline, binding scope, specification authority, and evidence depth. Static inspection alone cannot establish all macOS runtime behavior.

## Alternatives Considered

- Review current `main` or the working tree.
- Review immutable `v3.9.6`.
- Static-only review.
- Static review plus fresh build/tests.
- Broad codebase audit versus Advanced-Routing-centered review.

## Rationale

An immutable version-specific review best supports reproducibility and prevents later changes from contaminating findings. Explicit evidence labels prevent unsupported runtime or conformance claims.

## Consequences

The review can begin with static evidence, but a final verification verdict may remain limited until the baseline and test scope are confirmed. Draft PRD differences will require classification rather than automatic defect labeling.

## Unresolved Questions

- Exact baseline.
- Binding Advanced Routing phases.
- Authority between ADRs and the Draft PRD.
- Status of implementation extensions.
- Whether fresh build, unit, or UI tests are authorized.

**User approval:** Approved the edited Intent.md.

## Supervisor recommendation — 2026-07-13T10:29:43.251Z

**Phase:** clarification

**Action:** delegate

**Roles:** architecture-maintainability-reviewer, advanced-routing-conformance-reviewer

**Rationale:** Review scope is established: assess implemented changes for maintainability and Advanced Routing PRD conformance.

## Supervisor recommendation — 2026-07-13T10:29:56.099Z

**Phase:** verification

**Action:** verify

**Roles:** independent-verifier

**Rationale:** Verify the implemented changes with one independent specialist before any completion decision.

## Supervisor recommendation — 2026-07-13T10:36:55.257Z

**Phase:** implemented-changes-review

**Action:** review

**Roles:** swift-code-reviewer

**Rationale:** Review the implemented macOS Swift changes against project guidance, evidence, tests, and release behavior; identify correctness, regression, privacy, and App Store compatibility issues before independent verification.

## Supervisor recommendation — 2026-07-13T10:41:12.478Z

**Phase:** implemented-changes-review

**Action:** delegate

**Roles:** swift-code-reviewer

**Rationale:** Review the implemented macOS Swift changes for correctness, maintainability, routing conformance, regressions, privacy, and App Store compatibility before independent verification.

## Supervisor recommendation — 2026-07-13T10:43:34.200Z

**Phase:** clarification

**Action:** ask_user

**Roles:** (none)

**Rationale:** Round 1 confirmed the architecture is reviewable but identified blocking ambiguity about the immutable baseline, binding scope, extension classification, and allowed verification evidence.

**Question:** Confirm the exact baseline (v3.9.6, main, or another commit), whether Phases 1–4 are binding and Phases 5–7 deferred, how ADRs rank against the Draft PRD, and whether fresh build/unit/UI/App Store verification is authorized.

## User checkpoint — 2026-07-13T10:46:45.491Z

**Topic:** review codebase

New user context:
verify the implemented changes

New user context:
review

**User input:**
Confirm the exact baseline (v3.9.6, main, or another commit), whether Phases 1–4 are binding and Phases 5–7 deferred, how ADRs rank against the Draft PRD, and whether fresh build/unit/UI/App Store verification is authorized.

## Supervisor recommendation — 2026-07-13T10:51:48.927Z

**Phase:** clarification

**Action:** ask_user

**Roles:** (none)

**Rationale:** Review scope is clear, but verification requires a reproducible baseline and confirmed specification/test boundaries.

**Question:** Confirm the baseline (v3.9.6, main, or commit), whether Phases 1–4 are binding and 5–7 deferred, ADR precedence, and whether fresh build/unit/UI/App Store verification is authorized.

## Supervisor recommendation — 2026-07-14T08:12:38.715Z

**Phase:** clarification

**Action:** ask_user

**Roles:** (none)

**Rationale:** “Check implementation” is underspecified, and the existing council still lacks a reproducible baseline, binding scope, and verification evidence boundary.

**Question:** What exact baseline should be checked, which implementation scope is in focus, and should verification include a fresh build/unit/UI test run?

## User answer to Supervisor — 2026-07-14T08:13:05.361Z

What exact baseline should be checked, which implementation scope is in focus, and should verification include a fresh build/unit/UI test run? 
council implementation
Ctrl down is not working, it goes to mac's own shortcuts

## Supervisor recommendation — 2026-07-14T08:13:26.116Z

**Phase:** clarification

**Action:** delegate

**Roles:** macos-keyboard-input-specialist

**Rationale:** The implementation’s picker handler explicitly rejects Control-modified arrows, while macOS may consume Control+Down as a global shortcut; one AppKit keyboard specialist should determine the intended mapping and feasible fix scope.

## Supervisor recommendation — 2026-07-14T08:16:23.635Z

**Phase:** clarification

**Action:** ask_user

**Roles:** (none)

**Rationale:** Round 1 clarified the target as an Advanced Routing implementation review and surfaced two preliminary risks, but the immutable baseline, binding phases/spec authority, and verification evidence remain unresolved.

**Question:** Confirm: review v3.9.6 or main; treat Phases 1–4 as binding and 5–7 as deferred with ADRs above the Draft PRD; and authorize fresh build/unit tests, with UI/App Store checks optional.

## User answer to Supervisor — 2026-07-14T14:01:36.504Z

Confirm: review v3.9.6 or main; treat Phases 1–4 as binding and 5–7 as deferred with ADRs above the Draft PRD; and authorize fresh build/unit tests, with UI/App Store checks optional.

## Supervisor recommendation — 2026-07-14T14:01:45.934Z

**Phase:** clarification

**Action:** ask_user

**Roles:** (none)

**Rationale:** The response confirmed Phases 1–4, ADR precedence, deferred Phases 5–7, and fresh build/unit verification. Only the immutable baseline remains ambiguous.

**Question:** Choose exactly one baseline: tag v3.9.6 at 4614a884c97555f314c9e73f287638f047f7d19f, current main at e53bbfab77c53bd2bc04fb593b4634ee253aaab0, or another commit.

## User direction — 2026-08-26

**Topic:** Initialize Pi project knowledge and review the codebase.

**User input:**

> can you start getting everything into .pi/ memory an other stuff. and review codebase

### Session decision

- Establish a project-local Pi knowledge surface under `.pi/`.
- Review the current workspace at commit `70ea7855187a51c33a8c214ee1581ab7f05589e3`.
- Record architecture, findings, verification status, maintenance rules, and an actionable backlog.
- Preserve durable evidence-backed facts in Workbench memory and index project knowledge for retrieval.

### Scope note

Using current HEAD is the reproducibility baseline for this review only. It does not choose a release baseline or resolve the earlier `v3.9.6` versus `main` product question.

<!-- Last verified: 2026-08-26 against commit 70ea785 -->
