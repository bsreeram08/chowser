// ---------------------------------------------------------------------------
// Platform utility tests
// ---------------------------------------------------------------------------

import { describe, test, expect } from "bun:test";
import {
  isWindows,
  isLinux,
  isMacOS,
  getPlatformConfigPath,
  getPlatformStartupPath,
  getDefaultBrowserRegistryPath,
} from "./platform.ts";

// ===========================================================================
// Platform detection tests
// ===========================================================================

describe("isWindows", () => {
  test("returns boolean", () => {
    const result = isWindows();
    expect(typeof result).toBe("boolean");
  });

  test("returns consistent value on same platform", () => {
    const first = isWindows();
    const second = isWindows();
    expect(first).toBe(second);
  });
});

describe("isLinux", () => {
  test("returns boolean", () => {
    const result = isLinux();
    expect(typeof result).toBe("boolean");
  });

  test("returns consistent value on same platform", () => {
    const first = isLinux();
    const second = isLinux();
    expect(first).toBe(second);
  });
});

describe("isMacOS", () => {
  test("returns boolean", () => {
    const result = isMacOS();
    expect(typeof result).toBe("boolean");
  });

  test("returns consistent value on same platform", () => {
    const first = isMacOS();
    const second = isMacOS();
    expect(first).toBe(second);
  });
});

describe("Platform detection mutual exclusivity", () => {
  test("exactly one platform detector returns true", () => {
    const results = [isWindows(), isLinux(), isMacOS()];
    const trueCount = results.filter(Boolean).length;
    expect(trueCount).toBe(1);
  });

  test("isWindows and isLinux are mutually exclusive", () => {
    expect(isWindows() && isLinux()).toBe(false);
  });

  test("isWindows and isMacOS are mutually exclusive", () => {
    expect(isWindows() && isMacOS()).toBe(false);
  });

  test("isLinux and isMacOS are mutually exclusive", () => {
    expect(isLinux() && isMacOS()).toBe(false);
  });
});

// ===========================================================================
// Platform config path tests
// ===========================================================================

describe("getPlatformConfigPath", () => {
  test("returns non-empty string", () => {
    const path = getPlatformConfigPath();
    expect(typeof path).toBe("string");
    expect(path.length).toBeGreaterThan(0);
  });

  test("on macOS includes Library and Application Support", () => {
    if (isMacOS()) {
      const path = getPlatformConfigPath();
      expect(path).toContain("Library");
      expect(path).toContain("Application Support");
      expect(path).toContain("in.sreerams.chowser-electrobun");
    }
  });

  test("on Windows includes appFolder", () => {
    if (isWindows()) {
      const path = getPlatformConfigPath();
      expect(path).toContain("in.sreerams.chowser-electrobun");
    }
  });

  test("on Linux includes appFolder", () => {
    if (isLinux()) {
      const path = getPlatformConfigPath();
      expect(path).toContain("in.sreerams.chowser-electrobun");
    }
  });

  test("returns consistent value on repeated calls", () => {
    const first = getPlatformConfigPath();
    const second = getPlatformConfigPath();
    expect(first).toBe(second);
  });

  test("contains platform-specific folder name", () => {
    const path = getPlatformConfigPath();
    expect(path).toContain("in.sreerams.chowser-electrobun");
  });

  test("path is absolute", () => {
    const path = getPlatformConfigPath();
    expect(path[0]).toBe("/");
  });
});

// ===========================================================================
// Platform startup path tests
// ===========================================================================

describe("getPlatformStartupPath", () => {
  test("returns non-empty string", () => {
    const path = getPlatformStartupPath();
    expect(typeof path).toBe("string");
    expect(path.length).toBeGreaterThan(0);
  });

  test("on macOS returns LaunchAgents path", () => {
    if (isMacOS()) {
      const path = getPlatformStartupPath();
      expect(path).toContain("Library");
      expect(path).toContain("LaunchAgents");
    }
  });

  test("on Windows returns registry key path", () => {
    if (isWindows()) {
      const path = getPlatformStartupPath();
      expect(path).toContain("Software");
      expect(path).toContain("CurrentVersion");
      expect(path).toContain("Run");
    }
  });

  test("on Linux returns autostart path", () => {
    if (isLinux()) {
      const path = getPlatformStartupPath();
      expect(path).toContain("config");
      expect(path).toContain("autostart");
    }
  });

  test("returns consistent value on repeated calls", () => {
    const first = getPlatformStartupPath();
    const second = getPlatformStartupPath();
    expect(first).toBe(second);
  });

  test("path contains platform-specific key", () => {
    const path = getPlatformStartupPath();
    if (isWindows()) {
      expect(path).toContain("HKEY");
    } else if (isLinux()) {
      expect(path).toContain("autostart");
    } else {
      expect(path).toContain("LaunchAgents");
    }
  });
});

// ===========================================================================
// Default browser registry path tests
// ===========================================================================

describe("getDefaultBrowserRegistryPath", () => {
  test("returns null on non-Windows platforms", () => {
    if (!isWindows()) {
      const path = getDefaultBrowserRegistryPath();
      expect(path).toBeNull();
    }
  });

  test("returns string on Windows", () => {
    if (isWindows()) {
      const path = getDefaultBrowserRegistryPath();
      expect(typeof path).toBe("string");
      expect(path).toContain("Shell");
      expect(path).toContain("UrlAssociations");
    }
  });

  test("on Windows path contains HTTP association key", () => {
    if (isWindows()) {
      const path = getDefaultBrowserRegistryPath();
      expect(path).toContain("http");
      expect(path).toContain("UserChoice");
    }
  });

  test("returns consistent value on repeated calls", () => {
    const first = getDefaultBrowserRegistryPath();
    const second = getDefaultBrowserRegistryPath();
    expect(first).toBe(second);
  });

  test("on macOS and Linux returns null", () => {
    if (isMacOS() || isLinux()) {
      const path = getDefaultBrowserRegistryPath();
      expect(path).toBeNull();
    }
  });
});

// ===========================================================================
// Cross-platform consistency tests
// ===========================================================================

describe("Cross-platform path consistency", () => {
  test("config path and startup path differ", () => {
    const configPath = getPlatformConfigPath();
    const startupPath = getPlatformStartupPath();
    expect(configPath).not.toBe(startupPath);
  });

  test("config path contains app folder", () => {
    const path = getPlatformConfigPath();
    expect(path).toContain("in.sreerams.chowser-electrobun");
  });

  test("on macOS, paths respect home directory convention", () => {
    if (isMacOS()) {
      const configPath = getPlatformConfigPath();
      const startupPath = getPlatformStartupPath();
      expect(configPath).toContain("Library");
      expect(startupPath).toContain("Library");
    }
  });

  test("registry path null consistency on non-Windows", () => {
    if (!isWindows()) {
      const path = getDefaultBrowserRegistryPath();
      expect(path).toBeNull();
    }
  });
});

// ===========================================================================
// Platform independence tests
// ===========================================================================

describe("Platform detection is platform-aware", () => {
  test("detects current platform correctly", () => {
    const isOnSomeValidPlatform =
      isWindows() || isLinux() || isMacOS();
    expect(isOnSomeValidPlatform).toBe(true);
  });

  test("platform functions work without throwing", () => {
    expect(() => {
      isWindows();
      isLinux();
      isMacOS();
      getPlatformConfigPath();
      getPlatformStartupPath();
      getDefaultBrowserRegistryPath();
    }).not.toThrow();
  });
});
