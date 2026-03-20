// ---------------------------------------------------------------------------
// Browser detector tests
// ---------------------------------------------------------------------------

import { describe, test, expect, beforeAll, afterAll, beforeEach } from "bun:test";
import { mkdirSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { detectInstalledBrowsers, resolveExecutablePath } from "./browserDetector.ts";
import type { InstalledBrowser, BrowserProfile } from "./models.ts";

// ---------------------------------------------------------------------------
// readChromiumProfiles — copied from browserDetector.ts for direct testing
// (The function is not exported; this is a faithful copy for unit testing.)
// ---------------------------------------------------------------------------

function readChromiumProfiles(localStatePath: string): BrowserProfile[] {
  try {
    if (!existsSync(localStatePath)) return [];
    const { readFileSync } = require("node:fs");
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

// ---------------------------------------------------------------------------
// readFirefoxProfiles — copied from browserDetector.ts for direct testing
// ---------------------------------------------------------------------------

function readFirefoxProfiles(profilesIniPath: string): BrowserProfile[] {
  try {
    if (!existsSync(profilesIniPath)) return [];
    const { readFileSync } = require("node:fs");
    const raw = readFileSync(profilesIniPath, "utf-8");
    const profiles: BrowserProfile[] = [];

    let currentName: string | null = null;
    let currentPath: string | null = null;

    for (const line of raw.split("\n")) {
      const trimmed = line.trim();
      if (trimmed.startsWith("[Profile")) {
        if (currentName && currentPath) {
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

// ---------------------------------------------------------------------------
// Temp directory helper
// ---------------------------------------------------------------------------

let tempBase: string;

function tempDir(suffix: string): string {
  const dir = join(tempBase, suffix);
  mkdirSync(dir, { recursive: true });
  return dir;
}

beforeAll(() => {
  tempBase = join(tmpdir(), `chowser-detector-test-${Date.now()}`);
  mkdirSync(tempBase, { recursive: true });
});

afterAll(() => {
  rmSync(tempBase, { recursive: true, force: true });
});

// ===========================================================================
// readChromiumProfiles tests
// ===========================================================================

describe("readChromiumProfiles", () => {
  test("returns empty array for nonexistent file", () => {
    expect(readChromiumProfiles("/nonexistent/path/Local State")).toEqual([]);
  });

  test("returns empty array for empty file", () => {
    const dir = tempDir("chrome-empty");
    const path = join(dir, "Local State");
    writeFileSync(path, "");
    expect(readChromiumProfiles(path)).toEqual([]);
  });

  test("returns empty array for invalid JSON", () => {
    const dir = tempDir("chrome-invalid-json");
    const path = join(dir, "Local State");
    writeFileSync(path, "not json at all");
    expect(readChromiumProfiles(path)).toEqual([]);
  });

  test("returns empty array when profile key is missing", () => {
    const dir = tempDir("chrome-no-profile");
    const path = join(dir, "Local State");
    writeFileSync(path, JSON.stringify({ other: "data" }));
    expect(readChromiumProfiles(path)).toEqual([]);
  });

  test("returns empty array when info_cache is missing", () => {
    const dir = tempDir("chrome-no-info-cache");
    const path = join(dir, "Local State");
    writeFileSync(path, JSON.stringify({ profile: { other: "data" } }));
    expect(readChromiumProfiles(path)).toEqual([]);
  });

  test("returns empty array when info_cache is empty", () => {
    const dir = tempDir("chrome-empty-cache");
    const path = join(dir, "Local State");
    writeFileSync(path, JSON.stringify({ profile: { info_cache: {} } }));
    expect(readChromiumProfiles(path)).toEqual([]);
  });

  test("parses single profile with gaia_given_name", () => {
    const dir = tempDir("chrome-single-gaia");
    const path = join(dir, "Local State");
    writeFileSync(
      path,
      JSON.stringify({
        profile: {
          info_cache: {
            Default: { name: "Person 1", gaia_given_name: "Alice" },
          },
        },
      })
    );
    const profiles = readChromiumProfiles(path);
    expect(profiles).toHaveLength(1);
    expect(profiles[0].directory).toBe("Default");
    expect(profiles[0].name).toBe("Alice");
  });

  test("prefers gaia_given_name over name", () => {
    const dir = tempDir("chrome-gaia-priority");
    const path = join(dir, "Local State");
    writeFileSync(
      path,
      JSON.stringify({
        profile: {
          info_cache: {
            Default: { name: "Person 1", gaia_given_name: "Bob" },
          },
        },
      })
    );
    const profiles = readChromiumProfiles(path);
    expect(profiles[0].name).toBe("Bob");
  });

  test("falls back to name when gaia_given_name is missing", () => {
    const dir = tempDir("chrome-fallback-name");
    const path = join(dir, "Local State");
    writeFileSync(
      path,
      JSON.stringify({
        profile: {
          info_cache: {
            "Profile 1": { name: "Work" },
          },
        },
      })
    );
    const profiles = readChromiumProfiles(path);
    expect(profiles[0].name).toBe("Work");
  });

  test("falls back to directory name when both names are missing", () => {
    const dir = tempDir("chrome-fallback-dir");
    const path = join(dir, "Local State");
    writeFileSync(
      path,
      JSON.stringify({
        profile: {
          info_cache: {
            "Profile 2": {},
          },
        },
      })
    );
    const profiles = readChromiumProfiles(path);
    expect(profiles[0].name).toBe("Profile 2");
    expect(profiles[0].directory).toBe("Profile 2");
  });

  test("parses multiple profiles", () => {
    const dir = tempDir("chrome-multi");
    const path = join(dir, "Local State");
    writeFileSync(
      path,
      JSON.stringify({
        profile: {
          info_cache: {
            Default: { name: "Person 1", gaia_given_name: "Alice" },
            "Profile 1": { name: "Work" },
            "Profile 2": { gaia_given_name: "School" },
          },
        },
      })
    );
    const profiles = readChromiumProfiles(path);
    expect(profiles).toHaveLength(3);
    const names = profiles.map((p) => p.name);
    expect(names).toContain("Alice");
    expect(names).toContain("Work");
    expect(names).toContain("School");
  });

  test("directory fields match the JSON keys", () => {
    const dir = tempDir("chrome-dirs");
    const path = join(dir, "Local State");
    writeFileSync(
      path,
      JSON.stringify({
        profile: {
          info_cache: {
            Default: { name: "Person 1" },
            "Profile 1": { name: "Work" },
          },
        },
      })
    );
    const profiles = readChromiumProfiles(path);
    const dirs = profiles.map((p) => p.directory);
    expect(dirs).toContain("Default");
    expect(dirs).toContain("Profile 1");
  });

  test("falls back to dir when gaia_given_name is empty string", () => {
    const dir = tempDir("chrome-empty-gaia");
    const path = join(dir, "Local State");
    writeFileSync(
      path,
      JSON.stringify({
        profile: {
          info_cache: {
            Default: { name: "", gaia_given_name: "" },
          },
        },
      })
    );
    const profiles = readChromiumProfiles(path);
    // Both names are empty strings (falsy), so falls through to dir
    expect(profiles[0].name).toBe("Default");
  });

  test("handles nested JSON with extra fields gracefully", () => {
    const dir = tempDir("chrome-extra-fields");
    const path = join(dir, "Local State");
    writeFileSync(
      path,
      JSON.stringify({
        profile: {
          info_cache: {
            Default: {
              name: "Person 1",
              gaia_given_name: "Alice",
              avatar_icon: "chrome://theme/IDR_AVATAR_0",
              background_apps: false,
            },
          },
          last_used: "Default",
        },
        browser: { enabled_labs_experiments: [] },
      })
    );
    const profiles = readChromiumProfiles(path);
    expect(profiles).toHaveLength(1);
    expect(profiles[0].name).toBe("Alice");
  });

  test("returns empty array for JSON array input", () => {
    const dir = tempDir("chrome-array-json");
    const path = join(dir, "Local State");
    writeFileSync(path, JSON.stringify([1, 2, 3]));
    expect(readChromiumProfiles(path)).toEqual([]);
  });

  test("returns empty array for null JSON", () => {
    const dir = tempDir("chrome-null-json");
    const path = join(dir, "Local State");
    writeFileSync(path, "null");
    expect(readChromiumProfiles(path)).toEqual([]);
  });
});

// ===========================================================================
// readFirefoxProfiles tests
// ===========================================================================

describe("readFirefoxProfiles", () => {
  test("returns empty array for nonexistent file", () => {
    expect(readFirefoxProfiles("/nonexistent/path/profiles.ini")).toEqual([]);
  });

  test("returns empty array for empty file", () => {
    const dir = tempDir("ff-empty");
    const path = join(dir, "profiles.ini");
    writeFileSync(path, "");
    expect(readFirefoxProfiles(path)).toEqual([]);
  });

  test("parses single profile", () => {
    const dir = tempDir("ff-single");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      [
        "[Profile0]",
        "Name=default-release",
        "IsRelative=1",
        "Path=Profiles/abc123.default-release",
        "",
      ].join("\n")
    );
    const profiles = readFirefoxProfiles(path);
    expect(profiles).toHaveLength(1);
    expect(profiles[0].name).toBe("default-release");
    expect(profiles[0].directory).toBe("default-release");
  });

  test("parses multiple profiles", () => {
    const dir = tempDir("ff-multi");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      [
        "[Profile0]",
        "Name=default",
        "Path=Profiles/xxx.default",
        "",
        "[Profile1]",
        "Name=Work",
        "Path=Profiles/yyy.work",
        "",
        "[Profile2]",
        "Name=Personal",
        "Path=Profiles/zzz.personal",
        "",
      ].join("\n")
    );
    const profiles = readFirefoxProfiles(path);
    expect(profiles).toHaveLength(3);
    expect(profiles.map((p) => p.name)).toEqual([
      "default",
      "Work",
      "Personal",
    ]);
  });

  test("requires both Name and Path for a profile", () => {
    const dir = tempDir("ff-incomplete");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      [
        "[Profile0]",
        "Name=has-name-only",
        // Missing Path=
        "",
        "[Profile1]",
        "Name=complete",
        "Path=Profiles/complete",
        "",
      ].join("\n")
    );
    const profiles = readFirefoxProfiles(path);
    // Only "complete" has both Name and Path
    expect(profiles).toHaveLength(1);
    expect(profiles[0].name).toBe("complete");
  });

  test("ignores non-profile sections", () => {
    const dir = tempDir("ff-other-sections");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      [
        "[General]",
        "StartWithLastProfile=1",
        "",
        "[Install123]",
        "Default=Profiles/abc.default",
        "Locked=1",
        "",
        "[Profile0]",
        "Name=default",
        "Path=Profiles/abc.default",
        "",
      ].join("\n")
    );
    const profiles = readFirefoxProfiles(path);
    expect(profiles).toHaveLength(1);
    expect(profiles[0].name).toBe("default");
  });

  test("stores name in directory field (for -P flag)", () => {
    const dir = tempDir("ff-directory");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      ["[Profile0]", "Name=MyProfile", "Path=Profiles/xxx.myprofile", ""].join(
        "\n"
      )
    );
    const profiles = readFirefoxProfiles(path);
    expect(profiles[0].directory).toBe("MyProfile");
  });

  test("handles profile without trailing newline", () => {
    const dir = tempDir("ff-no-trailing");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      "[Profile0]\nName=default\nPath=Profiles/default"
    );
    const profiles = readFirefoxProfiles(path);
    expect(profiles).toHaveLength(1);
    expect(profiles[0].name).toBe("default");
  });

  test("handles Windows-style line endings", () => {
    const dir = tempDir("ff-crlf");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      "[Profile0]\r\nName=default\r\nPath=Profiles/default\r\n"
    );
    const profiles = readFirefoxProfiles(path);
    expect(profiles).toHaveLength(1);
    // Trim handles \r
    expect(profiles[0].name).toBe("default");
  });

  test("handles profile names with spaces", () => {
    const dir = tempDir("ff-spaces");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      ["[Profile0]", "Name=My Work Profile", "Path=Profiles/work", ""].join(
        "\n"
      )
    );
    const profiles = readFirefoxProfiles(path);
    expect(profiles[0].name).toBe("My Work Profile");
  });

  test("handles Path-only section (no Name) — profile skipped", () => {
    const dir = tempDir("ff-path-only");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      [
        "[Profile0]",
        "Path=Profiles/abc",
        // No Name= line
        "",
        "[Profile1]",
        "Name=valid",
        "Path=Profiles/valid",
        "",
      ].join("\n")
    );
    const profiles = readFirefoxProfiles(path);
    expect(profiles).toHaveLength(1);
    expect(profiles[0].name).toBe("valid");
  });

  test("returns empty for file with only non-profile sections", () => {
    const dir = tempDir("ff-general-only");
    const path = join(dir, "profiles.ini");
    writeFileSync(
      path,
      ["[General]", "StartWithLastProfile=1", ""].join("\n")
    );
    expect(readFirefoxProfiles(path)).toEqual([]);
  });

  test("handles many profiles", () => {
    const dir = tempDir("ff-many");
    const path = join(dir, "profiles.ini");
    const lines: string[] = [];
    for (let i = 0; i < 20; i++) {
      lines.push(`[Profile${i}]`, `Name=Profile${i}`, `Path=Profiles/p${i}`, "");
    }
    writeFileSync(path, lines.join("\n"));
    const profiles = readFirefoxProfiles(path);
    expect(profiles).toHaveLength(20);
  });
});

