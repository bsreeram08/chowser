<!-- /autoplan restore point: /Users/sreeram/.gstack/projects/bsreeram08-chowser/docs-landing-wireframe-improvements-autoplan-restore-20260706-002126.md -->
# Chowser Advanced Routing PRD

Status: Draft  
Date: 2026-07-05  
Release boundary: Post-TestFlight discovery; out of scope for the 3.1.5 TestFlight reactivation unless explicitly reopened.  
Related mockup: `mockups/chowser-routing-ideas.html`  
Platform scope: native macOS (Swift/AppKit/SwiftUI) only. `chowser-electrobun/` (cross-platform Win/Linux/macOS rewrite of the same domain model) is paused/dead as of this PRD — Advanced Routing does not ship there. Its README's "full feature parity" claim is stale; tracked as a doc-cleanup TODO, not this PRD's concern.  

## Summary

Chowser already solves the core problem: intercept a link, route it to a configured browser/profile, or show a picker. The next useful expansion is not "more config." It is a small set of controls that make routing predictable when links are messy, source apps vary, or the user wants a default outcome without seeing the picker.

This PRD proposes adding:

1. Fallback browser behavior when no rule matches.
2. Multiple source apps per routing rule.
3. Typed URL rewrite rules for common transformations.
4. Optional URL editing in the picker before launch.
5. A browser helper entry point for "open this page with Chowser."
6. Explicit privacy controls for network-backed shortlink resolution.
7. Later-stage destination types for desktop apps and mail clients.
8. Later-stage profile polish: Safari profile feasibility, profile identity, and optional profile launcher hotkeys.

The core product decision is to make advanced routing feel native, visual, importable/exportable, and App Store compatible. Chowser should not add a JavaScript configuration engine.

## Problem

Users who need browser routing often need more than domain-to-browser matching:

- Work links may come from Slack, Mail, Linear, GitHub Desktop, or a terminal, but the intended browser is the same.
- Login, redirect, and shortlink URLs may need cleanup before a rule can match.
- Some users want unmatched links to always go to a normal default browser, while others want the picker every time.
- Power users sometimes need to adjust a URL at the moment of opening, not after it lands in the wrong browser.
- Browser-originated pages need a way to re-enter Chowser when the user realizes the active page belongs elsewhere.

Today, these cases are partially handled by tracking cleanup, shortlink support, app-based routing, quick rules, and the picker. The missing piece is making those behaviors visible, configurable, and composable without turning Chowser into a code-driven rules engine.

## Goals

- Give users an obvious fallback choice: picker or configured browser/profile.
- Let a single rule match several source apps.
- Add URL rewrites through typed, inspectable controls.
- Keep rewrite previews understandable before the user saves.
- Keep no-network behavior as the default privacy posture.
- Preserve existing browser/rule import/export compatibility.
- Treat configured browser profiles as first-class destinations across picker, rules, fallback, and tests.
- Keep implementation native to the current SwiftUI/AppKit app.

## Non-Goals

- No JavaScript, TypeScript, Lua, or shell-based configuration engine.
- No user-provided executable rule code.
- No platform-specific installer or registry behavior.
- No hidden auto-sorting of browser choices based on usage.
- No general-purpose request proxying.
- No non-HTTP handler expansion in the first implementation phase.

## Product Decisions

| Idea | Decision | Rationale |
| --- | --- | --- |
| Fallback browser | Build | High value, low complexity, aligns with picker-first users and default-browser users. |
| Multiple source apps per rule | Build | Removes duplicate rules and makes app-based routing feel practical. |
| Typed URL rewrites | Build natively | Solves real routing misses without executable config risk. |
| URL editing in picker | Build carefully | Useful for power users, but should be secondary UI so the picker stays fast. |
| Network shortlink controls | Build | Chowser already unshortens; users need explicit privacy/timeout control. |
| Browser helper extension/bookmarklet | Build later (resolved) | `chowser://open` already exists; Phase 5 ships only a bookmarklet/docs wrapper — see Resolved Decisions. |
| Profile destination polish | Build later (resolved) | Safari profile launch has no public API — resolved as explicitly unsupported, not further explored; markers/hotkeys ship in Phase 6 — see Resolved Decisions. |
| Desktop app and mail destinations | Build later (resolved) | Desktop app deep links ship before `mailto:` in Phase 7 — see Resolved Decisions. |
| JS config files | Do not build | Too much support burden, harder to sandbox, harder to explain in Settings. |

## Users And Use Cases

Primary user: a macOS user with multiple browsers or profiles split across work, personal, client, and testing contexts.

Secondary user: a power user who is comfortable with rules but does not want to maintain code config.

Representative use cases:

- Route all `github.com/org-work/*` links from Slack, Mail, and Linear to Chrome Work.
- Strip tracking parameters before matching and before opening.
- Force `http://localhost:*` links into a development browser.
- Convert known redirect URLs into their target URL before route matching.
- Send unmatched links to Safari Personal without seeing a picker.
- Edit a malformed URL directly in the picker and then open it.
- From the active browser tab, choose "Open with Chowser" to re-route through native rules.
- Tell Work and Personal profiles apart visually in the picker without reading long labels.
- Open a configured browser profile from a global hotkey without first clicking a link.
- Route selected web URLs into installed desktop apps when the user configures an app destination.
- Choose a mail client for `mailto:` links without changing the system default mail app.

## User Experience

`mockups/chowser-routing-ideas.html` is early ideation, not binding spec — it predates and in three places contradicts this PRD's resolved decisions (fallback control widget type, URL field visual weight, Esc key semantics). Where the mockup and this PRD's text disagree, this PRD's text wins. The mockup's own embedded "Keep/Maybe/Skip" evaluation panel is a signal it was a brainstorming artifact, not a final design. Two rows shown in the mockup are explicitly **not** part of this PRD's scope: the "Future destinations" teaser rows (Desktop app target / Mail target) styled as live-looking rows — these must not ship as visually-live UI in Phase 1-4 Settings, since Phase 7 hasn't been built yet and a first-time user would read them as real, half-configured options; and a standalone "Fetch link preview" *feature toggle* (for turning the visual preview UI on/off, independent of privacy) — that's a separate, cosmetic concern from FR-034's privacy gating and stays out of scope here; FR-034 only requires the network fetch inside link preview to respect the same privacy default, not a new UI toggle. The mockup's rewrite-rule "Exception" field (excluding hosts like `localhost`/`*.local` from a rule) is also cut for v1 — rewrite rules match positively only; a more specific host pattern already expresses the same intent, and negative matching adds new `URLRewriteMatch` surface not backed by any FR.

### Settings: Behavior

Add a Behavior section that owns global routing decisions:

- Fallback mode segmented control:
  - Show picker.
  - Open in browser/profile.
- Browser/profile selector when fallback mode is browser.
- Shortlink resolution toggle:
  - Off by default for unknown hosts, and off by default on upgrade for existing installs — this changes today's always-on behavior (see `docs/adr/0003-shortlink-resolution-off-by-default-on-upgrade.md`). Because this is a silent behavior regression for every existing install landing right at TestFlight reactivation, the version that ships this flip must show a one-time notice. Chowser is `LSUIElement` with no guaranteed main window, so a single Settings-only banner isn't guaranteed to be seen — the notice attaches to whichever the user hits first: (a) an inline one-time banner at the top of the picker the next time it appears (the highest-traffic surface, guaranteed for anyone who clicks a link without fallback configured), and (b) a one-time note in Settings > Behavior the first time it's opened post-upgrade (covers users who rarely see the picker because fallback is already configured). Both check the same "seen" flag so it only shows once total, whichever surface is hit first.
  - Built-in shortener list (t.co, bit.ly, etc.) stays fixed; users can only append hosts to it, not remove built-ins.
  - Visible timeout label, default 1.5 seconds — new configurable timeout; today's resolution has no explicit timeout (relies on default `URLSessionConfiguration.ephemeral` behavior).
