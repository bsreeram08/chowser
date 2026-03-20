import { describe, expect, test } from "bun:test";
import {
  createDefaultState,
  nextAvailableShortcut,
  normalizeShortcut,
  SUPPORTED_SHORTCUTS,
  DEFAULT_HIDDEN_APP_IDS,
  DOMAIN_SUGGESTION_THRESHOLD,
  DOMAIN_MAX_ENTRIES,
  RECENT_URLS_MAX,
  APP_VERSION,
} from "./models.ts";
import type {
  BrowserConfig,
  BrowserRoutingRule,
  PersistedState,
  DomainFrequency,
  RecentUrl,
  FocusMode,
  PickerLayout,
  InstalledBrowser,
  BrowserProfile,
  ResolvedRoute,
  DomainSuggestion,
} from "./models.ts";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

describe("constants", () => {
  test("APP_VERSION equals 1", () => {
    expect(APP_VERSION).toBe(1);
  });

  test("DOMAIN_SUGGESTION_THRESHOLD equals 30", () => {
    expect(DOMAIN_SUGGESTION_THRESHOLD).toBe(30);
  });

  test("DOMAIN_MAX_ENTRIES equals 100", () => {
    expect(DOMAIN_MAX_ENTRIES).toBe(100);
  });

  test("RECENT_URLS_MAX equals 100", () => {
    expect(RECENT_URLS_MAX).toBe(100);
  });

  test("SUPPORTED_SHORTCUTS has exactly 9 entries", () => {
    expect(SUPPORTED_SHORTCUTS).toHaveLength(9);
  });

  test("SUPPORTED_SHORTCUTS contains '1' through '9'", () => {
    for (let i = 1; i <= 9; i++) {
      expect((SUPPORTED_SHORTCUTS as readonly string[]).includes(String(i))).toBe(true);
    }
  });

  test("DEFAULT_HIDDEN_APP_IDS is non-empty", () => {
    expect(DEFAULT_HIDDEN_APP_IDS.length).toBeGreaterThan(0);
  });

  test("DEFAULT_HIDDEN_APP_IDS contains com.colliderli.iina", () => {
    expect(DEFAULT_HIDDEN_APP_IDS).toContain("com.colliderli.iina");
  });

  test("DEFAULT_HIDDEN_APP_IDS contains org.videolan.vlc", () => {
    expect(DEFAULT_HIDDEN_APP_IDS).toContain("org.videolan.vlc");
  });

  test("DEFAULT_HIDDEN_APP_IDS contains io.mpv", () => {
    expect(DEFAULT_HIDDEN_APP_IDS).toContain("io.mpv");
  });
});

// ---------------------------------------------------------------------------
// createDefaultState
// ---------------------------------------------------------------------------

describe("createDefaultState", () => {
  test("returns an object with version equal to APP_VERSION", () => {
    const state = createDefaultState();
    expect(state.version).toBe(APP_VERSION);
  });

  test("hasCompletedOnboarding is false", () => {
    expect(createDefaultState().hasCompletedOnboarding).toBe(false);
  });

  test("has at least 1 configured browser", () => {
    expect(createDefaultState().configuredBrowsers.length).toBeGreaterThanOrEqual(1);
  });

  test("routingRules is empty", () => {
    expect(createDefaultState().routingRules).toEqual([]);
  });

  test("hiddenAppIds is non-empty", () => {
    expect(createDefaultState().hiddenAppIds.length).toBeGreaterThan(0);
  });

  test("hiddenAppIds length matches DEFAULT_HIDDEN_APP_IDS", () => {
    expect(createDefaultState().hiddenAppIds).toHaveLength(DEFAULT_HIDDEN_APP_IDS.length);
  });

  test("pickerLayout is 'icons'", () => {
    expect(createDefaultState().pickerLayout).toBe("icons");
  });

  test("launchAtLogin is false", () => {
    expect(createDefaultState().launchAtLogin).toBe(false);
  });

  test("focusMode is null", () => {
    expect(createDefaultState().focusMode).toBeNull();
  });

  test("recentUrls is empty", () => {
    expect(createDefaultState().recentUrls).toEqual([]);
  });

  test("domainFrequency is empty object", () => {
    expect(createDefaultState().domainFrequency).toEqual({});
  });

  test("on darwin, default browser is Safari", () => {
    // process.platform is 'darwin' on macOS (our CI/dev environment)
    if (process.platform === "darwin") {
      const state = createDefaultState();
      expect(state.configuredBrowsers[0]!.name).toBe("Safari");
      expect(state.configuredBrowsers[0]!.appId).toBe("com.apple.Safari");
    } else {
      expect(true).toBe(true); // pass on other platforms
    }
  });

  test("default browsers have valid shortcutKeys from SUPPORTED_SHORTCUTS", () => {
    const state = createDefaultState();
    for (const browser of state.configuredBrowsers) {
      expect(SUPPORTED_SHORTCUTS as readonly string[]).toContain(browser.shortcutKey);
    }
  });

  test("default browsers have non-empty ids", () => {
    const state = createDefaultState();
    for (const browser of state.configuredBrowsers) {
      expect(browser.id.length).toBeGreaterThan(0);
    }
  });

  test("each call returns a fresh object", () => {
    const a = createDefaultState();
    const b = createDefaultState();
    expect(a).not.toBe(b);
    expect(a.configuredBrowsers).not.toBe(b.configuredBrowsers);
  });

  test("all required PersistedState fields are present", () => {
    const state = createDefaultState();
    expect(state).toHaveProperty("version");
    expect(state).toHaveProperty("hasCompletedOnboarding");
    expect(state).toHaveProperty("configuredBrowsers");
    expect(state).toHaveProperty("routingRules");
    expect(state).toHaveProperty("hiddenAppIds");
    expect(state).toHaveProperty("domainFrequency");
    expect(state).toHaveProperty("recentUrls");
    expect(state).toHaveProperty("pickerLayout");
    expect(state).toHaveProperty("launchAtLogin");
    expect(state).toHaveProperty("focusMode");
  });
});

