// ---------------------------------------------------------------------------
// Browser launcher — open a URL in a specific browser / profile
// Cross-platform: macOS, Windows, Linux
// ---------------------------------------------------------------------------

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { BrowserConfig, ResolvedRoute } from "./models.ts";
import { resolveExecutablePath } from "./browserDetector.ts";

// ---------------------------------------------------------------------------
// Platform detection
// ---------------------------------------------------------------------------

const PLATFORM = process.platform; // 'darwin' | 'win32' | 'linux'

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
// Private-mode flags by browser (platform-specific)
// ---------------------------------------------------------------------------

function privateFlag(appId: string): string {
  if (CHROMIUM_APP_IDS.has(appId)) return "--incognito";
  if (appId.startsWith("org.mozilla") || appId.startsWith("app.zen-browser"))
    return "-private-window";
  if (appId === "com.apple.Safari") return ""; // Safari has no CLI flag
  return "--private";
}

/**
 * Private mode flags for Windows (Chromium-based browsers)
 */
function privateFlagWindows(appId: string): string {
  if (CHROMIUM_APP_IDS.has(appId)) return "--incognito";
  if (appId.startsWith("org.mozilla") || appId.startsWith("app.zen-browser"))
    return "-private-window";
  return "--private";
}

/**
 * Private mode flags for Linux (Chromium-based browsers)
 */
function privateFlagLinux(appId: string): string {
  if (CHROMIUM_APP_IDS.has(appId)) return "--incognito";
  if (appId.startsWith("org.mozilla") || appId.startsWith("app.zen-browser"))
    return "--private-window";
  return "--private";
}

// ---------------------------------------------------------------------------
// macOS: Resolve browser path from bundle ID using mdfind
// ---------------------------------------------------------------------------

