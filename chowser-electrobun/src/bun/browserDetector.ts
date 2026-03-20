// ---------------------------------------------------------------------------
// Browser detection — discover installed browsers and their profiles
// Supports macOS, Windows, and Linux.
// ---------------------------------------------------------------------------

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { spawnSync } from "node:child_process";
import type { InstalledBrowser, BrowserProfile } from "./models.ts";

const HOME = homedir();
const PLATFORM = process.platform;

// ---------------------------------------------------------------------------
// Shared profile readers (used on all platforms)
// ---------------------------------------------------------------------------

function readChromiumProfiles(localStatePath: string): BrowserProfile[] {
  try {
    if (!existsSync(localStatePath)) return [];
    const raw = readFileSync(localStatePath, "utf-8");
    const parsed = JSON.parse(raw) as {
      profile?: {
        info_cache?: Record<
          string,
          { name?: string; gaia_given_name?: string }
        >;
      };
    };
    const cache = parsed?.profile?.info_cache;
    if (!cache) return [];

    return Object.entries(cache).map(([dir, info]) => ({
      directory: dir,
      name: info.gaia_given_name || info.name || dir,
    }));
  } catch {
    return [];
  }
}

function readFirefoxProfiles(profilesIniPath: string): BrowserProfile[] {
  try {
    if (!existsSync(profilesIniPath)) return [];
    const raw = readFileSync(profilesIniPath, "utf-8");
    const profiles: BrowserProfile[] = [];

    let currentName: string | null = null;
    let currentPath: string | null = null;

    for (const line of raw.split("\n")) {
      const trimmed = line.trim();
      if (trimmed.startsWith("[Profile")) {
        if (currentName && currentPath) {
          // Launcher uses `-P <profile-name>`. Store the name in both fields so
          // BrowserConfig.profile (which reads from .directory) carries the name.
          profiles.push({ name: currentName, directory: currentName });
        }
        currentName = null;
        currentPath = null;
        continue;
      }
      if (trimmed.startsWith("Name=")) {
        currentName = trimmed.slice(5);
      } else if (trimmed.startsWith("Path=")) {
        currentPath = trimmed.slice(5);
      }
    }
    if (currentName && currentPath) {
      profiles.push({ name: currentName, directory: currentName });
    }

    return profiles;
  } catch {
    return [];
  }
}

// ===========================================================================
// macOS
// ===========================================================================

interface ChromiumBrowserSpec {
  name: string;
  appId: string;
  appName: string;
  localStatePath: string;
}

interface GeckoBrowserSpec {
  name: string;
  appId: string;
  appName: string;
  profilesIniPath: string;
}

const MAC_CHROMIUM_BROWSERS: ChromiumBrowserSpec[] = [
  {
    name: "Google Chrome",
    appId: "com.google.Chrome",
    appName: "Google Chrome.app",
    localStatePath: join(HOME, "Library", "Application Support", "Google", "Chrome", "Local State"),
  },
  {
    name: "Google Chrome Canary",
    appId: "com.google.Chrome.canary",
    appName: "Google Chrome Canary.app",
    localStatePath: join(HOME, "Library", "Application Support", "Google", "Chrome Canary", "Local State"),
  },
  {
    name: "Brave Browser",
    appId: "com.brave.Browser",
    appName: "Brave Browser.app",
    localStatePath: join(HOME, "Library", "Application Support", "BraveSoftware", "Brave-Browser", "Local State"),
  },
  {
    name: "Microsoft Edge",
    appId: "com.microsoft.edgemac",
    appName: "Microsoft Edge.app",
    localStatePath: join(HOME, "Library", "Application Support", "Microsoft Edge", "Local State"),
  },
  {
    name: "Vivaldi",
    appId: "com.vivaldi.Vivaldi",
    appName: "Vivaldi.app",
    localStatePath: join(HOME, "Library", "Application Support", "Vivaldi", "Local State"),
  },
  {
    name: "Opera",
    appId: "com.operasoftware.Opera",
    appName: "Opera.app",
    localStatePath: join(HOME, "Library", "Application Support", "com.operasoftware.Opera", "Local State"),
  },
  {
    name: "Arc",
    appId: "company.thebrowser.Browser",
    appName: "Arc.app",
    localStatePath: join(HOME, "Library", "Application Support", "Arc", "User Data", "Local State"),
  },
];

