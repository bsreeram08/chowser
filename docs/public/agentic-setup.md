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

## Step 3: Configure via API

1. **Check existing**: Call `GET /browsers` and `GET /rules`.
2. **Sync Browsers**: Call `POST /browsers` for each profile found.
   - Use the `apiSchema` to determine the payload (usually `name`, `bundleId`, `profile`, `shortcutKey`).
3. **Sync Rules**: Call `POST /rules` to set routing.
   - Example request: Open `*.github.com` in `Chrome - Work`.

## Step 4: Confirmation

Show me a summary table of the detected browsers and intended rules. **Ask for my confirmation** before making any `POST` or `DELETE` requests.

---
[CONTEXT FOR AI]
API server: {{API_SERVER_URL}}
Auth token: {{AUTH_TOKEN}}
