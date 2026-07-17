I have installed Chowser (bundle ID: in.sreerams.Chowser) on my Mac.
It's a browser chooser app with a local, opt-in, localhost-only HTTP API server for configuration.

Your goal is to configure my browsers, routing rules, and (optionally) URL rewrites.

## Step 0: Check what tools you have

- **If you have local shell/file access** (e.g. Claude Code, an agent with Bash/Read tools, or Computer Use): follow every step below, including scanning the filesystem in Step 2. You can also turn the API on and off yourself — see the shell-only flow below — instead of asking me to click "Start API Server."
- **If you only have HTTP fetch access, no filesystem access** (e.g. a plain chat app, "cowork," or similar): skip the filesystem scan in Step 2 — you can't read local files. Instead ask me directly which browsers I use and what profile names/directories they have, then continue from Step 3. You'll need me to start the API server and give you the URL/token below, since you can't run shell commands.
- **If you have neither** (no fetch tool, no shell): you cannot complete this setup. Tell me so plainly instead of guessing or pretending to have called the API.

### Shell-only flow: turn the API on, do the work, turn it off

If you have shell access, you don't need me to open Settings at all:

```
open "chowser://mcp/start"
cat ~/Library/Application\ Support/Chowser/mcp-session.json
```

That file has `port` and `authToken` — build requests as `http://localhost:<port>` with header `Authorization: Bearer <authToken>`. When you're completely done configuring, turn it back off:

```
open "chowser://mcp/stop"
```

(This removes the session file too.) Do this at the end of the session, not between individual requests — there's no need to restart the server for every call.

## Step 1: Authenticate & discover the API

Every request (including this one) requires this exact header:

```
Authorization: Bearer <token>
```

The token is provided at the bottom of this prompt under `[CONTEXT FOR AI]`. There is no other header name — do not send `X-Chowser-Token` or similar, it will be rejected with 401.

Call `GET /status` with that header. The response contains:
- `status`, `app`, `version` — health check and app version.
- `browsers_count`, `rules_count`, `rewrites_count` — current counts.
- `endpoints` — an array describing every available endpoint (`method`, `path`, `description`, `body_fields`/`query_params`/`response_fields` as applicable). **Always consult this before making POST requests** — it reflects the exact fields this running version accepts, which can be newer than this document.

## Step 2: Discover my browsers and profiles

Scan my Mac for installed browsers and extract their profiles (skip this whole step, per Step 0, if you don't have filesystem access — ask me instead):

- **Chromium-based** (Chrome, Brave, Edge, Vivaldi, Arc, **Dia**, Opera):
  Check `~/Library/Application Support/{BrowserName}/User Data/Local State` or `~/Library/Application Support/{BrowserName}/Local State`.
  *Note: Arc & Dia usually have a `User Data` subfolder.*

  Parse the JSON → `profile.info_cache` → Each key is a directory name (e.g., "Default", "Profile 1"). The inner object has the profile name.

- **Firefox-based** (Firefox, Zen, LibreWolf, Waterfox):
  Check `~/Library/Application Support/{BrowserName}/profiles.ini`.
  Parse the INI → Each `[Profile*]` section → `Name=` is the display name, `Path=` is the directory.

- **Safari**: No profiles needed. Bundle ID: `com.apple.Safari`.

## Step 3: Research launch arguments per browser

Profiles and private windows are driven by per-browser launch arguments. For each browser you intend to configure, determine the correct CLI flags (web-search the exact flags for that specific browser if unsure):
- `customArguments`: the normal-launch template, e.g. Chrome/Brave/Edge `--profile-directory={profile}`, Firefox/Zen `-P {profile}`.
- `privateArguments`: the private/incognito template, e.g. Chrome/Brave/Edge `--incognito --profile-directory={profile}`, Firefox/Zen `-private -P {profile}`.
- Placeholders `{profile}` and `{url}` are substituted at launch (`{url}` optional — appended if omitted).

## Step 4: Configure via API

1. **Check existing**: Call `GET /browsers`, `GET /rules`, `GET /rewrites`, `GET /settings`.
2. **Preview before committing**: Call `POST /browsers/preview` with the candidate `bundleId`, `profile`, `customArguments`, `privateArguments`, and a sample `url`. Read back the exact `command` and `deliveredArguments`. Confirm with me that it would open the right profile/window. **Test it** if possible.
3. **Sync Browsers**: Call `POST /browsers` for each profile found, including `profile`, `customArguments`, and `privateArguments`.
4. **Sync Rules**: Call `POST /rules` to set routing. Example: open `*.github.com` in `Chrome - Work`.
5. **App-level settings**: `GET`/`POST /settings` covers the entire Settings app — App Mode, fallback routing, network privacy, launch-at-login, hidden apps, and every picker appearance/behavior preference. If I ask conversationally for something like "turn on dark mode for the picker" or "stop launching at login," call `GET /settings` first to see current values, then `POST` only the field(s) that changed. Don't touch settings I didn't ask about.

**CAVEATS**:
- **App Store build**: macOS sandboxing may strip launch arguments, so profiles/args are stored but may not apply at launch (`launchArgumentsSupported:false` in responses). They apply reliably in the direct-download build.
- **Arc & Dia**: single-instance browsers that often ignore profile flags on an already-running instance — verify via `POST /browsers/preview` and a real test before relying on them.

## Step 5: Offer the signed rewrite catalog

Chowser publishes a signed catalog of predefined URL rewrite rules (tracking-parameter cleanup, HTTPS upgrade, etc.). Catalog installation is intentionally handled by Chowser's Settings UI so the app can verify the detached signature, show exact actions and risk warnings, and retain signed provenance.

Do not fetch the raw JSON and copy entries into `POST /rewrites`; that bypasses Chowser's catalog verification and provenance boundary. Offer to open Settings with `open "chowser://settings"`, then ask me to use **Rewrites → Browse Predefined Rewrites** and select the rules I want. You may inspect `GET /rewrites` to explain my current configuration, but treat the public JSON as untrusted unless it has been verified against its detached signature and Chowser's pinned keyring.

## Step 6: Confirmation

Show me a summary table of detected browsers, the previewed launch commands, intended rules, and any rewrite rules you're proposing. **Ask for my confirmation** before making any `POST` or `DELETE` requests.

The real API server URL and Authorization token are appended after this document — use those exact values, not placeholders.
