// ---------------------------------------------------------------------------
// Config & state management tests
// ---------------------------------------------------------------------------

import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import { existsSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

// We can't easily test config.ts directly because it uses a fixed CONFIG_DIR.
// Instead, test the business logic that would be invoked by RPC handlers.

import {
  type BrowserConfig,
  type BrowserRoutingRule,
  type PersistedState,
  createDefaultState,
  nextAvailableShortcut,
} from "./models.ts";

import { resolveRoute, recordDomainClick, getSuggestions } from "./routing.ts";
import { cleanUrl, isHttpUrl } from "./urlUtils.ts";
import type { DomainFrequency } from "./models.ts";

// ---------------------------------------------------------------------------
// Model / utility tests
// ---------------------------------------------------------------------------

describe("models", () => {
  test("createDefaultState returns valid state", () => {
    const state = createDefaultState();
    expect(state.version).toBe(1);
    expect(state.hasCompletedOnboarding).toBe(false);
    expect(state.configuredBrowsers.length).toBeGreaterThanOrEqual(1);
    expect(state.routingRules).toEqual([]);
    expect(state.hiddenAppIds.length).toBeGreaterThan(0);
    expect(state.pickerLayout).toBe("icons");
    expect(state.launchAtLogin).toBe(false);
    expect(state.focusMode).toBeNull();
  });

  test("nextAvailableShortcut returns first unused key", () => {
    const browsers: BrowserConfig[] = [
      { id: "1", name: "A", appId: "a", shortcutKey: "1" },
      { id: "2", name: "B", appId: "b", shortcutKey: "2" },
    ];
    expect(nextAvailableShortcut(browsers)).toBe("3");
  });

  test("nextAvailableShortcut returns 9 when all used", () => {
    const browsers: BrowserConfig[] = Array.from({ length: 9 }, (_, i) => ({
      id: String(i),
      name: `B${i}`,
      appId: `b${i}`,
      shortcutKey: String(i + 1),
    }));
    expect(nextAvailableShortcut(browsers)).toBe("9");
  });
});

// ---------------------------------------------------------------------------
// URL utility tests
// ---------------------------------------------------------------------------

describe("urlUtils", () => {
  test("cleanUrl strips UTM params", () => {
    const dirty = "https://example.com/page?utm_source=twitter&utm_medium=social&q=hello";
    const clean = cleanUrl(dirty);
    expect(clean).toContain("q=hello");
    expect(clean).not.toContain("utm_source");
    expect(clean).not.toContain("utm_medium");
  });

  test("cleanUrl leaves URLs without tracking params unchanged", () => {
    const url = "https://example.com/page?q=hello&page=2";
    expect(cleanUrl(url)).toBe(url);
  });

  test("cleanUrl strips fbclid", () => {
    const url = "https://example.com/?fbclid=abc123";
    const clean = cleanUrl(url);
    expect(clean).not.toContain("fbclid");
    expect(clean).toBe("https://example.com/");
  });

  test("cleanUrl handles malformed URLs gracefully", () => {
    expect(cleanUrl("not a url")).toBe("not a url");
  });

  test("isHttpUrl returns true for http URLs", () => {
    expect(isHttpUrl("http://example.com")).toBe(true);
    expect(isHttpUrl("https://example.com")).toBe(true);
  });

  test("isHttpUrl returns false for non-http URLs", () => {
    expect(isHttpUrl("ftp://example.com")).toBe(false);
    expect(isHttpUrl("not a url")).toBe(false);
    expect(isHttpUrl("")).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Routing tests
// ---------------------------------------------------------------------------

describe("resolveRoute", () => {
  const baseRule: BrowserRoutingRule = {
    id: "rule-1",
    name: "GitHub in Chrome",
    hostPattern: "github.com",
    browserAppId: "com.google.Chrome",
    isEnabled: true,
    usePrivateMode: false,
    useRegex: false,
  };

  test("matches exact host", () => {
    const result = resolveRoute("https://github.com/repo", [baseRule]);
    expect(result).not.toBeNull();
    expect(result!.browserAppId).toBe("com.google.Chrome");
    expect(result!.matchedRuleId).toBe("rule-1");
  });

  test("does not match different host", () => {
    const result = resolveRoute("https://gitlab.com/repo", [baseRule]);
    expect(result).toBeNull();
  });

  test("matches wildcard host pattern", () => {
    const rule = { ...baseRule, hostPattern: "*.github.com" };
    const result = resolveRoute("https://docs.github.com/page", [rule]);
    expect(result).not.toBeNull();
  });

  test("wildcard does not match base domain", () => {
    const rule = { ...baseRule, hostPattern: "*.github.com" };
    const result = resolveRoute("https://github.com/page", [rule]);
    // *.github.com should not match github.com (the * matches a non-empty subdomain)
    expect(result).toBeNull();
  });

  test("** wildcard matches nested subdomains", () => {
    const rule = { ...baseRule, hostPattern: "**.google.com" };
    const result = resolveRoute("https://mail.google.com/inbox", [rule]);
    expect(result).not.toBeNull();
  });

  test("matches path prefix case-insensitively", () => {
    const rule = { ...baseRule, pathPrefix: "/Work" };
    const result = resolveRoute("https://github.com/work/repo", [rule]);
    expect(result).not.toBeNull();
  });

  test("does not match wrong path prefix", () => {
    const rule = { ...baseRule, pathPrefix: "/work" };
    const result = resolveRoute("https://github.com/personal/repo", [rule]);
    expect(result).toBeNull();
  });

  test("matches source app when provided", () => {
    const rule = { ...baseRule, sourceAppBundleId: "com.tinyspeck.slackmacgap" };
    const result = resolveRoute(
      "https://github.com/repo",
      [rule],
      "com.tinyspeck.slackmacgap"
    );
    expect(result).not.toBeNull();
  });

  test("does not match wrong source app", () => {
    const rule = { ...baseRule, sourceAppBundleId: "com.tinyspeck.slackmacgap" };
    const result = resolveRoute(
      "https://github.com/repo",
      [rule],
      "com.apple.mail"
    );
    expect(result).toBeNull();
  });

  test("source app rule matches without source app if no constraint", () => {
    const result = resolveRoute("https://github.com/repo", [baseRule]);
    expect(result).not.toBeNull();
  });

  test("skips disabled rules", () => {
    const rule = { ...baseRule, isEnabled: false };
    const result = resolveRoute("https://github.com/repo", [rule]);
    expect(result).toBeNull();
  });

  test("returns first matching rule (priority order)", () => {
    const rules: BrowserRoutingRule[] = [
      { ...baseRule, id: "rule-a", name: "First", browserAppId: "com.brave.Browser" },
      { ...baseRule, id: "rule-b", name: "Second", browserAppId: "com.google.Chrome" },
    ];
    const result = resolveRoute("https://github.com/repo", rules);
    expect(result).not.toBeNull();
    expect(result!.browserAppId).toBe("com.brave.Browser");
    expect(result!.matchedRuleId).toBe("rule-a");
  });

  test("regex host matching requires full match", () => {
    const rule = { ...baseRule, useRegex: true, hostPattern: "github\\.com" };
    const result = resolveRoute("https://github.com.evil.com/", [rule]);
    expect(result).toBeNull();
  });

  test("regex host matching works for valid regex", () => {
    const rule = { ...baseRule, useRegex: true, hostPattern: "github\\.com" };
    const result = resolveRoute("https://github.com/repo", [rule]);
    expect(result).not.toBeNull();
  });

  test("regex with alternation", () => {
    const rule = {
      ...baseRule,
      useRegex: true,
      hostPattern: "(github|gitlab)\\.com",
    };
    expect(resolveRoute("https://github.com/", [rule])).not.toBeNull();
    expect(resolveRoute("https://gitlab.com/", [rule])).not.toBeNull();
    expect(resolveRoute("https://bitbucket.org/", [rule])).toBeNull();
  });

  test("returns private mode and profile from rule", () => {
    const rule = {
      ...baseRule,
      usePrivateMode: true,
      profile: "Work",
    };
    const result = resolveRoute("https://github.com/", [rule]);
    expect(result).not.toBeNull();
    expect(result!.usePrivateMode).toBe(true);
    expect(result!.profile).toBe("Work");
  });

  test("handles invalid URL gracefully", () => {
    const result = resolveRoute("not-a-url", [baseRule]);
    expect(result).toBeNull();
  });

  test("handles empty rules array", () => {
    const result = resolveRoute("https://github.com/", []);
    expect(result).toBeNull();
  });

  test("star pattern matches everything", () => {
    const rule = { ...baseRule, hostPattern: "*" };
    const result = resolveRoute("https://anything.example.com/", [rule]);
    expect(result).not.toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Domain frequency tests
// ---------------------------------------------------------------------------

describe("domainFrequency", () => {
  test("recordDomainClick increments count", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "github.com", "com.google.Chrome");
    freq = recordDomainClick(freq, "github.com", "com.google.Chrome");
    freq = recordDomainClick(freq, "github.com", "com.google.Chrome");
    expect(freq["github.com"]!["com.google.Chrome"]).toBe(3);
  });

  test("recordDomainClick tracks multiple browsers per domain", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "github.com", "com.google.Chrome");
    freq = recordDomainClick(freq, "github.com", "com.apple.Safari");
    expect(freq["github.com"]!["com.google.Chrome"]).toBe(1);
    expect(freq["github.com"]!["com.apple.Safari"]).toBe(1);
  });

  test("getSuggestions returns domains exceeding threshold", () => {
    let freq: DomainFrequency = {};
    for (let i = 0; i < 30; i++) {
      freq = recordDomainClick(freq, "github.com", "com.google.Chrome");
    }
    const suggestions = getSuggestions(freq, 30);
    expect(suggestions.length).toBe(1);
    expect(suggestions[0]!.domain).toBe("github.com");
    expect(suggestions[0]!.appId).toBe("com.google.Chrome");
    expect(suggestions[0]!.count).toBe(30);
  });

  test("getSuggestions returns empty for low counts", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "github.com", "com.google.Chrome");
    const suggestions = getSuggestions(freq, 30);
    expect(suggestions.length).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Business logic simulation tests (mimic RPC handler behavior)
// ---------------------------------------------------------------------------

describe("settings handler logic", () => {
  let state: PersistedState;

  beforeEach(() => {
    state = createDefaultState();
  });

  test("addBrowser adds to list", () => {
    const browser: BrowserConfig = {
      id: "new-1",
      name: "Chrome",
      appId: "com.google.Chrome",
      shortcutKey: "2",
    };
    if (!state.configuredBrowsers.some((b) => b.id === browser.id)) {
      state.configuredBrowsers = [...state.configuredBrowsers, browser];
    }
    expect(state.configuredBrowsers.length).toBe(2); // default Safari + Chrome
    expect(state.configuredBrowsers[1]!.name).toBe("Chrome");
  });

  test("addBrowser prevents duplicates by id", () => {
    const existing = state.configuredBrowsers[0]!;
    if (!state.configuredBrowsers.some((b) => b.id === existing.id)) {
      state.configuredBrowsers = [...state.configuredBrowsers, existing];
    }
    expect(state.configuredBrowsers.length).toBe(1);
  });

  test("removeBrowser removes by id", () => {
    const idToRemove = state.configuredBrowsers[0]!.id;
    state.configuredBrowsers = state.configuredBrowsers.filter(
      (b) => b.id !== idToRemove
    );
    expect(state.configuredBrowsers.length).toBe(0);
  });

  test("updateBrowser replaces matching entry", () => {
    const updated = {
      ...state.configuredBrowsers[0]!,
      name: "Safari Dev",
    };
    state.configuredBrowsers = state.configuredBrowsers.map((b) =>
      b.id === updated.id ? updated : b
    );
    expect(state.configuredBrowsers[0]!.name).toBe("Safari Dev");
  });

  test("reorderBrowsers respects new id order", () => {
    const b1: BrowserConfig = { id: "b1", name: "A", appId: "a", shortcutKey: "1" };
    const b2: BrowserConfig = { id: "b2", name: "B", appId: "b", shortcutKey: "2" };
    const b3: BrowserConfig = { id: "b3", name: "C", appId: "c", shortcutKey: "3" };
    state.configuredBrowsers = [b1, b2, b3];

    const newOrder = ["b3", "b1", "b2"];
    const browserMap = new Map(state.configuredBrowsers.map((b) => [b.id, b]));
    const ordered = newOrder
      .map((id) => browserMap.get(id))
      .filter((b): b is BrowserConfig => b !== undefined);
    state.configuredBrowsers = ordered;

    expect(state.configuredBrowsers.map((b) => b.id)).toEqual(["b3", "b1", "b2"]);
  });

  test("addRule appends rule", () => {
    const rule: BrowserRoutingRule = {
      id: "r1",
      name: "Test",
      hostPattern: "example.com",
      browserAppId: "com.google.Chrome",
      isEnabled: true,
      usePrivateMode: false,
      useRegex: false,
    };
    state.routingRules = [...state.routingRules, rule];
    expect(state.routingRules.length).toBe(1);
    expect(state.routingRules[0]!.id).toBe("r1");
  });

  test("removeRule removes by id", () => {
    state.routingRules = [
      {
        id: "r1",
        name: "Test",
        hostPattern: "example.com",
        browserAppId: "com.google.Chrome",
        isEnabled: true,
        usePrivateMode: false,
        useRegex: false,
      },
    ];
    state.routingRules = state.routingRules.filter((r) => r.id !== "r1");
    expect(state.routingRules.length).toBe(0);
  });

  test("duplicateRule creates copy at next position", () => {
    const original: BrowserRoutingRule = {
      id: "r1",
      name: "Test",
      hostPattern: "example.com",
      browserAppId: "com.google.Chrome",
      isEnabled: true,
      usePrivateMode: false,
      useRegex: false,
    };
    state.routingRules = [original];

    const rule = state.routingRules.find((r) => r.id === "r1")!;
    const idx = state.routingRules.indexOf(rule);
    const copy = { ...rule, id: "r1-copy", name: `${rule.name} (copy)` };
    const newRules = [...state.routingRules];
    newRules.splice(idx + 1, 0, copy);
    state.routingRules = newRules;

    expect(state.routingRules.length).toBe(2);
    expect(state.routingRules[0]!.id).toBe("r1");
    expect(state.routingRules[1]!.id).toBe("r1-copy");
    expect(state.routingRules[1]!.name).toBe("Test (copy)");
  });

  test("toggleRule enables/disables", () => {
    state.routingRules = [
      {
        id: "r1",
        name: "Test",
        hostPattern: "example.com",
        browserAppId: "com.google.Chrome",
        isEnabled: true,
        usePrivateMode: false,
        useRegex: false,
      },
    ];
    state.routingRules = state.routingRules.map((r) =>
      r.id === "r1" ? { ...r, isEnabled: false } : r
    );
    expect(state.routingRules[0]!.isEnabled).toBe(false);
  });

  test("reorderRules respects new id order", () => {
    const r1: BrowserRoutingRule = {
      id: "r1", name: "A", hostPattern: "a.com", browserAppId: "a",
      isEnabled: true, usePrivateMode: false, useRegex: false,
    };
    const r2: BrowserRoutingRule = {
      id: "r2", name: "B", hostPattern: "b.com", browserAppId: "b",
      isEnabled: true, usePrivateMode: false, useRegex: false,
    };
    state.routingRules = [r1, r2];

    const newOrder = ["r2", "r1"];
    const ruleMap = new Map(state.routingRules.map((r) => [r.id, r]));
    const reordered = newOrder
      .map((id) => ruleMap.get(id))
      .filter((r): r is BrowserRoutingRule => r !== undefined);
    state.routingRules = reordered;

    expect(state.routingRules.map((r) => r.id)).toEqual(["r2", "r1"]);
  });

  test("setHiddenApps replaces hidden app list", () => {
    state.hiddenAppIds = ["com.example.app"];
    expect(state.hiddenAppIds).toEqual(["com.example.app"]);
  });

  test("resetToDefaults restores default state", () => {
    state.configuredBrowsers = [];
    state.routingRules = [];
    state.hiddenAppIds = [];

    // Simulate resetToDefaults handler
    const defaults = createDefaultState();
    state.configuredBrowsers = defaults.configuredBrowsers;
    state.routingRules = defaults.routingRules;
    state.hiddenAppIds = defaults.hiddenAppIds;

    expect(state.configuredBrowsers.length).toBeGreaterThanOrEqual(1);
    expect(state.routingRules.length).toBe(0);
    expect(state.hiddenAppIds.length).toBeGreaterThan(0);
  });

  test("importConfig merges without duplicates", () => {
    state.configuredBrowsers = [
      { id: "b1", name: "Safari", appId: "com.apple.Safari", shortcutKey: "1" },
    ];
    state.routingRules = [];

    const imported = {
      browsers: [
        { id: "b2", name: "Chrome", appId: "com.google.Chrome", shortcutKey: "2" },
        // Duplicate appId should be merged
        { id: "b3", name: "Safari 2", appId: "com.apple.Safari", shortcutKey: "3" },
      ],
      rules: [
        {
          id: "r1", name: "Test", hostPattern: "example.com",
          browserAppId: "com.google.Chrome", isEnabled: true,
          usePrivateMode: false, useRegex: false,
        },
      ],
    };

    // Simulate importConfig handler
    const existing = new Set(
      state.configuredBrowsers.map((b) => `${b.appId}|${b.profile ?? ""}`)
    );
    const newBrowsers = imported.browsers.filter(
      (b) => !existing.has(`${b.appId}|${(b as BrowserConfig).profile ?? ""}`)
    );
    state.configuredBrowsers = [...state.configuredBrowsers, ...newBrowsers];

    const existingRuleIds = new Set(state.routingRules.map((r) => r.id));
    const newRules = (imported.rules as BrowserRoutingRule[]).filter(
      (r) => !existingRuleIds.has(r.id)
    );
    state.routingRules = [...state.routingRules, ...newRules];

    // Safari was a duplicate (same appId), so only Chrome should be added
    expect(state.configuredBrowsers.length).toBe(2);
    expect(state.configuredBrowsers[1]!.appId).toBe("com.google.Chrome");
    expect(state.routingRules.length).toBe(1);
  });

  test("exportConfig produces valid JSON", () => {
    const json = JSON.stringify(
      { browsers: state.configuredBrowsers, rules: state.routingRules },
      null,
      2
    );
    const parsed = JSON.parse(json);
    expect(parsed.browsers).toEqual(state.configuredBrowsers);
    expect(parsed.rules).toEqual(state.routingRules);
  });

  test("testUrl returns match info for matching URL", () => {
    const rule: BrowserRoutingRule = {
      id: "r1",
      name: "GitHub in Chrome",
      hostPattern: "github.com",
      browserAppId: "com.google.Chrome",
      isEnabled: true,
      usePrivateMode: false,
      useRegex: false,
    };
    state.routingRules = [rule];
    state.configuredBrowsers = [
      { id: "b1", name: "Chrome", appId: "com.google.Chrome", shortcutKey: "1" },
    ];

    const route = resolveRoute("https://github.com/repo", state.routingRules);
    expect(route).not.toBeNull();

    const matchedRule = state.routingRules.find((r) => r.id === route!.matchedRuleId);
    const browser = state.configuredBrowsers.find((b) => b.appId === route!.browserAppId);

    expect(matchedRule?.name).toBe("GitHub in Chrome");
    expect(browser?.name).toBe("Chrome");
  });

  test("testUrl returns null for non-matching URL", () => {
    state.routingRules = [
      {
        id: "r1",
        name: "GitHub in Chrome",
        hostPattern: "github.com",
        browserAppId: "com.google.Chrome",
        isEnabled: true,
        usePrivateMode: false,
        useRegex: false,
      },
    ];
    const route = resolveRoute("https://example.com/", state.routingRules);
    expect(route).toBeNull();
  });

  test("focus mode can be set and cleared", () => {
    state.focusMode = {
      browserId: "b1",
      expiresAt: Date.now() + 60 * 60 * 1000,
    };
    expect(state.focusMode).not.toBeNull();
    expect(state.focusMode!.browserId).toBe("b1");

    state.focusMode = null;
    expect(state.focusMode).toBeNull();
  });

  test("picker layout can be toggled", () => {
    expect(state.pickerLayout).toBe("icons");
    state.pickerLayout = "list";
    expect(state.pickerLayout).toBe("list");
    state.pickerLayout = "icons";
    expect(state.pickerLayout).toBe("icons");
  });

  test("recent URLs are capped and deduplicated", () => {
    const entries = Array.from({ length: 150 }, (_, i) => ({
      url: `https://example.com/page/${i}`,
      browserId: "b1",
      timestamp: Date.now() + i,
    }));

    // Simulate recordRecentUrl logic
    for (const entry of entries) {
      const existing = state.recentUrls.filter((r) => r.url !== entry.url);
      state.recentUrls = [entry, ...existing].slice(0, 100);
    }

    expect(state.recentUrls.length).toBe(100);
    // Most recent should be last entry added
    expect(state.recentUrls[0]!.url).toBe("https://example.com/page/149");
  });
});
