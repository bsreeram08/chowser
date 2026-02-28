# Chowser Agentic Setup

This page provides an automated way to configure Chowser using an AI agent (Claude, ChatGPT, or Cursor).

## Instructions

1.  **Copy the prompt below.**
2.  **Paste it into your AI agent.**
3.  **The agent will scan your system and generate your configuration files.**

---

```markdown
I have installed Chowser (bundle ID: in.sreerams.Chowser) on my Mac.
It's a browser chooser app that intercepts links. I need you to:

## Step 1: Discover my browsers and profiles

Scan my Mac for all installed browsers and their profiles:

- Chromium browsers (Chrome, Brave, Edge, Vivaldi, Arc, Opera):
  Check ~/Library/Application Support/{BrowserName}/Local State
  Parse the JSON → profile.info_cache → each key is a profile directory name
  (e.g. "Default", "Profile 1", "Profile 2")

- Firefox-based (Firefox, Zen, LibreWolf, Waterfox):
  Check ~/Library/Application Support/{BrowserName}/profiles.ini
  Parse the INI → each [Profile*] section → Name= is the profile name

- Safari: No profiles, just add it as-is.

For each browser+profile combo, produce a JSON object:
{ "name": "Chrome - Work", "bundleId": "com.google.Chrome", "shortcutKey": "1", "profile": "Profile 1" }

Save ALL of them as a JSON array in a file called ChowserBrowsers.json.

## Step 2: Generate routing rules

Based on my needs: [EDIT THIS — e.g. "work stuff in Chrome Work profile, personal browsing in Safari, dev docs in Firefox"]

For each rule, produce a JSON object:
{ "name": "Work GitHub", "hostPattern": "*.github.com", "pathPrefix": "/my-company", "browserBundleId": "com.google.Chrome", "profile": "Profile 1", "isEnabled": true }

hostPattern supports exact match (github.com) or wildcard (*.github.com).
pathPrefix is optional — only set it if you need path-level routing.

Save ALL rules as a JSON array in a file called ChowserRules.json.

## Step 3: Import into Chowser

Tell me to open Chowser → Menu Bar Icon → Settings:
- Browsers tab → click ⋯ menu → Import Browsers → select ChowserBrowsers.json
- Rules tab → click ⋯ menu → Import Rules → select ChowserRules.json
```