const MAC_GECKO_BROWSERS: GeckoBrowserSpec[] = [
  {
    name: "Firefox",
    appId: "org.mozilla.firefox",
    appName: "Firefox.app",
    profilesIniPath: join(HOME, "Library", "Application Support", "Firefox", "profiles.ini"),
  },
  {
    name: "Firefox Developer Edition",
    appId: "org.mozilla.firefoxdeveloperedition",
    appName: "Firefox Developer Edition.app",
    profilesIniPath: join(HOME, "Library", "Application Support", "Firefox", "profiles.ini"),
  },
  {
    name: "Zen Browser",
    appId: "app.zen-browser.zen",
    appName: "Zen Browser.app",
    profilesIniPath: join(HOME, "Library", "Application Support", "Zen", "profiles.ini"),
  },
  {
    name: "LibreWolf",
    appId: "io.gitlab.librewolf-community",
    appName: "LibreWolf.app",
    profilesIniPath: join(HOME, "Library", "Application Support", "LibreWolf", "profiles.ini"),
  },
];

const MAC_SIMPLE_BROWSERS = [
  { name: "Safari", appId: "com.apple.Safari", appName: "Safari.app" },
  {
    name: "Safari Technology Preview",
    appId: "com.apple.SafariTechnologyPreview",
    appName: "Safari Technology Preview.app",
  },
];

const MAC_APP_DIRS = ["/Applications", join(HOME, "Applications")];

function macFindApp(appName: string): string | null {
  for (const dir of MAC_APP_DIRS) {
    const candidate = join(dir, appName);
    if (existsSync(candidate)) return candidate;
  }
  // Fall back to mdfind for apps installed outside /Applications
  try {
    const result = spawnSync(
      "/usr/bin/mdfind",
      [`kMDItemFSName == "${appName}" && kMDItemContentType == "com.apple.application-bundle"`],
      { encoding: "utf-8", timeout: 3000 }
    );
    const first = (result.stdout ?? "").split("\n").map((p) => p.trim()).filter(Boolean)[0];
    return first ?? null;
  } catch {
    return null;
  }
}

function detectMacOS(): InstalledBrowser[] {
  const browsers: InstalledBrowser[] = [];

  for (const spec of MAC_SIMPLE_BROWSERS) {
    const path = macFindApp(spec.appName);
    if (path) browsers.push({ name: spec.name, appId: spec.appId, path, profiles: [] });
  }

  for (const spec of MAC_CHROMIUM_BROWSERS) {
    const path = macFindApp(spec.appName);
    if (!path) continue;
    browsers.push({ name: spec.name, appId: spec.appId, path, profiles: readChromiumProfiles(spec.localStatePath) });
  }

  for (const spec of MAC_GECKO_BROWSERS) {
    const path = macFindApp(spec.appName);
    if (!path) continue;
    browsers.push({ name: spec.name, appId: spec.appId, path, profiles: readFirefoxProfiles(spec.profilesIniPath) });
  }

  return browsers;
}

// ===========================================================================
// Windows
// ===========================================================================

// On Windows, BrowserConfig.appId uses the same bundle-ID-style logical key so
// routing rules are portable across platforms.  The launcher maps these to
// actual executable paths via WINDOWS_EXE_PATHS.

const LOCALAPPDATA = process.env["LOCALAPPDATA"] ?? join(HOME, "AppData", "Local");
const APPDATA = process.env["APPDATA"] ?? join(HOME, "AppData", "Roaming");
const PROGRAMFILES = process.env["PROGRAMFILES"] ?? "C:\\Program Files";
const PROGRAMFILES_X86 = process.env["PROGRAMFILES(X86)"] ?? "C:\\Program Files (x86)";

interface WinBrowserSpec {
  name: string;
  appId: string;
  /** Known executable paths to probe */
  exePaths: string[];
  /** Path to Chromium Local State (for profile discovery), if applicable */
  chromiumLocalState?: string;
  /** Path to Firefox profiles.ini, if applicable */
  firefoxProfilesIni?: string;
}

