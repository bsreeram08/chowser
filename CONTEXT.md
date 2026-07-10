# Chowser

Chowser intercepts HTTP/HTTPS links on macOS and routes them to a configured browser, browser profile, or the picker.

## Language

**Routing Rule**:
A persisted match (host pattern, optional path prefix, optional source apps) that resolves an incoming URL to a browser/profile destination. Matched top-to-bottom, first match wins.
_Avoid_: Route (use for the *result* of matching, not the stored rule)

**Rewrite Rule**:
A persisted, ordered, typed transformation (force scheme, replace host, strip query params, etc.) applied to a URL before routing rules are evaluated. Cannot execute arbitrary code.
_Avoid_: Transform, filter

**Fallback Policy**:
The global setting that decides what happens when no routing rule matches: show the picker, or open a specific configured browser/profile.
_Avoid_: Default browser (ambiguous with the OS-level default-browser concept)

**Source App**:
The application that originated the intercepted URL (captured via Apple Event `keyAddressAttr` → PID → bundle ID). A routing or rewrite rule can condition on zero, one, or many source apps; zero means "any."
_Avoid_: Sender, origin app

**Destination**:
Where a resolved URL is launched: a configured browser/profile today; future phases may add desktop apps, mail clients, or send-to-phone. Distinct from a "browser," which is the current-only destination kind.

**Shortlink Resolution**:
Network-backed expansion of a shortener URL (e.g. `bit.ly`) to its real target before routing, gated by a host allowlist and a timeout, off by default.
_Avoid_: Unshortening (implementation-level term, fine in code, not in settings copy)

**Tracking Cleanup**:
Built-in stripping of known tracking query parameters (utm_*, gclid, etc.) from a URL. A visible on/off toggle, not a user-editable rule list.
_Avoid_: URL cleaning (too broad — cleanup is specifically the tracking-parameter step, distinct from rewrite rules)

**Route Pipeline**:
The fixed order URLs pass through before launch: rewrite rules → shortlink resolution → tracking cleanup → routing-rule match → fallback (if no match).

**App Mode**:
Chowser runs as a regular macOS app with a Dock icon, Cmd-Tab presence, and native application menus. It does not show a menu-bar status item.

**Menu Bar Mode**:
Chowser runs as an accessory app with a menu-bar status item and no Dock icon. It exposes the same core commands as App Mode through the status-item menu.
