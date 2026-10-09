# Chowser Project Context

## Product

Chowser is a macOS link router. It receives HTTP/HTTPS links, rewrites and cleans them, resolves routing policy, and opens a configured browser/profile, an explicitly approved native app, or the picker.

Canonical domain terms live in [`../../CONTEXT.md`](../../CONTEXT.md).

## Runtime flow

```text
macOS Apple Event / application(_:open:)
  -> internal chowser: command dispatch
  -> RewritePipeline
  -> optional shortlink resolution
  -> tracking cleanup
  -> Shift-forced picker
  -> explicit/focus browser route
  -> approved native-app route
  -> configured browser fallback
  -> picker
```

Private-mode requests intentionally skip native apps. Current orchestration is in `Chowser/AppDelegate.swift:341-479`; destination precedence is centralized at `Chowser/AppDelegate.swift:297-325`.

## Main modules and seams

| Module | Interface / seam | Current responsibility |
|---|---|---|
| `AppDelegate` | AppKit lifecycle and URL-open callbacks | Incoming-link orchestration, source-app capture, app mode, status item, picker/settings/onboarding windows |
| `BrowserManager` | `@MainActor @Observable` mutable state owner | Browser/rule/rewrite state, persistence, routing, cleanup, shortlinks, discovery, launch, login/default-browser integration, picker preferences |
| `RewritePipeline` | Pure `apply` result with trace | Ordered typed URL transformations |
| `HostedCatalogTrust` | Verify/repository/client interfaces | Size bounds, Ed25519 verification, semantic validation hooks, version protection, last-known-good cache |
| `RewriteCatalogService` | Hosted rewrite adapter | Fetch, verify, review, apply, and provenance |
| `NativeAppDirectoryService` | Hosted native-directory adapter | Load/refresh, approval-aware resolution, handler recheck, launch |
| `MCPServer` | Authenticated localhost HTTP interface | Agent-driven browser/rule/rewrite/settings management |
| Settings and picker views | SwiftUI adapters | Present state and invoke manager mutations |

## State and persistence

- Primary configuration is stored in `UserDefaults` through `BrowserManager`.
- Browser, routing-rule, rewrite-rule, and recent-URL writes are debounced.
- Hosted catalog state is cached separately and reverified before use.
- UI tests use an isolated defaults suite via `AppEnvironment`.
- MCP uses a per-start bearer token and a mode-`0600` session file.

## Trust boundaries

1. **Incoming URLs:** untrusted input from macOS and `chowser:` commands.
2. **Network redirects:** untrusted shortlink responses; must remain inside the HTTP(S) routing boundary.
3. **Hosted catalogs:** untrusted transport, trusted only after signature and semantic verification.
4. **Native launch:** requires exact behavior approval plus system-handler bundle-ID checks at resolution and launch.
5. **MCP:** loopback-only but still exposed to untrusted local clients until bearer authentication succeeds.
6. **Distribution:** direct and App Store targets have different sandbox, launching, and updater behavior.

## Distribution

- `Chowser-osp`: direct, unsandboxed, `DIRECT_DISTRIBUTION`, Sparkle.
- `Chowser-appstore`: sandboxed, `APP_STORE`, no Sparkle.
- Release and artifact rules: [`../../DISTRIBUTION.md`](../../DISTRIBUTION.md) and [`../../RELEASE_VERIFICATION.md`](../../RELEASE_VERIFICATION.md).

## Authoritative references

- Operating guidance: [`../../AGENTS.md`](../../AGENTS.md)
- Domain glossary: [`../../CONTEXT.md`](../../CONTEXT.md)
- Architectural decisions: [`../../docs/adr/`](../../docs/adr/)
- Distribution: [`../../DISTRIBUTION.md`](../../DISTRIBUTION.md)
- Derived onboarding memory: [`../../.context/`](../../.context/)
- Historical draft: [`../../ADVANCED_ROUTING_PRD.md`](../../ADVANCED_ROUTING_PRD.md)

<!-- Last verified: 2026-08-26 against commit 70ea785 -->