const WINDOWS_BROWSERS: WinBrowserSpec[] = [
  {
    name: "Google Chrome",
    appId: "com.google.Chrome",
    exePaths: [
      join(LOCALAPPDATA, "Google", "Chrome", "Application", "chrome.exe"),
      join(PROGRAMFILES, "Google", "Chrome", "Application", "chrome.exe"),
      join(PROGRAMFILES_X86, "Google", "Chrome", "Application", "chrome.exe"),
    ],
    chromiumLocalState: join(LOCALAPPDATA, "Google", "Chrome", "User Data", "Local State"),
  },
  {
    name: "Google Chrome Canary",
    appId: "com.google.Chrome.canary",
    exePaths: [join(LOCALAPPDATA, "Google", "Chrome SxS", "Application", "chrome.exe")],
    chromiumLocalState: join(LOCALAPPDATA, "Google", "Chrome SxS", "User Data", "Local State"),
  },
  {
    name: "Microsoft Edge",
    appId: "com.microsoft.edgemac",
    exePaths: [
      join(LOCALAPPDATA, "Microsoft", "Edge", "Application", "msedge.exe"),
      join(PROGRAMFILES, "Microsoft", "Edge", "Application", "msedge.exe"),
      join(PROGRAMFILES_X86, "Microsoft", "Edge", "Application", "msedge.exe"),
    ],
    chromiumLocalState: join(LOCALAPPDATA, "Microsoft", "Edge", "User Data", "Local State"),
  },
  {
    name: "Brave Browser",
    appId: "com.brave.Browser",
    exePaths: [
      join(LOCALAPPDATA, "BraveSoftware", "Brave-Browser", "Application", "brave.exe"),
      join(PROGRAMFILES, "BraveSoftware", "Brave-Browser", "Application", "brave.exe"),
    ],
    chromiumLocalState: join(LOCALAPPDATA, "BraveSoftware", "Brave-Browser", "User Data", "Local State"),
  },
  {
    name: "Vivaldi",
    appId: "com.vivaldi.Vivaldi",
    exePaths: [
      join(LOCALAPPDATA, "Vivaldi", "Application", "vivaldi.exe"),
      join(PROGRAMFILES, "Vivaldi", "Application", "vivaldi.exe"),
    ],
    chromiumLocalState: join(LOCALAPPDATA, "Vivaldi", "User Data", "Local State"),
  },
  {
    name: "Opera",
    appId: "com.operasoftware.Opera",
    exePaths: [
      join(LOCALAPPDATA, "Programs", "Opera", "opera.exe"),
      join(PROGRAMFILES, "Opera", "opera.exe"),
    ],
    chromiumLocalState: join(APPDATA, "Opera Software", "Opera Stable", "Local State"),
  },
  {
    name: "Firefox",
    appId: "org.mozilla.firefox",
    exePaths: [
      join(PROGRAMFILES, "Mozilla Firefox", "firefox.exe"),
      join(PROGRAMFILES_X86, "Mozilla Firefox", "firefox.exe"),
    ],
    firefoxProfilesIni: join(APPDATA, "Mozilla", "Firefox", "profiles.ini"),
  },
  {
    name: "Firefox Developer Edition",
    appId: "org.mozilla.firefoxdeveloperedition",
    exePaths: [
      join(PROGRAMFILES, "Firefox Developer Edition", "firefox.exe"),
      join(PROGRAMFILES_X86, "Firefox Developer Edition", "firefox.exe"),
    ],
    firefoxProfilesIni: join(APPDATA, "Mozilla", "Firefox", "profiles.ini"),
  },
];

function detectWindows(): InstalledBrowser[] {
  const browsers: InstalledBrowser[] = [];

  for (const spec of WINDOWS_BROWSERS) {
    const exePath = spec.exePaths.find((p) => existsSync(p));
    if (!exePath) continue;

    const profiles = spec.chromiumLocalState
      ? readChromiumProfiles(spec.chromiumLocalState)
      : spec.firefoxProfilesIni
        ? readFirefoxProfiles(spec.firefoxProfilesIni)
        : [];

    browsers.push({ name: spec.name, appId: spec.appId, path: exePath, profiles });
  }

  return browsers;
}

// ===========================================================================
// Linux
// ===========================================================================

interface LinuxBrowserSpec {
  name: string;
  appId: string;
  /** Candidate executable names looked up in $PATH */
  executables: string[];
  /** Chromium Local State path */
  chromiumLocalState?: string;
  /** Firefox profiles.ini path */
  firefoxProfilesIni?: string;
}

const XDG_CONFIG = process.env["XDG_CONFIG_HOME"] ?? join(HOME, ".config");

