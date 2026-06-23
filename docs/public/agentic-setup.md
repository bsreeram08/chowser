I have installed Chowser (bundle ID: in.sreerams.Chowser) on my Mac.
It's a browser chooser app with a local MCP-style HTTP API server for configuration.

Your goal is to configure my browsers and routing rules.

## Step 1: Discover API & Schema

Call `GET /status`. This responds with:
- `appName`, `version`, `serverHealth`.
- `apiSchema`: A JSON object detailing all endpoints and their expected JSON payloads. **Always consult this schema before making POST requests.**
- `authHeader`: The key to use in your headers (usually `X-Chowser-Token`).

## Step 2: Discover my browsers and profiles

Scan my Mac for installed browsers and extract their profiles:

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

1. **Check existing**: Call `GET /browsers` and `GET /rules`.
2. **Preview before committing**: Call `POST /browsers/preview` with the candidate `bundleId`, `profile`, `customArguments`, `privateArguments`, and a sample `url`. Read back the exact `command` and `deliveredArguments`. Confirm with me that it would open the right profile/window. **Test it** if possible.
3. **Sync Browsers**: Call `POST /browsers` for each profile found, including `profile`, `customArguments`, and `privateArguments` (consult `apiSchema` for the payload).
4. **Sync Rules**: Call `POST /rules` to set routing. Example: open `*.github.com` in `Chrome - Work`.

**CAVEATS**:
- **App Store build**: macOS sandboxing may strip launch arguments, so profiles/args are stored but may not apply at launch (`launchArgumentsSupported:false` in responses). They apply reliably in the direct-download build.
- **Arc & Dia**: single-instance browsers that often ignore profile flags on an already-running instance — verify via `POST /browsers/preview` and a real test before relying on them.

## Step 4b: Route links to native apps (any app, even brand-new ones)

Many links are better opened in a desktop app than a browser (Slack, Zoom, Figma, Notion, Linear, and **newer apps released after this prompt was written**). You are not limited to a built-in list — configure ANY app:

1. **Identify the app**: find its bundle ID. On disk: `mdls -name kMDItemCFBundleIdentifier /Applications/<App>.app`. If I name an app you don't recognize, **web-search** "<app name> macOS bundle identifier" and the domains it owns.
2. **Find its domains**: web-search the web domains the app handles (e.g. a new chat app "Acme" → `acme.com`, `app.acme.com`). These become the routing rules.
3. **Add the app as a target**: `POST /browsers` with `name` + `bundleId` (no profile needed for most apps).
4. **Add the routing rules**: `POST /rules` with `hostPattern` = each domain and `browserBundleId` = the app's bundle ID.
5. **Verify**: `POST /browsers/preview` with the app's bundleId + a sample link to see the resolved launch command, then ask me to confirm and test one link.

Launching uses macOS's universal-link handling, so this works for any app that registers its web domains (most modern apps do). If an app only opens via a custom URL scheme (e.g. `acme://`) and not its https links, tell me — that needs a per-app scheme rewrite Chowser doesn't do yet.

## Step 5: Confirmation

Show me a summary table of detected browsers, native-app routes, the previewed launch commands, and intended rules. **Ask for my confirmation** before making any `POST` or `DELETE` requests.

---
[CONTEXT FOR AI]
API server: {{API_SERVER_URL}}
Auth token: {{AUTH_TOKEN}}
