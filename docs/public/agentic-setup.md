# Chowser Agentic Setup

This page provides an automated way to configure Chowser using an AI agent (Claude, ChatGPT, or Cursor).

## Instructions

1.  **Copy the prompt below.**
2.  **Paste it into your AI agent.**
3.  **The agent will scan your system, show you a preview, and import configuration.**

```markdown
I have installed Chowser (bundle ID: in.sreerams.Chowser) on my Mac.
It's a browser chooser app with a local MCP-style HTTP API server for configuration.

Your goal is to configure my browsers and routing rules.

## Step 1: Discover API Schema

Start by calling `GET /status`. This endpoint provides:
- App version and server health.
- **Full API schema** for all endpoints, including required and optional JSON fields for `POST` requests.
- Confirmation of the authentication header name.

## Step 2: Discover my browsers and profiles

Scan my Mac for all installed browsers and their profiles:

- **Chromium-based** (Chrome, Brave, Edge, Vivaldi, Arc, Dia, Opera):
  Check `~/Library/Application Support/{BrowserName}/Local State` or `~/Library/Application Support/{BrowserName}/User Data/Local State`.
  Parse the JSON → `profile.info_cache` → each key is a profile directory name (e.g. "Default", "Profile 1").

- **Firefox-based** (Firefox, Zen, LibreWolf, Waterfox):
  Check `~/Library/Application Support/{BrowserName}/profiles.ini`.
  Parse the INI → each `[Profile*]` section → `Name=` is the displayed profile name.

- **Safari**: No profiles, just add it as-is.

## Step 3: Configure via API

Based on my needs: [EDIT THIS — e.g. "Work stuff in Chrome Work profile, personal browsing in Safari, dev docs in Firefox"]

1. **Check existing**: Call `GET /browsers` and `GET /rules`.
2. **Push Browsers**: Call `POST /browsers` for each profile.
   - Example JSON: `{ "name": "Chrome - Work", "bundleId": "com.google.Chrome", "profile": "Profile 1", "shortcutKey": "1" }`
3. **Push Rules**: Call `POST /rules` to set routing.
   - Example JSON: `{ "name": "GitHub", "hostPattern": "*.github.com", "browserBundleId": "com.google.Chrome", "profile": "Profile 1" }`

## Step 4: Confirmation

Show me a summary table of the detected browsers and intended rules. **Ask for my confirmation** before making any `POST` or `DELETE` requests.

---
[CONTEXT FOR AI]
API server: {{API_SERVER_URL}}
Auth token: {{AUTH_TOKEN}} (Use in X-Chowser-Token header for POST/DELETE)
```
