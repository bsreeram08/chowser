// ---------------------------------------------------------------------------
// Browser launcher — open a URL in a specific browser / profile
// ---------------------------------------------------------------------------

import { spawnSync } from "node:child_process";
import type { BrowserConfig, ResolvedRoute } from "./models.ts";

// ---------------------------------------------------------------------------
// Chromium-family bundle IDs that support --profile-directory
// ---------------------------------------------------------------------------

const CHROMIUM_APP_IDS = new Set([
  "com.google.Chrome",
  "com.google.Chrome.canary",
  "com.brave.Browser",
  "com.microsoft.edgemac",
  "com.vivaldi.Vivaldi",
  "com.operasoftware.Opera",
  "company.thebrowser.Browser",
  "com.google.Chrome.beta",
  "com.google.Chrome.dev",
]);

// ---------------------------------------------------------------------------
// Private-mode flags by browser
// ---------------------------------------------------------------------------

function privateFlag(appId: string): string {
  if (CHROMIUM_APP_IDS.has(appId)) return "--incognito";
  if (appId.startsWith("org.mozilla") || appId.startsWith("app.zen-browser"))
    return "-private-window";
  if (appId === "com.apple.Safari") return ""; // Safari has no CLI flag
  return "--private";
}

// ---------------------------------------------------------------------------
// Resolve browser path from bundle ID
// ---------------------------------------------------------------------------

function resolveAppPath(appId: string): string | null {
  try {
    const result = spawnSync(
      "/usr/bin/mdfind",
      [`kMDItemCFBundleIdentifier == "${appId}"`],
      { encoding: "utf-8", timeout: 3000 }
    );
    const paths = (result.stdout ?? "")
      .split("\n")
      .map((p) => p.trim())
      .filter(Boolean);
    return paths[0] ?? null;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Main launch function
// ---------------------------------------------------------------------------

/**
 * Open `url` in the browser described by `browser` (or `route`).
 *
 * Strategy:
 *   • Chromium with profile → `open -n -a "App.app" --args --profile-directory=<dir> <url>`
 *   • Firefox with profile  → `open -n -a "App.app" --args -P <profile> <url>`
 *   • Everything else       → `open -a <bundleId> <url>` (via LSOpenURLsWithRole)
 */
export function launchBrowser(
  url: string,
  browser: BrowserConfig,
  usePrivateMode = false
): void {
  const appId = browser.appId;
  const appPath = resolveAppPath(appId);

  // Build extra args list
  const extraArgs: string[] = [];

  if (usePrivateMode) {
    const flag = privateFlag(appId);
    if (flag) extraArgs.push(flag);
  }

  if (browser.profile) {
    if (CHROMIUM_APP_IDS.has(appId)) {
      extraArgs.push(`--profile-directory=${browser.profile}`);
    } else if (
      appId.startsWith("org.mozilla") ||
      appId.startsWith("app.zen-browser")
    ) {
      extraArgs.push("-P", browser.profile);
    }
  }

  if (browser.customArguments) {
    extraArgs.push(...browser.customArguments.split(/\s+/).filter(Boolean));
  }

  if (appPath && extraArgs.length > 0) {
    // Profile/flag-aware launch: `open -n -a "<App.app>" --args [flags] <url>`
    const args = ["-n", "-a", appPath, "--args", ...extraArgs, url];
    const result = spawnSync("/usr/bin/open", args, { timeout: 5000 });
    if (result.status === 0) return;
    // Fall through to plain open on failure
  }

  // Plain launch by bundle ID
  const args = ["-b", appId, url];
  spawnSync("/usr/bin/open", args, { timeout: 5000 });
}

/**
 * Launch a URL using a resolved route + a browser lookup table.
 * Returns true if a browser was found and launched.
 */
export function launchByRoute(
  url: string,
  route: ResolvedRoute,
  browsers: BrowserConfig[]
): boolean {
  const browser = browsers.find((b) => b.appId === route.browserAppId);
  if (!browser) return false;

  // Override profile from route if the browser itself doesn't specify one
  const effectiveBrowser: BrowserConfig = {
    ...browser,
    profile: route.profile ?? browser.profile,
  };

  launchBrowser(url, effectiveBrowser, route.usePrivateMode);
  return true;
}

/**
 * Register Chowser as the default browser for http and https.
 * On macOS we use the `defaultbrowser` CLI tool if available, or fall back to
 * `open x-apple.systempreferences:com.apple.preferences.generalIn`.
 */
export function registerAsDefaultBrowser(appId: string): void {
  // Attempt via lsregister or defaultbrowser helper (must be installed separately)
  const result = spawnSync(
    "/usr/bin/open",
    [
      "x-apple.systempreferences:com.apple.preferences.generalIn",
    ],
    { timeout: 5000 }
  );
  if (result.status !== 0) {
    console.warn("[launcher] Could not open System Preferences to set default browser");
  }
}