function resolveAppPathMac(appId: string): string | null {
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
// Main launch function (cross-platform)
// ---------------------------------------------------------------------------

/**
 * Open `url` in the browser described by `browser` (or `route`).
 *
 * Strategy by platform:
 *   macOS:
 *     • Chromium with profile → `open -n -a "App.app" --args --profile-directory=<dir> <url>`
 *     • Firefox with profile  → `open -n -a "App.app" --args -P <profile> <url>`
 *     • Everything else       → `open -a <bundleId> <url>` (via LSOpenURLsWithRole)
 *   Windows:
 *     • Direct exe launch with arguments
 *     • Falls back to `start "" "url"` for simple launches
 *   Linux:
 *     • Try xdg-open first for simple launches
 *     • Direct exe launch with arguments for profile/private mode
 */
export function launchBrowser(
  url: string,
  browser: BrowserConfig,
  usePrivateMode = false
): void {
  const appId = browser.appId;

  switch (PLATFORM) {
    case "darwin":
      launchBrowserMac(url, browser, usePrivateMode);
      break;
    case "win32":
      launchBrowserWindows(url, browser, usePrivateMode);
      break;
    case "linux":
      launchBrowserLinux(url, browser, usePrivateMode);
      break;
    default:
      // Fallback to macOS behavior
      launchBrowserMac(url, browser, usePrivateMode);
  }
}

function launchBrowserMac(
  url: string,
  browser: BrowserConfig,
  usePrivateMode: boolean
): void {
  const appId = browser.appId;
  const appPath = resolveAppPathMac(appId);

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
    extraArgs.push(...parseCustomArguments(browser.customArguments));
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

function launchBrowserWindows(
  url: string,
  browser: BrowserConfig,
  usePrivateMode: boolean
): void {
  const appId = browser.appId;

  // Get executable path from browser detector
  let exePath = resolveExecutablePath(appId);

  // Build extra args list
  const extraArgs: string[] = [];

  if (usePrivateMode) {
    const flag = privateFlagWindows(appId);
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
    extraArgs.push(...parseCustomArguments(browser.customArguments));
  }

  if (exePath && existsSync(exePath)) {
    // Direct exe launch with arguments
    const args = [exePath, ...extraArgs, url];
    try {
      spawnSync(exePath, [...extraArgs, url], {
        timeout: 5000,
        windowsHide: true,
      });
      return;
    } catch {
      // Fall through to start command
    }
  }

  // Fallback: use start command to open URL (will use default browser)
  // This is less reliable but works when we can't find the browser exe
  try {
    spawnSync(
      "cmd",
      ["/c", "start", "", url],
      { timeout: 5000, windowsHide: true }
    );
  } catch (err) {
    console.error("[launcher] Failed to launch browser on Windows:", err);
  }
}

function launchBrowserLinux(
  url: string,
  browser: BrowserConfig,
  usePrivateMode: boolean
): void {
  const appId = browser.appId;

  // Get executable path from browser detector
  let exePath = resolveExecutablePath(appId);

  // Build extra args list
  const extraArgs: string[] = [];

  if (usePrivateMode) {
    const flag = privateFlagLinux(appId);
    if (flag) extraArgs.push(flag);
  }

  if (browser.profile) {
    if (CHROMIUM_APP_IDS.has(appId)) {
      extraArgs.push(`--profile-directory=${browser.profile}`);
    } else if (
      appId.startsWith("org.mozilla") ||
      appId.startsWith("app.zen-browser")
    ) {
      extraArgs.push("--profile", browser.profile);
    }
  }

  if (browser.customArguments) {
    extraArgs.push(...parseCustomArguments(browser.customArguments));
  }

  if (exePath && existsSync(exePath)) {
    // Direct exe launch with arguments
    try {
      spawnSync(exePath, [...extraArgs, url], {
        timeout: 5000,
      });
      return;
    } catch {
      // Fall through to xdg-open
    }
  }

  // Fallback: use xdg-open (will use default browser)
  // This is less reliable for specific browser launching but works as fallback
  try {
    spawnSync("xdg-open", [url], { timeout: 5000 });
  } catch (err) {
    console.error("[launcher] Failed to launch browser on Linux:", err);
  }
}

/**
 * Launch a URL using a resolved route + a browser lookup table.
 * Returns true if a browser was found and launched.
 *
 * When the route specifies a profile, prefer a BrowserConfig that matches
 * both appId AND profile; fall back to appId-only when no exact match exists.
 */
export function launchByRoute(
  url: string,
  route: ResolvedRoute,
  browsers: BrowserConfig[]
): boolean {
  // Prefer exact appId+profile match so the right config (name, customArgs,
  // shortcutKey) is used when multiple entries share the same bundle ID.
  const browser =
    (route.profile
      ? browsers.find(
          (b) =>
            b.appId === route.browserAppId && b.profile === route.profile
        )
      : undefined) ?? browsers.find((b) => b.appId === route.browserAppId);

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
export function registerAsDefaultBrowser(_appId: string): void {
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

// ---------------------------------------------------------------------------
// Custom argument parser
// ---------------------------------------------------------------------------

/**
 * Parse a custom-arguments string into an argv array.
 * Supports single-quoted and double-quoted groups (preserving spaces within
 * quotes) and backslash-escaped characters, matching POSIX shell tokenization.
 *
 * Examples:
 *   '--flag="hello world"'  → ['--flag=hello world']
 *   "--user 'John Doe'"     → ['--user', 'John Doe']
 *   '--no-sandbox'          → ['--no-sandbox']
 */
function parseCustomArguments(args: string): string[] {
  const tokens: string[] = [];
  let current = "";
  let i = 0;

  while (i < args.length) {
    const ch = args[i];

    if (ch === "\\") {
      // Backslash escape — include next char literally
      if (i + 1 < args.length) current += args[++i];
    } else if (ch === "'") {
      // Single-quoted block — no escape processing inside.
      // i++ moves past the opening quote; the inner loop consumes characters
      // until the closing quote (leaving i pointing AT it); the outer i++ below
      // then advances past the closing quote.
      i++;
      while (i < args.length && args[i] !== "'") {
        current += args[i++];
      }
      // i now points at the closing "'" (or past end if unclosed).
      // The outer i++ at the bottom of this loop advances past it.
    } else if (ch === '"') {
      // Double-quoted block — backslash escapes still apply.
      // Same opening/closing quote advancement logic as single quotes above.
      i++;
      while (i < args.length && args[i] !== '"') {
        if (args[i] === "\\" && i + 1 < args.length) {
          current += args[++i];
        } else {
          current += args[i];
        }
        i++;
      }
      // i now points at the closing '"' (or past end if unclosed).
      // The outer i++ at the bottom of this loop advances past it.
    } else if (ch === " " || ch === "\t") {
      if (current.length > 0) {
        tokens.push(current);
        current = "";
      }
    } else {
      current += ch;
    }

    // Advance past the current character (or past the closing quote for
    // quoted blocks, because i was left pointing at it above).
    i++;
  }

  if (current.length > 0) tokens.push(current);
  return tokens;
}
