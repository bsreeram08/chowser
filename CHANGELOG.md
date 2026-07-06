# Changelog

All notable changes to Chowser are documented here.

## [3.9.3] - 2026-07-06

### Fixed
- **Link previews silently did nothing** when network lookups are off (the default since 3.9.0) — the picker now explains why and points to Settings → Behavior instead of showing nothing.

## [3.9.2] - 2026-07-06

### Fixed
- **"Check for Predefined Rewrites" always failed to decode the catalog.** 5 of the 6 hosted starter rules omitted an optional field, and Swift's default JSON decoding doesn't apply a field's default value to a missing key — it fails the whole response. Now tolerant of missing optional fields, matching the pattern already used elsewhere in the app.
- **Diagnostic logs and bug reports no longer record any visited hostname or local file path**, ever — previously, routing/launch/Handoff/AirDrop log lines included the destination host (and, for local files, the full file path), which could end up in a bug report attached to a public GitHub issue. Logs now record only the routing decision itself (rule name, destination browser).

## [3.9.1] - 2026-07-06

### Added
- **App Mode.** Chowser can now run as a regular Dock app instead of menu-bar-only — choose during onboarding, change anytime in Settings → General. Existing installs are asked once after updating.
- **MCP: full Settings API.** The local API now reads and writes every Settings preference (App Mode, fallback routing, network privacy, launch-at-login, hidden apps, picker appearance) via `GET`/`POST /settings`, so an AI assistant can configure Chowser conversationally, not just browsers/rules/rewrites.
- **MCP: headless start/stop.** `chowser://mcp/start` and `chowser://mcp/stop` let an agent with shell access turn the local API on, configure Chowser, and turn it off without opening the app UI.
- **Predefined rewrite rules.** Settings → Rewrites can check for a small hosted catalog of starter rewrite rules (HTTPS upgrade, tracking-parameter stripping) and offer to add them.