// ---------------------------------------------------------------------------
// nextAvailableShortcut
// ---------------------------------------------------------------------------

describe("nextAvailableShortcut", () => {
  test("returns '1' when no browsers exist", () => {
    expect(nextAvailableShortcut([])).toBe("1");
  });

  test("returns '3' when '1' and '2' are used", () => {
    const browsers: BrowserConfig[] = [
      { id: "a", name: "A", appId: "a", shortcutKey: "1" },
      { id: "b", name: "B", appId: "b", shortcutKey: "2" },
    ];
    expect(nextAvailableShortcut(browsers)).toBe("3");
  });

  test("returns '2' when '1' and '3' are used (fills gap)", () => {
    const browsers: BrowserConfig[] = [
      { id: "a", name: "A", appId: "a", shortcutKey: "1" },
      { id: "b", name: "B", appId: "b", shortcutKey: "3" },
    ];
    expect(nextAvailableShortcut(browsers)).toBe("2");
  });

  test("returns '9' when all 1-9 are used", () => {
    const browsers: BrowserConfig[] = SUPPORTED_SHORTCUTS.map((k, i) => ({
      id: `b${i}`,
      name: `Browser ${i}`,
      appId: `app.${i}`,
      shortcutKey: k,
    }));
    expect(nextAvailableShortcut(browsers)).toBe("9");
  });

  test("returns '1' when browsers have non-standard shortcutKeys", () => {
    const browsers: BrowserConfig[] = [
      { id: "a", name: "A", appId: "a", shortcutKey: "z" },
    ];
    expect(nextAvailableShortcut(browsers)).toBe("1");
  });
});

// ---------------------------------------------------------------------------
// normalizeShortcut
// ---------------------------------------------------------------------------

