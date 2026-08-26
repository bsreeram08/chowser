# Review Backlog

This backlog orders follow-up work from the 2026-08-26 current-HEAD review. It is not an implementation commitment; each item needs an explicit user decision before production changes.

## P0 — correctness and link preservation

1. **Enforce the HTTP(S) boundary after shortlink resolution**
   - Done when custom/non-web redirects fail open to the original web URL and unknown/malformed `chowser:` commands cannot enter ordinary routing.
   - Add tests for `chowser:`, `ftp:`, `mailto:`, missing hosts, and malformed `chowser://open`.

2. **Serialize or identify overlapping incoming-link operations**
   - Decide queue versus latest-wins policy.
   - Done when an older suspended request cannot overwrite or close a newer request's picker state.

3. **Recover from browser-launch failure**
   - Done when missing apps, `Process.run` failures, and `NSWorkspace` callback failures preserve the URL and expose a recovery path.

## P1 — privacy, consent, and availability

4. **Keep private links out of recent history**
   - Cover clipboard-private, rule-private, picker-private, and ordinary launches.

5. **Match native runtime behavior to HTTPS consent**
   - Reject HTTP, userinfo, ports, and fragments unless explicitly modeled and shown.

6. **Bound MCP requests before authentication**
   - Cap headers, bodies, connections, and idle time; test oversized and incomplete requests.

7. **Centralize validated configuration commands**
   - Make Settings, import, and MCP use the same invariant-preserving interface.

8. **Recover persisted collections safely**
   - Preserve last-known-good/original bytes and return visible load outcomes.

9. **Make launch-at-login transitions truthful**
   - Update observable state only after successful registration/unregistration or reconciliation.

## P2 — architecture, CI, and documentation

10. **Extract pure URL-rule matching policy from `BrowserManager`**.
11. **Add general PR unit-test gating and catalog dependency paths**.
12. **Add deterministic native-catalog consent UI tests after stabilizing UI-test bootstrap**.
13. **Refresh `AGENTS.md`, `CONTEXT.md`, and `.context/` from current source**.
14. **Label `ADVANCED_ROUTING_PRD.md` historical or replace its stale implementation appendix**.

## Recommended sequencing

`1 -> 2 -> 3 -> 4/5/6 -> 7/8/9 -> 10/11/12/13/14`

<!-- Last verified: 2026-08-26 against commit 70ea785 -->
