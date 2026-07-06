# TODOs

Deferred work surfaced during `/autoplan` review of `ADVANCED_ROUTING_PRD.md` (2026-07-06).

## Import/translate Finicky JS configs into typed rules

**What:** A one-time importer that parses a common subset of Finicky's `.finicky.js` config (host/pattern matchers, browser choice) and translates it into Chowser's typed `BrowserRoutingRule`/`URLRewriteRule` model.
**Why:** Real bridge for users switching from Finicky — removes the "I already wrote this in JS" migration cost.
**Pros:** Could meaningfully grow adoption from Finicky's existing user base; validates the "typed rules cover what JS configs cover" positioning claim directly.
**Cons:** Needs a JS-subset parser (real engineering cost, not a settings toggle); Finicky configs can express arbitrary logic Chowser's typed model can't represent 1:1 — partial-import UX needs its own design.
**Context:** Surfaced by the CEO review's 10x-check during Advanced Routing planning. Not blast-radius for this PRD (doesn't touch existing routing/rewrite code, purely additive import tooling).
**Effort:** L (human) → M (CC+gstack).
**Priority:** P3.
**Depends on:** Phase 3 (typed rewrites) shipping first, so there's a target model to import into.

## Evaluate sandboxed predicate-only match scripting

**What:** A single sandboxed expression (not full JS) allowed only in a rewrite/routing rule's *match* condition — no actions, crash-isolated, similar to what Finicky does for its match functions.
**Why:** The CEO review flagged this as a real alternative to "typed conditions only" that was folded into the "no JS config" non-goal without being evaluated on its own — match-only scripting is a materially smaller sandbox/support surface than full config-as-code.
**Pros:** Could cover match patterns the typed `hostPattern`/`pathPrefix`/`sourceAppBundleIDs` model can't express (e.g. compound boolean logic across multiple fields).
**Cons:** Any sandboxed-eval feature reopens App Store review risk and the "how do we explain this in Settings" support burden the PRD explicitly wants to avoid; typed conditions may already cover the real cases once rewrite rules ship and usage data comes in.
**Context:** Only worth revisiting if Phase 3's typed match conditions prove insufficient for real use cases surfaced post-ship.
**Effort:** M (human) → S (CC+gstack) for a spike; L for a shippable version.
**Priority:** P3.
**Depends on:** Phase 3 shipping and generating real "I can't express this rule" feedback.

## Auto-run rewrite tester against recent URL history

**What:** When a rewrite rule is created/edited, automatically run the tester against `DomainFrequencyTracker`'s recent-URL history to show which existing links would change, instead of requiring the user to manually paste test URLs.
**Why:** Surfaced as a CEO-review cherry-pick candidate — makes the "what will this rule actually affect" question answerable without manual testing.
**Pros:** Higher confidence before saving a rewrite rule; reuses existing recent-URL infra.
**Cons:** Touches 3-5 files (tester UI, `DomainFrequencyTracker` read path, rule editor) — borderline blast radius, not a trivial addition like the other Phase 3 cherry-picks.
**Context:** Deferred rather than bundled into Phase 3 scope because it's genuinely optional polish, not core to shipping the rewrite engine.
**Effort:** M (human) → S (CC+gstack).
**Priority:** P3.
**Depends on:** Phase 3 (rewrite tester) shipping first.

## Fix chowser-electrobun README's stale "full feature parity" claim

**What:** `chowser-electrobun/README.md` claims "Full feature parity across all platforms," but the directory has been untouched since 2026-03-26 while the native Swift app shipped v3.7.1, v3.7.2, and v3.8.0 since then. The claim is now false.
**Why:** Stale documentation makes false promises to anyone (including future-you) evaluating the cross-platform build.
**Pros:** Cheap, one-line fix; prevents confusion about platform strategy going forward.
**Cons:** None.
**Context:** Surfaced during `/autoplan` CEO review of `ADVANCED_ROUTING_PRD.md`. Advanced Routing PRD now states platform scope is native-macOS-only and Electrobun is paused — this TODO is just the doc cleanup that follows from that decision.
**Effort:** S (human) → S (CC+gstack, minutes).
**Priority:** P2.
**Depends on:** None.