### Fixed
- **Handoff to nearby devices** could silently fail to advertise due to an activation-timing race, and the always-on background path never had a real chance of working in the first place (the picker deliberately doesn't steal focus) — now gated honestly and the explicit "Send to Phone" path is race-free.
- **The AI setup prompt was broken** for any AI assistant without a way to self-correct (e.g. inside Claude's app or Cowork) — it specified the wrong auth header and stale API response fields, so every request failed with 401. Corrected to match the real API.

## [3.9.0] - 2026-07-06

### Added
- **Fallback routing.** Unmatched links can now open directly in a chosen browser/profile instead of always showing the picker — configurable in Settings → Behavior. Existing installs keep today's picker-first behavior by default.
- **Multiple source apps per rule.** A single routing rule can now match links from several apps (e.g. Slack, Mail, and Linear all routing the same way) instead of needing one rule per app. Existing installs get an on-upgrade prompt offering to merge duplicate rules that only differed by source app.
- **URL rewrites.** New Settings → Rewrites section lets you strip tracking parameters, force HTTPS, replace hosts, or edit query parameters on a link before it's routed — with a live tester showing exactly what changed and why, no code required.
- **Picker URL editing.** The link shown in the picker can now be edited before choosing a browser, for one-off fixes to a malformed URL.
- **Network privacy controls.** Shortlink resolution and link-preview fetches are now off by default (including for existing installs, a deliberate change — see below), with a configurable timeout and an appendable allowlist of trusted shortener hosts.

### Changed
- **Shortlink resolution and link preview no longer contact the network automatically.** Both used to unshorten/preview every link without asking; both are now off by default, including on upgrade. A one-time notice explains the change the first time you hit the picker or open Settings after updating. Turn it back on in Settings → Behavior.

### Fixed
- **Regex host patterns are now checked for catastrophic backtracking before they can be saved**, in both routing rules and rewrites — a maliciously crafted link could otherwise freeze the app.

## [3.8.0] - 2026-07-03

### Added
- **Send to Phone.** New picker action for the current link: AirDrop it, show a scannable QR code, or copy the URL — reachable from a phone icon in the URL bar, the `I` shortcut, or the shortcuts help. Handoff advertises the link to nearby Apple devices while the menu is open.
- **Styled QR codes.** The QR renders in color — the site's own favicon color when a preview is loaded, with the favicon badge in the center. Custom QR color available in Settings → Appearance.
- **Report a Bug.** Settings → General → About bundles the last day's logs, app and macOS versions into a report file and opens a prefilled GitHub issue.
- **Diagnostic logging.** URL routing decisions, browser launches, AirDrop, Handoff, and QR failures now log to daily files (3-day retention) under Application Support.

### Changed
- **Decluttered picker footer.** The always-visible shortcut chip row is now a single `?` button that reveals the shortcuts on demand.
- **Link preview no longer resizes the picker.** All preview states reserve the same height, so the panel doesn't jump when metadata loads.

## [3.7.2] - 2026-06-25

### Fixed
- **Link preview no longer burns one-time links.** Clicking a magic-login, OAuth callback, email-confirm, or other single-use link used to silently fetch it for the preview — consuming the token before your browser opened, so the real click landed on "already used." The preview now detects these and skips the fetch, showing why instead.
- **Previews load for big pages like YouTube.** The preview only scanned the first 400KB of a page; sites that emit a large script blob before their metadata (YouTube puts it ~630KB in) came back blank. Now scans up to 1MB.

### Added
- **Honest preview states.** Instead of a blank panel, the picker now says what happened: "needs sign-in" for links behind a login (401/403), "page not found" for dead links (404), and "no preview available" for API/JSON endpoints and bare pages.

### Changed
- **Accent color now applies to every shortcut badge** (Esc, H, R), not just Launch.
- **Custom picker surface is translucent glass.** The custom tint used a flat fill that ignored the transparency slider; it's now a frosted-glass surface whose tint and see-through both respond to the slider.

## [3.7.1] - 2026-06-24

### Added
- **Appearance settings page** — a dedicated Appearance section in Settings gathers all picker-look controls in one place with a **live preview that embeds the real picker** (clicking a browser in the preview opens a sample URL for real).
- Picker customization: **tint color**, **transparency**, **corner radius**, and an **accent color override**, plus the existing layout / icon-size / label controls. A backdrop switcher (Light / Dark / Color / Checker) shows how the picker looks over different backgrounds.
- **Running-state dimming** — browsers that aren't currently open are faded in the picker so you see what's already running at a glance (toggle in Appearance).
- **Color scheme override** — force the picker to Light or Dark, or follow the system.
- **Link preview** — the picker shows the clicked link's title, description, and image (loaded async with a spinner) so you know what you're opening before you choose. Following redirects also **resolves shortlinks** to the real destination. Toggle in Appearance.
- **Clickable picker footer actions** — the P / H / R / Esc / ↵ hints are now real buttons, not just labels.
- **Browser engine badge** — browser rows show whether each browser is Chromium- or Firefox-based.
- Expanded browser detection to current-market browsers (Comet, Thorium, Helium, Wavebox, Sidekick, Whale, Yandex, Floorp, Mullvad, Basilisk, Pale Moon, Tor, and more).
- **Per-browser launch arguments** — set a normal-launch and a separate **private/incognito** argument template per browser (with `{profile}`/`{url}` placeholders) in Edit Browser. Works for any browser, not just the built-in Chromium/Firefox defaults.
- **MCP launch API** — the local API accepts `profile`, `customArguments`, and `privateArguments`, and a new `POST /browsers/preview` dry-run returns the exact framed launch command so an AI agent can research a browser's flags, preview the command, and confirm before saving.

### Fixed
- **Browsers settings page renders reliably** — it used a SwiftUI `List` that mis-laid-out inside `NavigationSplitView` (blank rows / collapsed sidebar until a window resize). Now uses the same `ScrollView` scaffold as the other settings pages.
- Accent-colored picker text (Launch, suggestions) stays legible — a brightness-aware accent prevents dark/black-on-dark.

### Notes
- **Profiles/launch arguments apply at launch only in the direct-download build.** macOS strips launch arguments from sandboxed apps, so the App Store build stores them (and keeps them portable) but may not pass them to the browser. The Edit Browser sheet and MCP API both say so. Auto-detecting profiles also requires the direct build.

### Changed
- Accent color across the picker now follows the user's accent override.