- Tracking cleanup toggle: simple on/off over the existing hardcoded parameter list, not an editable rule list (see `docs/adr/0002-tracking-cleanup-stays-built-in.md`).
- Every network-touching row (shortlink resolution; any other row that turns out to hit the network) gets the same visual network-indicator affordance (e.g. a small consistent icon or inline label) per FR-033 — not identical-looking switches that only differ in their text description. Purely-local rows (tracking cleanup) do not get this indicator, so its presence/absence is itself the signal.

**Interaction states (design review):** if no browsers are configured, the browser/profile selector under "Open in browser/profile" is disabled with an inline note ("Add a browser to enable fallback") rather than showing an empty dropdown — the fallback mode control itself stays enabled but effectively no-ops back to picker behavior (consistent with FR-003's "fallback browser deleted → show picker" rule, applied to the zero-browsers case too). If the selected fallback browser is later deleted, disabled, or hidden, Settings shows a one-time inline note the next time the section is opened, not a silent revert with no trace.

This is the first feature to ship because it answers the most common unmatched-link question without forcing users into advanced rules.

### Settings: Rules

Extend existing routing rules with a source-app token field:

- Empty source list means any source app.
- One or more app chips means match any listed source app.
- Existing single-source rules migrate into a one-item chip list.
- Rule rows should summarize the source condition compactly, for example `Slack, Mail -> Chrome Work`.

This should replace duplicate app-specific rules, not create another rule type.

### Settings: Rewrites

Add a URL Rewrites section for typed transformations:

- Enabled/disabled rule list.
- Match controls:
  - Host pattern.
  - Optional path prefix.
  - Optional source app condition.
  - Scheme condition.
- Action controls:
  - Force scheme.
  - Replace host.
  - Strip query parameters by name or prefix.
  - Add/replace query parameter.
  - Remove fragment.
- Preview/tester:
  - Input URL.
  - Output URL.
  - Explanation of matched rewrite rules in order.
  - A regex pattern rejected at save time for ReDoS risk (FR-028) can't be saved in the first place, so the tester never needs to represent a "match timed out" state — the editor's save-time validation error is where this surfaces.
  - When 2+ rewrite rules fire in the chain (FR-021), the tester shows each rule's individual before/after step, not one collapsed "Original → Rewrite → Route" summary — e.g. Original → after Rule A → after Rule B → Route, one step per rule that actually fired. Collapsing multi-rule chains into a single step hides the exact behavior (which rule changed what) that the tester exists to make visible.

Rewrite rules should be visible, ordered, and deterministic. They should run before browser-route matching.

**Interaction states (design review):**

| Feature | Empty | Error | Notes |
| --- | --- | --- | --- |
| Rewrite rule list | "No rewrites yet" with one concrete example rule the user can add in one click (e.g. "Strip tracking parameters") — not a bare "No items found" | — | Empty states are a feature, not a placeholder |
| Rewrite rule row | — | Last-skip-reason (FR-024) shown as an inline badge directly on the affected row, matching the mockup's existing chip visual language (e.g. an orange chip reading "Skipped: not http/https") | Must be visible without opening the rule editor |
| Source-app chips (Rules editor) | Zero chips renders as a single non-removable "Any source app" ghost chip, not a blank row | — | Prevents "did this save empty by mistake" confusion |
| Rewrite rule save | — | — | Save button disabled while required match/action fields are incomplete, not just validated after clicking Save |

Rewrite rule reordering must have a keyboard-accessible alternative to drag-and-drop (e.g. a context-menu "Move Up" / "Move Down", or arrow-key reorder while a row is focused) — drag-only reordering has no accessible equivalent.

### Picker

Add URL editing as a power-user affordance:

- The URL displays as static text by default (today's behavior) and only becomes an editable field on an explicit trigger (click on the URL, or a keyboard shortcut) — not a permanently-rendered input that merely toggles read-only, which would make it visually dominant by default and contradict the next point.
- Editing is keyboard reachable but not visually dominant.
- `Return` opens the selected browser with the edited URL.
- `Esc` exits edit mode and reverts to static text, without closing the picker, while editing is active. When not editing, `Esc` closes the picker as it does today. The footer keyboard-shortcut legend must reflect whichever meaning is currently active (e.g. "Esc cancel edit" vs "Esc close") — a static legend that never changes text is itself a spec bug, since the same key means two different things depending on mode.
- If the URL is invalid, show inline validation (a visible message near the field, not just a color change — color alone fails accessibility) and keep the picker open.

The default picker path must remain one-key browser selection. Pre-picker pipeline steps that can take visible time (shortlink resolution, up to the 1.5s timeout) must show a loading state before the picker/route decision appears — a click that produces no visible feedback for up to 1.5s reads as an app hang, not "working as designed."

### Future: Profile Destination Polish

Chowser already stores browser profiles as configured browser entries. Later polish should make that model more obvious:

- Optional per-profile marker such as a short label, color, or symbol.
- Optional global hotkey to open a configured browser/profile without an incoming URL.
- Safari profile feasibility check before any commitment to support it.
- Clear unsupported state if a browser exposes profiles visually but cannot be launched into a specific profile reliably.

This should not become a separate profile manager. It is presentation and launch polish on top of existing `BrowserConfig` entries.

### Browser Helper

`chowser://open?url=<target>` already exists and already validates the target is HTTP/HTTPS before recursing into normal route handling (`AppDelegate.swift:219-226`) — this satisfies FR-053 today, no new Swift code needed for the handoff itself. Remaining work is packaging:

- Ship a bookmarklet and a documented URL-scheme flow pointing at the existing handler.
- Extension only if the lightweight helper proves insufficient.
- Treat `chowser://open?url=...` as the stable public handoff contract.

This should not duplicate rule management in the browser.

### Future: Destination Types

Keep first-pass routing browser/profile-only. After the browser route pipeline is explicit and tested, evaluate a destination picker that can route to:

- Browser/profile.
- Desktop app URL scheme.
- Email client for `mailto:`.
- Send-to-phone (automatic, rule-triggered — distinct from the manual Send to Phone action already shipped in v3.8.0's picker URL bubble; this would let a *routing rule* target a phone automatically instead of requiring the user to click Send to Phone each time).

This should reuse routing rules instead of adding a separate automation model. Each destination type needs its own validation because app URL schemes and mail clients fail differently than browser launches.

## Functional Requirements

### Fallback Routing

- FR-001: The user can choose whether unmatched links show the picker or open in a configured fallback browser/profile.
- FR-002: The fallback browser/profile must use the same browser launch path as normal browser selections.
- FR-003: If the fallback browser is deleted, disabled, or hidden, Chowser must fall back to showing the picker.
- FR-004: Fallback routing must not bypass private-mode choices on matched routing rules.
- FR-005: Existing installs must preserve current behavior by default: unmatched links show the picker.
- FR-006: The existing Hold-Shift-to-force-picker behavior (`AppDelegate.swift:246-248`, already shipped) overrides fallback routing exactly like it already overrides matched routing rules — holding Shift on an unmatched link always shows the picker, even when fallback mode is "open in browser/profile."

### Multiple Source Apps

- FR-010: A routing rule can match zero, one, or many source app bundle IDs.
- FR-011: Zero source apps means "any source app."
- FR-012: A rule matches when the incoming source app is present in the rule source list.
- FR-013: Existing single-source rules migrate without changing behavior.
- FR-014: Import/export must support both the old single-source shape and the new multi-source shape during a compatibility window.

### URL Rewrites

- FR-020: Users can create, enable, disable, reorder, edit, and delete URL rewrite rules.
- FR-021: All enabled rewrite rules whose match condition is satisfied against the *current* URL state fire in user-defined order — this is a chained pipeline (each rule's output feeds the next rule's input), not first-match-wins like routing rules (see `CONTEXT.md`: Routing Rule vs Rewrite Rule).
- FR-022: Rewrite rules run before browser route resolution.
- FR-023: A rewrite rule cannot execute arbitrary code.
- FR-024: A rewrite rule must produce a valid HTTP or HTTPS URL, or it must be skipped. The rule list shows a last-skip reason inline on the affected rule (not just in the tester), so a silently-failing rewrite on a real link is discoverable without re-running the tester with the exact URL.
- FR-025: The rewrite tester must invoke the same rewrite-pipeline function used at runtime — no separate interpreter — and show input URL, output URL, and matched rule order.
- FR-025b: Rewrite pipeline decisions (which rules fired, in what order, on real incoming links) are logged through the existing `AppLogger` "Route" category, same log level as current routing decisions — reuses the diagnostics infra shipped in v3.8.0 rather than adding a separate logging path.
- FR-026: Rewrites must be exportable and importable.
- FR-027: Rewrites must not trigger network calls.
- FR-028: Regex host-pattern matching (`useRegex`, both routing rules and rewrite rules) is a ReDoS-class risk since the *string* tested against a user's own regex is attacker-controlled (any webpage can construct a URL), independent of who authored the pattern. **Corrected mechanism** (a runtime evaluation timeout was considered and rejected — see Architecture Notes): reject dangerous patterns at *save time* via a static complexity heuristic (deny nested quantifiers like `(a+)+`, `(a*)*`, and similar catastrophic-backtracking shapes) when a regex host pattern is entered in the rule/rewrite editor. This is a save-time validation error ("This pattern could cause severe slowdowns — simplify it"), not a runtime behavior change, and keeps `resolvedRoute` synchronous. Applies to both the existing `BrowserRoutingRule.useRegex` matcher and new rewrite matching.

### Shortlink And Privacy Controls

- FR-030: The user can disable automatic network-backed shortlink resolution.
- FR-031: Unknown shortlink hosts are never resolved automatically — resolution only happens for hosts on the allowlist (built-in list plus user-appended hosts, see Settings: Behavior). No separate "explicit user action" prompt path is built for v1.
- FR-032: Resolution must have a short timeout and fail open to the original URL.
- FR-033: The UI must make clear when a feature contacts the network before routing.
- FR-034: **Link preview (already-shipped, `LinkMetadataFetcher.swift`) is a second, previously-unaddressed network path that must respect the same privacy posture as shortlink resolution.** Verified: it performs a full GET (not HEAD) to any non-single-use link's real host and follows redirects, unshortening for free, completely independent of the `shortenerDomains` allowlist — a user who disables shortlink resolution (FR-030) still leaks link destinations over the network via link preview, which defeats this PRD's stated privacy goal. Link preview's fetch must be gated by the same off-by-default-on-upgrade toggle state as shortlink resolution (they can share one user-facing "network lookups" toggle, or link preview can get its own toggle that defaults off under the same upgrade conditions as ADR-0003) — not left as a silent exception. Gets the same FR-033 network indicator.

### Picker URL Editing

- FR-040: The picker can expose an editable URL field.
- FR-041: URL edits apply only to the current launch unless the user creates a rewrite rule. Editing starts from the *post-pipeline* URL (after rewrites/shortlink/cleanup already ran, per the Architecture Notes pipeline step 8), not the original incoming URL — the picker always shows and edits the final URL, consistent with the rewrite trace shown in the same preview area.
- FR-042: Invalid edits must not launch.
- FR-043: Keyboard shortcuts for browser selection must keep working when not editing the URL.

### Browser Helper

- FR-050: A helper entry point can pass a URL to Chowser for normal route processing.
- FR-051: The helper must not maintain separate routing logic.
- FR-052: The helper must work without requiring network access.
- FR-053: The URL-scheme handoff must reject non-HTTP/HTTPS target URLs until non-browser destinations are explicitly supported.

### Future Profile Polish

- FR-070: Browser profiles must be displayed as first-class destinations anywhere a browser can be selected.
- FR-071: A configured browser/profile can have an optional short visual marker for picker scanning.
- FR-072: Safari profile support must ship only if Chowser can launch a selected Safari profile reliably.
- FR-073: If reliable Safari profile launch is unavailable, Settings must not imply support.
- FR-074: Optional global profile hotkeys must open only configured browser/profile entries.

### Future Destination Types

- FR-060: A rule can eventually target a browser/profile, desktop app, mail client, or automatic send-to-phone (rule-triggered, distinct from the manual Send to Phone action shipped in v3.8.0).
- FR-061: Non-browser targets must be disabled unless the target app or handler is installed.
- FR-062: `mailto:` support must not change the user's system default mail client.
- FR-063: Desktop app targets must show the exact URL scheme or app bundle used to launch.

## Architecture Notes

### Current Flow

The current app flow is:

1. macOS opens an HTTP/HTTPS URL through Chowser.
2. `AppDelegate` captures the source app where possible.
3. Existing URL cleanup and shortlink behavior may modify the URL.
4. `BrowserManager.resolvedRoute(for:)` checks routing rules top-to-bottom.
5. A match opens directly; no match shows the picker.

The proposed features should keep this architecture. `BrowserManager` remains the owner of browser, rule, and routing state.

### Proposed Route Pipeline

Use one explicit URL handling pipeline:

1. Receive incoming URL and source app metadata.
2. Normalize URL enough for safe parsing.
3. Apply local URL rewrite rules in order.
4. Optionally resolve shortlinks when allowed by user settings.
5. Apply tracking cleanup (built-in toggle, not user-editable rules — see ADR-0002) to the resolved URL.
6. Resolve browser route against the final URL and source app.
7. If no route matches, apply fallback policy.
8. If fallback policy is picker, present the picker with the final URL.
9. Launch selected browser/profile.

Order is rewrites → shortlink resolution → cleanup (see `docs/adr/0001-route-pipeline-order.md`): local rewrites run first since they're free and may fix the URL before any network call; cleanup runs after shortlink resolution because tracking parameters live on the expanded URL, not the shortlink wrapper, so cleanup before expansion would be a no-op.

A rewrite skipped for invalid output (FR-024) is treated as if the rewrite didn't happen — the original URL proceeds to route resolution and, if unmatched, to fallback like any other unmatched link. No separate error-fallback state.

### Data Model Sketch

```swift
struct BrowserFallbackPolicy: Codable, Equatable {
    enum Mode: String, Codable {
        case picker
        case browser
    }

    var mode: Mode
    var browserID: UUID?
    var profile: String?
}

struct URLRewriteRule: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var match: URLRewriteMatch
    var actions: [URLRewriteAction]
}

struct URLRewriteMatch: Codable, Equatable {
    var schemes: [String]
    var hostPattern: String
    var useRegex: Bool = false
    var pathPrefix: String?
    var sourceAppBundleIDs: [String]
}

enum URLRewriteAction: Codable, Equatable {
    case forceScheme(String)
    case replaceHost(String)
    case stripQueryParameters([String])
    case stripQueryParameterPrefixes([String])
    case setQueryParameter(name: String, value: String)
    case removeFragment
}
```

`BrowserRoutingRule` should evolve from a single source-app field to an array:

```swift
var sourceAppBundleIDs: [String]
```

During migration, existing persisted/imported `sourceAppBundleId` values should become a one-item array. Missing or empty source values continue to mean any source app.

**Design system alignment (design review):** Chowser has no `DESIGN.md` and doesn't need one — this is a native macOS Settings panel, not a web product, so Apple's Human Interface Guidelines plus the existing codebase's own component vocabulary are the design system. New "Behavior" and "Rewrites" sections should follow the existing `SettingsView+Browsers.swift` / `SettingsView+Rules.swift` extension-per-section pattern (a `SettingsView+Behavior.swift` and `SettingsView+Rewrites.swift`), and rewrite rule rows should reuse `RuleRowView`'s local-`@State`-with-commit-on-blur pattern rather than introducing a new state-management approach for what is structurally the same kind of row.

**Correction:** an earlier draft of this PRD claimed `URLRewriteRule` just needed "the same tolerant `Codable` pattern `BrowserRoutingRule` already has" for per-item import resilience — that premise is wrong. Verified against the actual code: `BrowserRoutingRule`'s custom `init(from:)` (`BrowserManager.swift:36-48`) only defaults *optional* fields (`isEnabled`, `usePrivateMode`, `useRegex`); required fields (`id`, `name`, `hostPattern`, `browserBundleId`) still throw on decode failure, and `importRules` (`BrowserManager.swift:634-665`) calls `decoder.decode([BrowserRoutingRule].self, from: data)` as a single array decode — one throwing element fails the *entire* import with no `ImportSummary` produced at all, today, for routing rules. There is no existing per-item-resilient pattern to copy. Delivering per-item import resilience (for both `BrowserRoutingRule` and the new `URLRewriteRule`) requires restructuring the import function to decode the file as loosely-typed JSON first, then attempt each element's `Decodable` decode individually inside a loop, catching and counting failures — a real, uncosted piece of work, not a one-line `init` change. This applies to fixing the existing routing-rule import path too, not just shipping it correctly for rewrites.

**Rewrite engine is a separate pure type, not more `BrowserManager` methods.** `BrowserManager.swift` is already 1866 lines, owning persistence, launch-arg templating, profile detection, shortlink resolution, and tracking cleanup. Stacking a 6-action chained rewrite engine on top as more instance methods would make FR-025's "tester invokes the same pipeline function as runtime" only informally true — a real pure function/type (e.g. `RewritePipeline.apply(url:rules:context:) -> RewriteTrace`) that `BrowserManager` merely calls is what actually guarantees the tester and runtime share code, not just similar-looking code. `BrowserManager` stays the state/persistence owner; the rewrite algorithm itself is not a `BrowserManager` responsibility.

**Source-app context must be explicit, not read from `currentSourceAppBundleId`.** Today, `currentSourceAppBundleId` (`BrowserManager.swift:161`) is set once per incoming URL and cleared via `defer` inside `AppDelegate.resolveIncomingURLRoute` (`AppDelegate.swift:174-186`) immediately after the first `resolvedRoute` call — it's `nil` by the time any later picker interaction (manual re-resolve, the rewrite tester, or a live rewrite-trace preview while the user edits) runs. Since rewrite rules can carry source-app conditions and the tester needs to simulate a source app, the rewrite pipeline (and any future re-resolve of `resolvedRoute`) must take source app as an explicit parameter, not read it from this ambient, defer-cleared property. This is the same "explicit over ambient" fix the rewrite engine needs to actually be testable in isolation.

### Persistence And Compatibility

- Store fallback policy, rewrite rules, and privacy controls through the same `BrowserManager` persistence path used for browsers and routing rules.
- Debounce writes consistently with existing browser/rule writes for interactive edits (settings changes, drag-to-reorder). The one-time migration write (single-source → array, and the merge-assist accept/reject) is a single synchronous write, not debounced — debouncing a one-time startup migration only delays persistence for no benefit.
- Preserve import/export readability.
- Accept old exports with `sourceAppBundleId`.
- Export new rules with `sourceAppBundleIDs`.
- MCP `GET /rules` emits both fields during the compatibility window: `sourceAppBundleId` (singular, populated only when the list has exactly one entry, for existing consumers) and `sourceAppBundleIDs` (plural, always present). No `/status` schema-version field needed for this; drop the singular field at the next whole-major `MARKETING_VERSION` bump (e.g. 4.0), not an unpinned "later."
- **Write-path parity (gap found in eng review):** `MCPServer.handleAddOrUpdateRule` (`MCPServer.swift:539-595`) currently reads only the singular `sourceAppBundleId` key from the POST body — there is no plural-field handling anywhere in `MCPServer.swift` today. Without fixing the write path too, Phase 2's headline feature (multi-source rules) would be exposed **read-only** via MCP: automation could list multi-source rules but not create or edit them. `POST /rules` must accept `sourceAppBundleIDs` as well as the legacy singular field.
- MCP's bearer-token check (`MCPServer.swift:252`, `requestToken == authToken`) uses plain string equality, a timing side-channel. Low severity (loopback-only, requires local code execution already) but cheap to fix to a constant-time comparison while touching this file for the new `/rewrites` endpoints.

### App Store Constraints

- Do not rely on launching external scripts.
- Keep network-backed behavior opt-in and explainable.
- Browser helper work must be reviewed separately for sandbox and distribution impact.
- Safari profile support must be reviewed separately because Safari does not use the Chromium/Firefox launch argument paths.
- Desktop app and mail destinations must be reviewed separately because they expand the URL schemes Chowser accepts.
- App Store builds already use `NSWorkspace.open()` for browser launching; fallback and picker edits must respect that existing path.

## Implementation Sequence

Phases 5-7 (browser helper, profile polish, destination types) are committed here for positioning reasons, not technical necessity — Approach A (ship Phases 1-2 only) was rejected mainly because it leaves the differentiating pitch unbuilt, not because 5-7 are hard blockers. Treat Phases 5-7 as re-confirm-before-build checkpoints: real usage from Phases 1-3 may change their priority or scope.

This PRD's use cases and prioritization are not backed by support-ticket or usage data — accepted as-is given Chowser is a solo-maintained personal tool where the maintainer is also the primary user. Before re-confirming Phases 5-7, pull real signal from `DomainFrequencyTracker` (already collects domain→browser click frequency) and App Store review/support volume on shortlink/cleanup complaints, rather than re-litigating from vibes a second time.

### Phase 1: Fallback And Privacy Controls

Ship:

- Fallback picker/browser setting.
- Fallback route tests.
- Shortlink auto-resolution toggle and timeout setting if current behavior is implicit.

Why first: it is useful immediately and does not require a new rule editor surface.

### Phase 2: Multiple Source Apps

Ship:

- Rule model migration.
- Rule editor source app chips.
- Import/export compatibility.
- Route-resolution tests for any/one/many source apps.
- Migration-time merge assist: when converting single-source rules, auto-suggest merging rules that share the same browser/profile destination but differ only in source app into one multi-source rule (CEO-review cherry-pick — small addition to the existing migration path, dedups rule lists that would otherwise stay fragmented after upgrade). This mutates the user's existing rule set, so it must be shown as an explicit accept/reject prompt during migration (a one-time review sheet listing each proposed merge), never applied silently — the user can accept, reject, or accept-all.

Why second: it simplifies existing routing without changing URL semantics.

### Phase 3: Typed Rewrites

Ship:

- Rewrite model.
- Rewrite engine.
- Rewrite list/editor.
- Rewrite tester.
- Import/export support.
- Rewrite trace shown inline in the picker's existing async link-preview area, not just in Settings (CEO-review cherry-pick — reuses the existing preview UI, makes the rewrite pipeline visible at the moment it matters).
- Rewrite CRUD exposed via MCP (`POST/DELETE /rewrites` alongside the existing `/rules` shape) so the same automation surface that manages routing rules also manages rewrites (CEO-review cherry-pick).

Why third: it has the most behavioral risk and needs explicit preview tooling.

### Phase 4: Picker URL Editing

Ship:

- Expandable editable URL field.
- Validation.
- Keyboard behavior tests.

Why fourth: useful but secondary, and it depends on the route pipeline being clear.

### Phase 5: Browser Helper

Ship:

- Bookmarklet or URL-scheme helper first.
- Extension only if the lightweight helper proves insufficient.

Why last: browser packaging can expand scope quickly. Kept last deliberately after CEO-review competitive-risk pushback (Finicky/Velja/OpenIn already ship routing-rule subsets, and re-routing-from-active-tab is Chowser's real differentiator) — rewrites still go first because they carry the most behavioral risk and need the tester built before anything else depends on it. The `chowser://open` handoff already works today, so the differentiating capability is usable immediately without waiting for Phase 5's packaging polish.

### Phase 6: Profile Polish

Ship after the route pipeline is stable:

- Profile markers in the picker.
- Optional configured-profile hotkeys.
- Safari profile support: **not pursued.** Safari has no public API or CLI argument for launching into a specific profile (unlike the Chromium/Firefox launch-arg templates `BrowserConfig` already supports). Settings hides/disables the profile field for Safari with a one-line note rather than implying support — no feasibility spike needed, the answer is already known from the public API surface.

Why later: existing profile routing works; this is scan speed and launch polish.

### Phase 7: Destination Types

Ship only after the browser-routing pipeline is stable, desktop app targets first:

1. Desktop app targets for configured URL schemes — reuses the existing "launch this bundle ID" primitive already used for browsers.
2. Mail client selection for `mailto:` — deferred behind desktop apps because FR-062 (must not change the system default mail client) requires a materially trickier mechanism than app-launch, and a wrong-account send is a worse failure mode than a wrong-browser open.
3. Rule tester support for non-browser targets.

Why later: this changes what Chowser routes, not just how it chooses a browser.

## Acceptance Criteria

- Existing unmatched-link behavior is unchanged after upgrade.
- A user can configure a fallback browser and confirm unmatched links open there.
- A single routing rule can match multiple source apps.
- Existing exported rules still import correctly.
- A rewrite rule can strip query parameters and force `https` before route matching.
- Rewrite tester output matches actual runtime routing behavior.
- Network shortlink resolution can be disabled.
- Picker URL editing does not interfere with numeric browser shortcuts.
- App Store build behavior remains compatible with sandboxed browser launch constraints.
- Future non-browser destinations do not change existing HTTP/HTTPS browser routing behavior.

## Test Plan

Unit tests:

- Fallback policy: picker default, browser fallback, missing browser fallback.
- Source-app matching: any source, one source, multiple sources, no source metadata.
- Migration: old `sourceAppBundleId` to new `sourceAppBundleIDs`.
- Rewrite actions: force scheme, replace host, strip params, remove fragment.
- Rewrite ordering: first rule output feeds next rule.
- Invalid rewrite output is skipped or reported without crashing.
- Shortlink disabled path does not make a network request.
- Known catastrophic-backtracking patterns (e.g. `(a+)+`, `(a*)*`) are rejected at save time with a clear validation error, both in the rule editor and rewrite editor (FR-028).
- **Regression (critical, Iron Rule):** existing, already-saved `BrowserRoutingRule.useRegex` patterns that are legitimate (non-catastrophic) are not retroactively broken or re-validated in a way that could lock users out of a working rule — the save-time check applies to new saves/edits only, not a startup re-validation of existing persisted rules.
- Malformed/old-shape rule (routing or rewrite) in an import is skipped individually (counted in `ImportSummary.invalid`) without failing the whole array decode — this requires restructuring `importRules`/`importRewrites` to decode array elements individually (e.g. decode as loosely-typed JSON first, then attempt per-element `Decodable` decode in a loop), since neither the existing `BrowserRoutingRule` import path nor a naive `[URLRewriteRule].self` decode has this property today (see Architecture Notes).
- Migration-time merge-suggestion correctly proposes merging same-destination single-source rules, does not merge rules with different destinations, and does not change which rule wins for a URL that also matches a third, differently-matching rule interleaved between the merge candidates in the original ordered list.
- MCP rewrite CRUD endpoints round-trip correctly and reject malformed payloads the same way `/rules` does; `POST /rules` accepts the plural `sourceAppBundleIDs` array field, not just the legacy singular field (write-path parity with the `GET /rules` dual-field read already specified).

UI tests or focused manual QA:

- Settings fallback control persists.
- Rule editor adds and removes multiple source app chips.
- Profile markers make similarly named profiles distinguishable in the picker.
- Rewrite tester shows before/after output.
- Picker edit mode validates malformed URLs.
- Existing picker shortcuts still work.

Manual QA:

- Slack/Mail/GitHub Desktop source-app routing.
- Chrome/Brave/Firefox profile launch paths.
- App Store sandbox build fallback behavior.
- Import/export round trip with browsers, routes, and rewrites.

## Risks

- Rewrite order can surprise users if the UI does not explain which rule changed the URL.
- Making tracking cleanup configurable could complicate an existing privacy promise.
- Shortlink resolution has privacy implications because it contacts remote hosts before routing.
- Import/export and MCP API compatibility can break external automation if field names change abruptly.
- Browser helper packaging can pull the project into browser-store review work.
- Safari profile support may not be reliable through public launch APIs.
- Desktop app and mail destinations can make route failures harder to explain if validation is weak.
- Link preview's network fetch (FR-034) was an unaddressed privacy hole in the original draft of this PRD — found during eng review, not anticipated at design time. Worth treating as a signal to re-scan for other already-shipped features whose behavior interacts with this PRD's privacy claims before shipping Phase 1.
- Save-time regex complexity rejection (FR-028's corrected mechanism) is a heuristic, not a perfect ReDoS classifier — some legitimately safe patterns may get flagged, and some slow-but-not-technically-catastrophic patterns may pass. It's a real improvement over no check, not a formal guarantee.

## Resolved Decisions

All prior open decisions are resolved; see `CONTEXT.md` for terminology and `docs/adr/` for the three decisions with real, hard-to-reverse tradeoffs:

- Tracking cleanup stays a built-in on/off toggle, not editable rewrite rules — `docs/adr/0002-tracking-cleanup-stays-built-in.md`.
- Pipeline order is rewrites → shortlink resolution → cleanup — `docs/adr/0001-route-pipeline-order.md`.
- Rewrite rules support source-app conditions in v1 (reuses Phase 2's matching logic).
- A failed/skipped rewrite falls through to normal route resolution and fallback — no separate error-fallback state.
- Browser helper: the URL-scheme handoff already exists (`chowser://open`); Phase 5 ships only a bookmarklet/docs wrapper around it.
- Safari profile launch has no public API — marked explicitly unsupported, not explored further.
- Non-browser destinations ship desktop app deep links before `mailto:`.
- MCP `/rules` emits both `sourceAppBundleId` (singular) and `sourceAppBundleIDs` (plural) during the compatibility window.
- Shortlink resolution defaults to off for all installs, including existing ones — a deliberate breaking change — `docs/adr/0003-shortlink-resolution-off-by-default-on-upgrade.md`.

## Recommendation

Build this as a PRD-led feature set with a narrow ARD inside the implementation work. The product value is clear for fallback routing, multi-source rules, and typed rewrites. Picker URL editing and browser helper support are useful but should follow after the route pipeline is explicit and tested.

Do not build an executable config model. Chowser's advantage is native configuration, visual confidence, and App Store-safe behavior. The right implementation is a typed routing pipeline that advanced users can reason about without writing code.

## CEO Review: Decision Audit Trail

<!-- AUTONOMOUS DECISION LOG -->

| # | Decision | Classification | Principle | Rationale | Outcome |
|---|----------|-----------------|-----------|-----------|---------|
| 1 | Mode: SELECTIVE EXPANSION | Mechanical | — | Feature enhancement on an existing system, per autoplan default | Applied |
| 2 | Alternatives: Approach B (full PRD as sequenced) | Mechanical | P1 completeness | Already user-approved in office-hours Phase 4; reused, not re-litigated | Applied |
| 3 | Complexity check: no scope reduction | Mechanical | P2 boil lakes | Phased into independently-small vertical slices, not one 8+-file commit | No change |
| 4 | Cherry-pick: rewrite trace in picker preview | Auto-approved | P2 blast radius | Reuses existing preview UI, <1 day CC effort | Added to Phase 3 |
| 5 | Cherry-pick: migration merge-suggestion | Auto-approved | P2 blast radius | Touches only the existing migration path | Added to Phase 2 |
| 6 | Cherry-pick: MCP rewrite CRUD | Auto-approved | P2 blast radius | Extends existing `/rules`-shaped endpoints | Added to Phase 3 |
| 7 | Cherry-pick: Finicky JS-config import bridge | Deferred | P3 pragmatic | Real engineering cost (JS-subset parser), not blast radius | TODOS.md |
| 8 | Cherry-pick: auto-test rewrites against recent URL history | Deferred | Borderline blast radius (3-5 files) | Genuinely optional polish, not core | TODOS.md |
| 9 | chowser-electrobun platform status | **User Challenge** (asked directly, not auto-decided) | — | High blast-radius ambiguity the CEO review couldn't resolve alone | Confirmed dead/paused, native-only; PRD + TODOS.md updated |
| 10 | Shortlink-off-by-default silent regression | Auto-fixed | P1 completeness | Real gap: breaking change with no user-visible notice | Added in-app notice requirement |
| 11 | Send-to-phone FR staleness (already shipped v3.8.0) | Auto-fixed | Mechanical | Factual error in PRD text | Corrected FR-060 + use case |
| 12 | MCP dual-field exit criteria unpinned | Auto-fixed | P5 explicit | "Later" invites permanent legacy fields | Pinned to next major version |
| 13 | No user-evidence backing prioritization | Accepted + mitigated | P3 pragmatic | Solo-maintainer project; user is primary data source | Added instrumentation recommendation via `DomainFrequencyTracker` |
| 14 | "No JS config" vs. equivalent-complexity typed system | No action | — | Sandboxing/support-burden distinction is real even if UI complexity is comparable | No change |
| 15 | Sandboxed predicate-only match scripting | Deferred | P3 pragmatic | Real alternative, but only worth it if typed conditions prove insufficient post-ship | TODOS.md |
| 16 | Extension sequencing vs. competitive risk | **Taste decision** (asked directly) | — | Reasonable people could sequence either way | Kept current order; note added to Phase 5 |
| 17 | ReDoS risk in regex host-pattern matching | Auto-fixed | P1 completeness | Attacker-controlled input against user-authored regex, no timeout guard existed | Added FR-028 |
| 18 | `URLRewriteRule` needs tolerant Codable decode | Auto-fixed | P4 DRY | Should match `BrowserRoutingRule`'s existing pattern, not diverge | Added note |
| 19 | Picker edit starting URL ambiguity (pre/post pipeline) | Auto-fixed | P5 explicit | Implicit behavior made explicit | Clarified FR-041 |
| 20 | Test plan gaps (regex timeout, tolerant decode, cherry-picks) | Auto-fixed | P1 completeness | New behavior needs new test coverage | Added to Test Plan |
| 21 | Rewrite pipeline logging | Auto-fixed | P4 DRY | Reuse existing `AppLogger` "Route" category | Added FR-025b |

## CEO Review: Completion Summary

```
+====================================================================+
|            MEGA PLAN REVIEW — CEO PHASE COMPLETION SUMMARY         |
+====================================================================+
| Mode selected        | SELECTIVE EXPANSION                          |
| System Audit         | No TODOS.md pre-existing; chowser-electrobun |
|                       | found unmentioned — resolved as dead/paused  |
| Step 0               | Premises confirmed; Approach B reused        |
| Section 1  (Arch)    | 1 issue found (ReDoS) — fixed                |
| Section 2  (Errors)  | 1 GAP found (non-tolerant Codable) — fixed   |
| Section 3  (Security)| 0 further issues beyond Section 1's ReDoS    |
| Section 4  (Data/UX) | 1 edge case clarified (edit pre/post pipeline)|
| Section 5  (Quality) | 0 issues found                              |
| Section 6  (Tests)   | 4 test gaps found — added to Test Plan       |
| Section 7  (Perf)    | 0 issues found                              |
| Section 8  (Observ)  | 1 gap found (rewrite logging) — fixed        |
| Section 9  (Deploy)  | 0 new risks beyond already-ADR'd shortlink   |
| Section 10 (Future)  | Reversibility: 4/5, debt: MCP dual-field     |
|                       | (pinned removal version)                     |
| Section 11 (Design)  | Deferred to full /plan-design-review phase   |
+--------------------------------------------------------------------+
| NOT in scope         | Finicky import bridge, sandboxed predicate   |
|                       | scripting, recent-URL auto-test (3 items,    |
|                       | all in TODOS.md)                             |
| What already exists  | chowser://open handoff, hostMatches/useRegex |
|                       | matcher, cleanURL query manipulation,        |
|                       | tolerant Codable migration pattern,          |
|                       | AppLogger diagnostics infra, MCP /rules shape|
| Dream state delta     | 7 of 8 twelve-month-ideal dimensions covered |
| Error/rescue registry | 2 methods flagged, both fixed (0 remaining)  |
| Failure modes         | 1 CRITICAL GAP found (shortlink silent       |
|                       | regression) — fixed with in-app notice reqt  |
| TODOS.md updates      | 4 items proposed, all added                  |
| Scope proposals       | 5 proposed, 3 accepted, 2 deferred           |
| Outside voice         | Codex unavailable (usage limit) — Claude     |
|                       | subagent ran solo [subagent-only]            |
| Unresolved decisions  | 0 — all resolved (2 required direct user     |
|                       | input: electrobun status, phase sequencing)  |
+====================================================================+
```

**NOT in scope:** Finicky JS-config import bridge (real engineering cost, deferred to TODOS.md); sandboxed predicate-only match scripting (deferred, revisit only if typed conditions prove insufficient); auto-testing rewrites against recent URL history (borderline blast radius, deferred as optional polish).

**What already exists (reused, not rebuilt):** `chowser://open` URL-scheme handoff; `hostMatches`/`useRegex` matcher; `cleanURL` query-parameter manipulation; the tolerant-Codable-with-defaults migration pattern from `BrowserRoutingRule`; `AppLogger`'s "Route" diagnostics category (shipped v3.8.0); MCP `/rules` endpoint shape.

## Design Review: Decision Audit Trail

<!-- AUTONOMOUS DECISION LOG -->

| # | Decision | Classification | Rationale | Outcome |
|---|----------|-----------------|-----------|---------|
| 1 | Focus areas: all 7 passes | Mechanical | autoplan default — no reduction | Ran all 7 |
| 2 | Picker URL field: static-text-by-default, not always-editable | Auto-fixed | Mockup contradicted PRD's own "not visually dominant" directive | Fixed in Picker section |
| 3 | Esc key semantics ambiguous (edit-cancel vs picker-close) | Auto-fixed | Critical: mockup's static footer legend vs. FR text disagree | Made explicit + dynamic legend requirement |
| 4 | Shortlink notice: no guaranteed delivery surface (LSUIElement, no window) | Auto-fixed | Critical: undermines ADR-0003's entire purpose | Dual-surface (picker + Settings) one-time notice |
| 5 | "Hold Shift to ask" in mockup — scope creep or existing feature? | Investigated, not scope creep | Verified against `AppDelegate.swift:246-248` — already shipped | Added FR-006 cross-reference, no new work |
| 6 | Rewrite host "Exception"/negative-match field | **Taste decision** (asked directly) | Real feature, but new `URLRewriteMatch` surface with no FR backing | Cut for v1 |
| 7 | "Fetch link preview" toggle in mockup | Auto-decided: out of scope | Already-shipped feature, unrelated to this PRD | Excluded, noted explicitly |
| 8 | "Future destinations" teaser rows styled as live UI | Auto-fixed | Scope-leakage risk — reads as real to first-time users | Excluded from Phase 1-4 UI, noted explicitly |
| 9 | Fallback control: segmented control vs. dropdown (mockup contradiction) | Auto-fixed | PRD text (segmented control) is authoritative over mockup | Resolved via "mockup is ideation" framing note |
| 10 | Multi-rule rewrite tester collapses chained rules into one step | Auto-fixed | Hides the exact differentiator behavior (which rule changed what) | Per-rule before/after steps required |
| 11 | Pre-picker pipeline latency (up to 1.5s) has no loading state | Auto-fixed | High: reads as app hang on every affected link | Added loading-state requirement |
| 12 | FR-033 network indicator has no visual design | Auto-fixed | Requirement existed in text only | Consistent indicator affordance specified |
| 13 | Behavior toggles have equal visual weight regardless of network sensitivity | Auto-fixed | Same root cause as #12 | Folded into the network-indicator fix |
| 14 | Migration merge-suggestion UI unspecified | Auto-fixed | Mutates user's existing rule set with zero interaction spec | Explicit accept/reject review sheet required |
| 15 | Design system: no DESIGN.md | Auto-decided: not needed | Native macOS Settings panel — HIG + existing component vocabulary is the design system | Noted reuse of `SettingsView+X.swift` pattern |

## Design Review: Completion Summary

```
+====================================================================+
|         DESIGN PLAN REVIEW — COMPLETION SUMMARY                    |
+====================================================================+
| System Audit         | No DESIGN.md (not needed — native app);      |
|                       | existing mockup found and reviewed          |
| Step 0               | Initial rating: 7/10 → all 7 passes run      |
| Pass 1  (Info Arch)  | 8/10 — no issues                            |
| Pass 2  (States)     | 4/10 → 9/10 — 6 gaps found and fixed        |
| Pass 3  (Journey)    | Adequate — 1 critical break found (Esc)      |
|                       | and fixed                                    |
| Pass 4  (AI Slop)    | N/A — native App UI, not marketing; no       |
|                       | slop patterns found                          |
| Pass 5  (Design Sys) | No DESIGN.md needed; component reuse noted   |
| Pass 6  (Responsive) | 1 gap found (rewrite reorder a11y) — fixed   |
| Pass 7  (Decisions)  | 14 resolved, 0 deferred                      |
+--------------------------------------------------------------------+
| NOT in scope         | Rewrite host exceptions, link-preview toggle,|
|                       | future-destination teaser rows (3 items)     |
| What already exists  | Mockup (reused as input, not regenerated);   |
|                       | SettingsView+X.swift pattern; RuleRowView    |
| TODOS.md updates      | 0 new (design gaps fixed inline, not         |
|                       | deferred — all were cheap fixes)             |
| Approved Mockups      | 0 new generated — existing mockup treated    |
|                       | as ideation reference, reconciled with PRD   |
| Decisions made        | 15 (14 auto-fixed, 1 taste decision)         |
| Decisions deferred    | 0                                             |
| Overall design score  | 7/10 → 9/10                                  |
+====================================================================+
```

## Eng Review: Decision Audit Trail

<!-- AUTONOMOUS DECISION LOG -->

| # | Decision | Classification | Rationale | Outcome |
|---|----------|-----------------|-----------|---------|
| 1 | FR-028's "bounded evaluation timeout" is unimplementable | Auto-fixed (critical) | `NSRegularExpression`/ICU has no true mid-match cancellation; a naive fix would ripple `resolvedRoute` async across 4 production + 19 test call sites | Redesigned as save-time complexity rejection |
| 2 | `currentSourceAppBundleId` ambient state breaks rewrite tester/live-trace | Auto-fixed | Verified: cleared via `defer` in `AppDelegate.swift:174-186` before later picker interactions run | Rewrite pipeline takes source app as explicit parameter |
| 3 | Rewrite engine should be a separate pure type | Auto-fixed | `BrowserManager.swift` already 1866 lines; FR-025's "same pipeline function" needs to be literally true, not informally true | `RewritePipeline` as a free function/type, not more `BrowserManager` methods |
| 4 | Import per-item resilience premise was wrong | Auto-fixed (corrects an earlier CEO-phase decision) | Verified: `BrowserRoutingRule`'s tolerant init only covers optional fields; `importRules` does one whole-array decode with no per-item catch, today | Corrected to require restructuring the import function itself, for both routing rules and rewrites |
| 5 | MCP `POST /rules` doesn't accept the plural field | Auto-fixed | Verified: `MCPServer.swift:539-595` reads only singular `sourceAppBundleId` | Write-path parity required alongside the already-specified read-path dual-field |
| 6 | MCP bearer-token comparison is non-constant-time | Auto-fixed | Verified: plain `==` at `MCPServer.swift:252`; cheap fix while touching this file anyway | Constant-time comparison required |
| 7 | Migration merge-assist ignores rule order | Auto-fixed | Real edge case: an interleaved third rule could change which rule wins after a merge | Added order-safety requirement + test |
| 8 | Link preview (shipped feature) leaks link destinations regardless of the new privacy toggle | **User Challenge** (asked directly) | Verified: full GET, no allowlist gate, undermines ADR-0003's entire purpose; real scope expansion beyond original PRD boundary | Gated behind the same privacy posture — FR-034 added |
| 9 | Save-time regex heuristic is imperfect | Accepted, noted | A heuristic classifier, not a formal ReDoS proof — real improvement over nothing, not a guarantee | Documented as a known limitation in Risks |

## Eng Review: Architecture Diagram

```
AppDelegate.application(_:open:)
        │
        ▼
RewritePipeline.apply(url, rules, sourceApp)   ◄── new, pure function (not BrowserManager)
        │  reuses hostMatches/useRegex (now with save-time-only complexity check)
        ▼
BrowserManager.unshortenURL / LinkMetadataFetcher.fetch   ◄── both now gated by
        │                                                     the same privacy toggle (FR-034)
        ▼
BrowserManager.cleanURL (tracking cleanup)
        │
        ▼
BrowserManager.resolvedRoute(url, sourceApp)   ◄── unchanged signature (sync),
        │                                          source app now explicit param
        ├─ match → BrowserManager.open()
        └─ no match → BrowserFallbackPolicy (new) → open() or show picker

BrowserManager (persistence/state owner, unchanged responsibility)
        ├── routingRules: [BrowserRoutingRule]      (existing)
        ├── configuredBrowsers: [BrowserConfig]      (existing)
        ├── fallbackPolicy: BrowserFallbackPolicy    (new)
        ├── rewriteRules: [URLRewriteRule]            (new)
        └── shortlinkAllowlist / privacy toggles      (new)

MCPServer  ──/rules (GET dual-field, POST now dual-field)──▶ BrowserManager
           ──/rewrites (new CRUD, mirrors /rules)──────────▶ BrowserManager
```

Coupling: `RewritePipeline` is new and depends only on `hostMatches` (existing) — no new coupling into `BrowserManager` beyond it calling the pipeline. `BrowserManager` itself gains 3 new persisted properties but no new *responsibilities* beyond what it already owns (state + persistence).

## Eng Review: Test Coverage Diagram

```
CODE PATHS                                          USER FLOWS
[+] RewritePipeline.apply() (new)                   [+] Picker
  ├── [GAP] chained multi-rule application             ├── [GAP] Edit URL → Return → launch
  ├── [GAP] invalid output → skip + badge              ├── [GAP] Edit URL → Esc → cancel (dynamic legend)
  └── [GAP] source app passed explicitly, not ambient  ├── [GAP] [→E2E] shortlink loading state
[+] Save-time regex validation (new)                   └── [GAP] rewrite trace, multi-rule chain
  ├── [GAP] catastrophic pattern rejected             [+] Settings
  └── [GAP] existing valid patterns not re-broken       ├── [GAP] zero-browsers fallback disabled state
[+] Import (restructured, routing + rewrites)          ├── [GAP] rewrite empty state
  └── [GAP] per-item skip, no whole-array failure       └── [GAP] [→E2E] merge-assist accept/reject/accept-all
[+] LinkMetadataFetcher (FR-034 gating, existing code) [+] MCP
  └── [GAP] no fetch when privacy toggle off             ├── [GAP] POST /rules plural field
[+] MCPServer                                            └── [GAP] /rewrites CRUD round-trip
  └── [GAP] constant-time token compare

COVERAGE: 0/17 new/changed paths tested (nothing built yet — expected;
all 17 are now explicit requirements in the Test Plan section and the
eng-review test-plan artifact, not implicit)
```

## Eng Review: Failure Modes Registry

```
CODEPATH                        | FAILURE MODE                          | RESCUED? | TEST? | USER SEES?                        | LOGGED?
---------------------------------|----------------------------------------|----------|-------|-----------------------------------|--------
Regex host pattern (save)       | Catastrophic backtracking shape       | Y        | Y     | Save-time validation error        | N/A (never saved)
Rewrite action output           | Produces non-http/s URL               | Y        | Y     | Inline last-skip-reason badge     | Y (AppLogger)
Import decode (rules/rewrites)  | Malformed element in array            | Y        | Y     | Per-item skip, ImportSummary.invalid | N (not logged — low priority)
Shortlink resolution            | Timeout / network failure             | Y        | Y     | Silent fail-open to original URL  | Existing
Link preview fetch (FR-034)     | Fires while privacy toggle is off     | Y        | Y (new) | No preview / skipped state        | N/A
MCP POST /rules                 | Missing/malformed sourceAppBundleIDs  | Y        | Y     | Error response (existing pattern) | Existing
Migration merge-assist          | Merge changes order-dependent routing | Y        | Y     | Explicit accept/reject review sheet | N/A
```

0 rows with RESCUED=N AND TEST=N AND USER SEES=Silent — no critical gaps remaining after fixes.

## Eng Review: Completion Summary

```
+====================================================================+
|         ENG PLAN REVIEW — COMPLETION SUMMARY                       |
+====================================================================+
| Step 0 (Scope Challenge) | Scope accepted as-is — phased into small |
|                           | slices, no reduction (P2 never-reduce)   |
| Architecture Review       | 4 issues found (1 critical), all fixed   |
| Code Quality Review       | 0 new issues (already covered in CEO/    |
|                           | Design phases)                           |
| Test Review               | Diagram + artifact produced, 7 gaps      |
|                           | found and added to Test Plan             |
| Performance Review        | 0 issues (in-memory, O(n) per URL)       |
| NOT in scope              | written                                  |
| What already exists       | written (see below)                      |
| TODOS.md updates          | 0 new (all fixes cheap enough to fold in)|
| Failure modes             | 7 mapped, 0 critical gaps remaining      |
| Outside voice              | Codex unavailable (usage limit) —        |
|                            | Claude subagent ran solo [subagent-only] |
| Parallelization            | Sequential — shared BrowserManager.swift |
| Lake Score                 | 9/9 findings chose the complete fix over |
|                             | a shortcut                               |
+====================================================================+
```

**NOT in scope:** none newly deferred — every finding this phase was either fixed inline or (link preview privacy) explicitly pulled into scope via FR-034.

**What already exists (reused, verified against code, not assumed):** `BrowserRoutingRule`'s partial tolerant-decode pattern (corrected understanding: optional-fields-only, not per-item import resilience); `hostMatches`/`useRegex` matcher (now getting the save-time complexity check); `LinkMetadataFetcher`'s existing GET-based redirect-following (now brought under the same privacy posture via FR-034); `MCPServer`'s existing `/rules` validation pattern (extended to `/rewrites`).

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | clean | 5 proposals, 3 accepted, 2 deferred |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | clean | 9 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | clean | score: 7/10 → 9/10, 15 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — (no developer-facing scope detected) |

**VERDICT:** CEO + ENG + DESIGN CLEARED — ready to implement. Codex was unavailable across all three phases (usage limit) — every outside-voice pass ran as a Claude subagent solo [subagent-only], not a cross-model consensus. DX review was skipped (Settings/picker UI, not a developer-facing surface).

NO UNRESOLVED DECISIONS
