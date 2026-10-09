# Codebase Review

**Baseline:** `70ea7855187a51c33a8c214ee1581ab7f05589e3` (`work/catalog-trust-native-routing`)  
**Review date:** 2026-08-26  
**Scope:** current implementation, architecture, correctness, privacy, trust, tests, and documentation

## Verdict

The catalog-verification and native-routing modules are strong and fail closed in most intended paths, but the current branch should not be treated as fully verified. Three high-priority defects can lose or misroute incoming links, and several medium-priority privacy, consent, and local-availability issues remain. No critical signing bypass was found.

## Priority findings

| Priority | Finding | Category | Evidence |
|---|---|---|---|
| P0 | A shortener can return a non-HTTP(S) custom URL, which then re-enters ordinary destination resolution without post-resolution scheme validation. | Defect / trust boundary | `Chowser/BrowserManager.swift:1711-1759`; `Chowser/AppDelegate.swift:401-466` |
| P0 | Overlapping incoming-link tasks share scalar picker state; an older suspended request can overwrite or close a newer request. | Defect / concurrency | `Chowser/AppDelegate.swift:401-479`; `Chowser/BrowserManager.swift:277-284,444-446` |
| P0 | Browser-launch failure consumes or dismisses the pending link because `open` returns `Void` and failures only log. | Defect / data loss | `Chowser/AppDelegate.swift:452-466`; `Chowser/ContentView.swift:1526-1530`; `Chowser/BrowserManager.swift:2072-2142` |
| P1 | Private-mode URLs are added to persisted recent history before effective private mode is resolved. | Privacy defect | `Chowser/AppDelegate.swift:428-466`; `Chowser/BrowserManager.swift:722-725,2375-2382`; `Chowser/ContentView.swift:1526-1534` |
| P1 | Native consent is described as exact HTTPS shapes, but resolution accepts HTTP and does not reject source credentials, port, or fragment. | Consent mismatch | `docs/adr/0005-signed-hosted-catalogs.md:3-17`; `Chowser/NativeAppDirectory.swift:412-429,453-500` |
| P1 | MCP buffers an unbounded request body before authentication. | Availability/security defect | `Chowser/MCPServer.swift:137-190,236-280` |
| P1 | Core configuration collections are caller-mutable, so Settings, imports, and MCP enforce different invariants. | Maintainability risk | `Chowser/BrowserManager.swift:254-269,1067-1101`; `Chowser/MCPServer.swift:575-625,932-947` |
| P1 | Any persisted collection decode failure silently replaces the whole collection with defaults or empty state. | Data-loss risk | `Chowser/BrowserManager.swift:690-700,818-845` |
| P1 | Launch-at-login state reports the requested value even when `SMAppService` fails. | Correctness defect | `Chowser/BrowserManager.swift:286-290,1857-1868`; `Chowser/MCPServer.swift:564-569` |
| P2 | `RewritePipeline` is pure at execution but depends on matching policy owned by the large stateful manager. | Design debt | `Chowser/RewritePipeline.swift:219-239`; `Chowser/BrowserManager.swift:2292-2359,2477-2714` |
| P2 | Catalog CI path filters omit behavior-language dependencies such as `RewritePipeline.swift`. | CI gap | `.github/workflows/deploy-docs.yml:6-26`; `Chowser/RewritePipeline.swift` |
| P2 | Project guidance and `.context` contain stale architecture, endpoint, picker-layout, import, and pipeline claims. | Documentation drift | `AGENTS.md:29,44,46,48-49`; `.context/architecture.md:63,119,173,199`; `CONTEXT.md:34-35` |

## Detail and remediation direction

### 1. Preserve the web-URL boundary

Validate every incoming and post-shortlink URL with one central `HTTP(S) + nonempty host` rule. Unknown or malformed `chowser:` commands should terminate command handling rather than fall through. Invalid shortlink redirects should fail open to the original web URL.

### 2. Give incoming links operation identity

Create an `IncomingLinkCoordinator` module that receives an immutable request context and owns sequencing, request identity, and picker policy. Decide explicitly whether multiple picker-requiring requests queue or latest-wins. AppDelegate should remain the AppKit adapter.

### 3. Make launch failure observable

Extract a `BrowserLauncher` seam with a typed result. Keep the URL pending until launch is accepted; on immediate or callback failure, preserve the request and show a recoverable picker/error state.

### 4. Move history recording to the final launch seam

Persist recent history only after effective private mode is known and only for non-private launches. Cover clipboard-private, rule-private, picker-private, and ordinary launches.

### 5. Align native consent with runtime matching

Require HTTPS for native source matches and reject user, password, port, and fragment unless those attributes become explicit signed source-rule fields shown during approval.

### 6. Bound MCP framing before authentication

Create a byte-oriented request-framing module with maximum header/body sizes, bounded concurrent connections, and an idle timeout. Reject invalid or excessive `Content-Length` before body accumulation.

### 7. Deepen configuration ownership

Make collections `private(set)` and expose validated commands returning typed outcomes. Share these commands across Settings, imports, and MCP. Useful seams are immutable routing snapshots, validated configuration commands, persistence, and launching—not pass-through manager classes.

### 8. Version and recover persisted state

Return typed load outcomes, preserve original or last-known-good bytes, and decode per item where safe. Make corruption visible rather than indistinguishable from a genuine empty setup.

## Strengths to preserve

- `HostedCatalogTrust` is a deep module: compact verification/repository/client interfaces hide signatures, bounds, semantic checks, version checks, cache re-verification, and fallback.
- Native routing is declarative, approval-bound, and rechecks the system handler immediately before launch.
- Rewrite execution has a small pure interface and produces a trace shared by runtime and tester UI.
- Destination precedence is centralized.
- App-mode transition ordering and rollback have a focused test seam.
- Direct and App Store distribution behavior is separated at target and compilation boundaries.
- Current unit coverage is broad for rule engines, catalog trust, launch planning, native resolution, app-mode transitions, and MCP endpoints.

## Unverified behavior

- UI test execution and picker concurrency under real AppKit event delivery.
- Release archive, signing, notarization, and App Store submission behavior.
- Real LaunchServices handler changes.
- Browser behavior when handed a non-web custom scheme.
- The product policy for two near-simultaneous links requiring one picker.

<!-- Last verified: 2026-08-26 against commit 70ea785 -->