describe("normalizeShortcut", () => {
  test("returns '1' for input '1'", () => {
    expect(normalizeShortcut("1")).toBe("1");
  });

  test("returns '5' for input '5'", () => {
    expect(normalizeShortcut("5")).toBe("5");
  });

  test("returns '9' for input '9'", () => {
    expect(normalizeShortcut("9")).toBe("9");
  });

  test("returns null for '0'", () => {
    expect(normalizeShortcut("0")).toBeNull();
  });

  test("returns null for 'a'", () => {
    expect(normalizeShortcut("a")).toBeNull();
  });

  test("returns null for empty string", () => {
    expect(normalizeShortcut("")).toBeNull();
  });

  test("returns null for '10'", () => {
    expect(normalizeShortcut("10")).toBeNull();
  });

  test("trims whitespace and normalizes ' 3 ' to '3'", () => {
    expect(normalizeShortcut(" 3 ")).toBe("3");
  });

  test("returns null for special characters", () => {
    expect(normalizeShortcut("@")).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Interface shape tests (compile-time + runtime structure)
// ---------------------------------------------------------------------------

describe("interface shape tests", () => {
  test("BrowserConfig can be constructed with required fields", () => {
    const config: BrowserConfig = {
      id: "test-id",
      name: "Test Browser",
      appId: "com.test.browser",
      shortcutKey: "1",
    };
    expect(config.id).toBe("test-id");
    expect(config.name).toBe("Test Browser");
    expect(config.appId).toBe("com.test.browser");
    expect(config.shortcutKey).toBe("1");
  });

  test("BrowserConfig supports optional profile and customArguments", () => {
    const config: BrowserConfig = {
      id: "test-id",
      name: "Chrome",
      appId: "com.google.Chrome",
      shortcutKey: "2",
      profile: "Profile 1",
      customArguments: "--incognito",
    };
    expect(config.profile).toBe("Profile 1");
    expect(config.customArguments).toBe("--incognito");
  });

  test("BrowserRoutingRule can be constructed with all fields", () => {
    const rule: BrowserRoutingRule = {
      id: "rule-1",
      name: "GitHub rule",
      hostPattern: "*.github.com",
      pathPrefix: "/repos",
      browserAppId: "com.google.Chrome",
      profile: "Work",
      sourceAppBundleId: "com.tinyspeck.slackmacgap",
      isEnabled: true,
      usePrivateMode: false,
      useRegex: false,
    };
    expect(rule.id).toBe("rule-1");
    expect(rule.hostPattern).toBe("*.github.com");
    expect(rule.isEnabled).toBe(true);
    expect(rule.useRegex).toBe(false);
  });

  test("PersistedState shape matches createDefaultState output", () => {
    const state: PersistedState = createDefaultState();
    expect(typeof state.version).toBe("number");
    expect(typeof state.hasCompletedOnboarding).toBe("boolean");
    expect(Array.isArray(state.configuredBrowsers)).toBe(true);
    expect(Array.isArray(state.routingRules)).toBe(true);
    expect(Array.isArray(state.hiddenAppIds)).toBe(true);
    expect(typeof state.domainFrequency).toBe("object");
    expect(Array.isArray(state.recentUrls)).toBe(true);
    expect(typeof state.pickerLayout).toBe("string");
    expect(typeof state.launchAtLogin).toBe("boolean");
  });

  test("FocusMode can be constructed with expiresAt", () => {
    const mode: FocusMode = { browserId: "b1", expiresAt: Date.now() + 60000 };
    expect(mode.browserId).toBe("b1");
    expect(typeof mode.expiresAt).toBe("number");
  });

  test("FocusMode can be constructed with null expiresAt", () => {
    const mode: FocusMode = { browserId: "b1", expiresAt: null };
    expect(mode.expiresAt).toBeNull();
  });

  test("DomainFrequency stores nested domain → appId → count", () => {
    const freq: DomainFrequency = {
      "github.com": { "com.google.Chrome": 5, "com.apple.Safari": 2 },
    };
    expect(freq["github.com"]!["com.google.Chrome"]).toBe(5);
  });

  test("RecentUrl can be constructed", () => {
    const recent: RecentUrl = {
      url: "https://example.com",
      browserId: "com.apple.Safari",
      timestamp: Date.now(),
    };
    expect(recent.url).toBe("https://example.com");
    expect(recent.browserId).toBe("com.apple.Safari");
  });

  test("RecentUrl browserId can be null", () => {
    const recent: RecentUrl = {
      url: "https://example.com",
      browserId: null,
      timestamp: Date.now(),
    };
    expect(recent.browserId).toBeNull();
  });

  test("InstalledBrowser has required fields", () => {
    const browser: InstalledBrowser = {
      name: "Chrome",
      appId: "com.google.Chrome",
      path: "/Applications/Google Chrome.app",
      profiles: [],
    };
    expect(browser.profiles).toEqual([]);
  });

  test("BrowserProfile has name and directory", () => {
    const profile: BrowserProfile = { name: "Default", directory: "Default" };
    expect(profile.name).toBe("Default");
    expect(profile.directory).toBe("Default");
  });

  test("ResolvedRoute can be constructed", () => {
    const route: ResolvedRoute = {
      browserAppId: "com.apple.Safari",
      usePrivateMode: false,
      matchedRuleId: "r1",
    };
    expect(route.browserAppId).toBe("com.apple.Safari");
    expect(route.profile).toBeUndefined();
  });

  test("DomainSuggestion has domain, appId, count", () => {
    const suggestion: DomainSuggestion = {
      domain: "github.com",
      appId: "com.google.Chrome",
      count: 35,
    };
    expect(suggestion.count).toBe(35);
  });

  test("PickerLayout is either 'icons' or 'list'", () => {
    const layout1: PickerLayout = "icons";
    const layout2: PickerLayout = "list";
    expect(layout1).toBe("icons");
    expect(layout2).toBe("list");
  });
});
