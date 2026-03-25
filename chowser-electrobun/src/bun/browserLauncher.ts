// ---------------------------------------------------------------------------
// Browser launcher — open a URL in a specific browser / profile
// ---------------------------------------------------------------------------

import { spawnSync } from "node:child_process";
import type { BrowserConfig, ResolvedRoute } from "./models.ts";
import { resolveExecutablePath } from "./browserDetector.ts";

const PLATFORM = process.platform;

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
 * Launch a URL in the given browser on Windows or Linux using Bun.spawn().
 * The process is detached so Chowser does not wait for the browser to exit.
 *
 * Argument structure:
 *   Chromium: <exe> [--profile-directory=<dir>] [--incognito] [customArgs] <url>
 *   Firefox:  <exe> [-P <profile>] [-private-window] [customArgs] <url>
 *   Other:    <exe> [customArgs] <url>
 */
function launchBrowserNative(
  url: string,
  browser: BrowserConfig,
  usePrivateMode: boolean
): void {
  const appId = browser.appId;
  const exePath = resolveExecutablePath(appId);

  if (!exePath) {
    console.warn(`[launcher] Could not resolve executable for ${appId}`);
    return;
  }

  const args: string[] = [];

  if (browser.profile) {
    if (CHROMIUM_APP_IDS.has(appId)) {
      args.push(`--profile-directory=${browser.profile}`);
    } else if (
      appId.startsWith("org.mozilla") ||
      appId.startsWith("app.zen-browser") ||
      appId.startsWith("io.gitlab.librewolf")
    ) {
      args.push("-P", browser.profile);
    }
  }

  if (usePrivateMode) {
    const flag = privateFlag(appId);
    if (flag) args.push(flag);
  }

  if (browser.customArguments) {
    args.push(...parseCustomArguments(browser.customArguments));
  }

  args.push(url);

  // Spawn detached — Chowser must not block waiting for the browser to exit.
  // `unref()` releases the child from the parent process.
  try {
    const proc = Bun.spawn([exePath, ...args], {
      stdio: ["ignore", "ignore", "ignore"],
    });
    proc.unref();
  } catch (err) {
    console.error(`[launcher] Failed to spawn ${exePath}:`, err);
  }
}

/**
 * Open `url` in the browser described by `browser` (or `route`).
 *
 * Strategy:
 *   macOS:
 *     • Chromium with profile → `open -n -a "App.app" --args --profile-directory=<dir> <url>`
 *     • Firefox with profile  → `open -n -a "App.app" --args -P <profile> <url>`
 *     • Everything else       → `open -b <bundleId> <url>`
 *   Windows / Linux:
 *     • Spawn exe directly via Bun.spawn() (detached) with profile + private flags
 */
export function launchBrowser(
  url: string,
  browser: BrowserConfig,
  usePrivateMode = false
): void {
  if (PLATFORM === "win32" || PLATFORM === "linux") {
    launchBrowserNative(url, browser, usePrivateMode);
    return;
  }

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
