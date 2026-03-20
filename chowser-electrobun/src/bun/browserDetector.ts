// ---------------------------------------------------------------------------
// Browser detection — discover installed browsers and their profiles
// ---------------------------------------------------------------------------

import {
  existsSync,
  readFileSync,
} from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { InstalledBrowser, BrowserProfile } from "./models.ts";

const HOME = homedir();

// ---------------------------------------------------------------------------
// Well-known Chromium-family browsers
// ---------------------------------------------------------------------------

interface ChromiumBrowserSpec {
  name: string;
  appId: string;
  appName: string;
  localStateRelativePath: string;
}

const CHROMIUM_BROWSERS: ChromiumBrowserSpec[] = [
  {
    name: "Google Chrome",
    appId: "com.google.Chrome",
    appName: "Google Chrome.app",
    localStateRelativePath: join(
      HOME,
      "Library",
      "Application Support",
      "Google",
      "Chrome",
      "Local State"
    ),
  },
  {
    name: "Google Chrome Canary",
    appId: "com.google.Chrome.canary",
    appName: "Google Chrome Canary.app",
    localStateRelativePath: join(
      HOME,
      "Library",
      "Application Support",
      "Google",
      "Chrome Canary",
      "Local State"
    ),
  },
  {
    name: "Brave Browser",
    appId: "com.brave.Browser",
    appName: "Brave Browser.app",
    localStateRelativePath: join(
      HOME,
      "Library",
      "Application Support",
      "BraveSoftware",
      "Brave-Browser",
      "Local State"
    ),
  },
  {
    name: "Microsoft Edge",
    appId: "com.microsoft.edgemac",
    appName: "Microsoft Edge.app",
    localStateRelativePath: join(
      HOME,
      "Library",
      "Application Support",
      "Microsoft Edge",
      "Local State"
    ),
  },
  {
    name: "Vivaldi",
    appId: "com.vivaldi.Vivaldi",
    appName: "Vivaldi.app",
    localStateRelativePath: join(
      HOME,
      "Library",
      "Application Support",
      "Vivaldi",
      "Local State"
    ),
  },
  {
    name: "Opera",
    appId: "com.operasoftware.Opera",
    appName: "Opera.app",
    localStateRelativePath: join(
      HOME,
      "Library",
      "Application Support",
      "com.operasoftware.Opera",
      "Local State"
    ),
  },
  {
    name: "Arc",
    appId: "company.thebrowser.Browser",
    appName: "Arc.app",
    localStateRelativePath: join(
      HOME,
      "Library",
      "Application Support",
      "Arc",
      "User Data",
      "Local State"
    ),
  },
];

// ---------------------------------------------------------------------------
// Well-known Gecko-family browsers
// ---------------------------------------------------------------------------

interface GeckoBrowserSpec {
  name: string;
  appId: string;
  appName: string;
  profilesIniPath: string;
}

const GECKO_BROWSERS: GeckoBrowserSpec[] = [
  {
    name: "Firefox",
    appId: "org.mozilla.firefox",
    appName: "Firefox.app",
    profilesIniPath: join(
      HOME,
      "Library",
      "Application Support",
      "Firefox",
      "profiles.ini"
    ),
  },
  {
    name: "Firefox Developer Edition",
    appId: "org.mozilla.firefoxdeveloperedition",
    appName: "Firefox Developer Edition.app",
    profilesIniPath: join(
      HOME,
      "Library",
      "Application Support",
      "Firefox",
      "profiles.ini"
    ),
  },
  {
    name: "Zen Browser",
    appId: "app.zen-browser.zen",
    appName: "Zen Browser.app",
    profilesIniPath: join(
      HOME,
      "Library",
      "Application Support",
      "Zen",
      "profiles.ini"
    ),
  },
  {
    name: "LibreWolf",
    appId: "io.gitlab.librewolf-community",
    appName: "LibreWolf.app",
    profilesIniPath: join(
      HOME,
      "Library",
      "Application Support",
      "LibreWolf",
      "profiles.ini"
    ),
  },
];

// ---------------------------------------------------------------------------
// Safari (no profiles)
// ---------------------------------------------------------------------------

const SIMPLE_BROWSERS: Array<{ name: string; appId: string; appName: string }> =
  [
    {
      name: "Safari",
      appId: "com.apple.Safari",
      appName: "Safari.app",
    },
    {
      name: "Safari Technology Preview",
      appId: "com.apple.SafariTechnologyPreview",
      appName: "Safari Technology Preview.app",
    },
  ];

const APP_DIRS = ["/Applications", join(HOME, "Applications")];

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/** Scan the system for installed browsers.  Results are not cached. */
export function detectInstalledBrowsers(): InstalledBrowser[] {
  const browsers: InstalledBrowser[] = [];

  // Safari and other simple browsers
  for (const spec of SIMPLE_BROWSERS) {
    const path = findApp(spec.appName);
    if (path) {
      browsers.push({ name: spec.name, appId: spec.appId, path, profiles: [] });
    }
  }

  // Chromium-family
  for (const spec of CHROMIUM_BROWSERS) {
    const path = findApp(spec.appName);
    if (!path) continue;
    const profiles = readChromiumProfiles(spec.localStateRelativePath);
    browsers.push({ name: spec.name, appId: spec.appId, path, profiles });
  }

  // Gecko-family
  for (const spec of GECKO_BROWSERS) {
    const path = findApp(spec.appName);
    if (!path) continue;
    const profiles = readFirefoxProfiles(spec.profilesIniPath);
    browsers.push({ name: spec.name, appId: spec.appId, path, profiles });
  }

  return browsers;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

function findApp(appName: string): string | null {
  for (const dir of APP_DIRS) {
    const candidate = join(dir, appName);
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

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
      name:
        info.gaia_given_name || info.name || dir,
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
    let isRelative = true;

    for (const line of raw.split("\n")) {
      const trimmed = line.trim();
      if (trimmed.startsWith("[Profile")) {
        if (currentName && currentPath) {
          profiles.push({ name: currentName, directory: currentPath });
        }
        currentName = null;
        currentPath = null;
        isRelative = true;
        continue;
      }
      if (trimmed.startsWith("Name=")) {
        currentName = trimmed.slice(5);
      } else if (trimmed.startsWith("Path=")) {
        currentPath = trimmed.slice(5);
      } else if (trimmed.startsWith("IsRelative=")) {
        isRelative = trimmed.slice(11) === "1";
      }
    }
    if (currentName && currentPath) {
      profiles.push({ name: currentName, directory: currentPath });
    }

    return profiles;
  } catch {
    return [];
  }
}