const LINUX_BROWSERS: LinuxBrowserSpec[] = [
  {
    name: "Google Chrome",
    appId: "com.google.Chrome",
    executables: ["google-chrome", "google-chrome-stable", "chromium-browser", "chromium"],
    chromiumLocalState: join(XDG_CONFIG, "google-chrome", "Local State"),
  },
  {
    name: "Brave Browser",
    appId: "com.brave.Browser",
    executables: ["brave-browser", "brave"],
    chromiumLocalState: join(XDG_CONFIG, "BraveSoftware", "Brave-Browser", "Local State"),
  },
  {
    name: "Microsoft Edge",
    appId: "com.microsoft.edgemac",
    executables: ["microsoft-edge", "msedge"],
    chromiumLocalState: join(XDG_CONFIG, "microsoft-edge", "Local State"),
  },
  {
    name: "Vivaldi",
    appId: "com.vivaldi.Vivaldi",
    executables: ["vivaldi", "vivaldi-stable"],
    chromiumLocalState: join(XDG_CONFIG, "vivaldi", "Local State"),
  },
  {
    name: "Opera",
    appId: "com.operasoftware.Opera",
    executables: ["opera"],
    chromiumLocalState: join(XDG_CONFIG, "opera", "Local State"),
  },
  {
    name: "Firefox",
    appId: "org.mozilla.firefox",
    executables: ["firefox", "firefox-esr"],
    firefoxProfilesIni: join(HOME, ".mozilla", "firefox", "profiles.ini"),
  },
  {
    name: "Firefox Developer Edition",
    appId: "org.mozilla.firefoxdeveloperedition",
    executables: ["firefox-developer-edition", "firefox"],
    firefoxProfilesIni: join(HOME, ".mozilla", "firefox", "profiles.ini"),
  },
  {
    name: "LibreWolf",
    appId: "io.gitlab.librewolf-community",
    executables: ["librewolf"],
    firefoxProfilesIni: join(HOME, ".librewolf", "profiles.ini"),
  },
  {
    name: "Zen Browser",
    appId: "app.zen-browser.zen",
    executables: ["zen", "zen-browser"],
    firefoxProfilesIni: join(HOME, ".zen", "profiles.ini"),
  },
];

const LINUX_SEARCH_DIRS = [
  "/usr/bin",
  "/usr/local/bin",
  "/opt/google/chrome",
  "/opt/brave.com/brave",
  join(HOME, ".local", "bin"),
];

function linuxFindExecutable(executables: string[]): string | null {
  // First try `which` for PATH-based discovery
  for (const exe of executables) {
    try {
      const result = spawnSync("which", [exe], { encoding: "utf-8", timeout: 2000 });
      const path = (result.stdout ?? "").trim();
      if (path && existsSync(path)) return path;
    } catch {}
  }
  // Fall back to probing known directories
  for (const dir of LINUX_SEARCH_DIRS) {
    for (const exe of executables) {
      const candidate = join(dir, exe);
      if (existsSync(candidate)) return candidate;
    }
  }
  return null;
}

function detectLinux(): InstalledBrowser[] {
  const browsers: InstalledBrowser[] = [];

  for (const spec of LINUX_BROWSERS) {
    const exePath = linuxFindExecutable(spec.executables);
    if (!exePath) continue;

    const profiles = spec.chromiumLocalState
      ? readChromiumProfiles(spec.chromiumLocalState)
      : spec.firefoxProfilesIni
        ? readFirefoxProfiles(spec.firefoxProfilesIni)
        : [];

    browsers.push({ name: spec.name, appId: spec.appId, path: exePath, profiles });
  }

  return browsers;
}

// ===========================================================================
// Public API
// ===========================================================================

/** Scan the system for installed browsers. Results are not cached. */
export function detectInstalledBrowsers(): InstalledBrowser[] {
  switch (PLATFORM) {
    case "win32":
      return detectWindows();
    case "linux":
      return detectLinux();
    default:
      return detectMacOS();
  }
}

/**
 * Return the known executable path for a browser by its logical appId.
 * Used by the launcher on Windows and Linux.
 */
export function resolveExecutablePath(appId: string): string | null {
  switch (PLATFORM) {
    case "win32": {
      const spec = WINDOWS_BROWSERS.find((s) => s.appId === appId);
      if (!spec) return null;
      return spec.exePaths.find((p) => existsSync(p)) ?? null;
    }
    case "linux": {
      const spec = LINUX_BROWSERS.find((s) => s.appId === appId);
      if (!spec) return null;
      return linuxFindExecutable(spec.executables);
    }
    default:
      return null; // macOS uses mdfind in the launcher
  }
}