// ===========================================================================
// detectInstalledBrowsers — public API tests
// ===========================================================================

describe("detectInstalledBrowsers", () => {
  let browsers: InstalledBrowser[];

  beforeAll(() => {
    browsers = detectInstalledBrowsers();
  });

  test("returns an array", () => {
    expect(Array.isArray(browsers)).toBe(true);
  });

  test("each browser has a name string", () => {
    for (const b of browsers) {
      expect(typeof b.name).toBe("string");
      expect(b.name.length).toBeGreaterThan(0);
    }
  });

  test("each browser has an appId string", () => {
    for (const b of browsers) {
      expect(typeof b.appId).toBe("string");
      expect(b.appId.length).toBeGreaterThan(0);
    }
  });

  test("each browser has a path string", () => {
    for (const b of browsers) {
      expect(typeof b.path).toBe("string");
      expect(b.path.length).toBeGreaterThan(0);
    }
  });

  test("each browser has a profiles array", () => {
    for (const b of browsers) {
      expect(Array.isArray(b.profiles)).toBe(true);
    }
  });

  test("each profile has name and directory strings", () => {
    for (const b of browsers) {
      for (const p of b.profiles) {
        expect(typeof p.name).toBe("string");
        expect(typeof p.directory).toBe("string");
      }
    }
  });

  test("on macOS, at least Safari should be detected", () => {
    if (process.platform !== "darwin") return; // skip on other platforms
    const safari = browsers.find((b) => b.appId === "com.apple.Safari");
    expect(safari).toBeTruthy();
  });

  test("on macOS, Safari has no profiles", () => {
    if (process.platform !== "darwin") return;
    const safari = browsers.find((b) => b.appId === "com.apple.Safari");
    if (safari) {
      expect(safari.profiles).toEqual([]);
    }
  });

  test("browser paths point to existing locations", () => {
    for (const b of browsers) {
      expect(existsSync(b.path)).toBe(true);
    }
  });

  test("appIds follow reverse-domain convention", () => {
    for (const b of browsers) {
      // Most appIds have dots (com.x.y) except some like "app.zen-browser.zen"
      expect(b.appId).toContain(".");
    }
  });
});

// ===========================================================================
// resolveExecutablePath
// ===========================================================================

describe("resolveExecutablePath", () => {
  test("returns null for unknown appId", () => {
    expect(resolveExecutablePath("com.nonexistent.browser")).toBeNull();
  });

  test("returns null on macOS (uses mdfind in launcher)", () => {
    if (process.platform !== "darwin") return;
    // On macOS, resolveExecutablePath always returns null
    expect(resolveExecutablePath("com.google.Chrome")).toBeNull();
  });

  test("returns null for empty string appId", () => {
    expect(resolveExecutablePath("")).toBeNull();
  });

  test("returns null for Safari on macOS", () => {
    if (process.platform !== "darwin") return;
    expect(resolveExecutablePath("com.apple.Safari")).toBeNull();
  });

  test("returns null for Firefox on macOS", () => {
    if (process.platform !== "darwin") return;
    expect(resolveExecutablePath("org.mozilla.firefox")).toBeNull();
  });
});
