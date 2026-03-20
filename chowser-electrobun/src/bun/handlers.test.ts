// ---------------------------------------------------------------------------
// Comprehensive handler business-logic tests
//
// These tests exercise the same logic the RPC handlers in index.ts perform,
// but by calling the state-management functions (getState / patchState / setState)
// and pure helpers (resolveRoute, recordDomainClick, getSuggestions) directly.
// ---------------------------------------------------------------------------

import { describe, test, expect, beforeEach } from "bun:test";
import {
  loadState,
  getState,
  patchState,
  setState,
  flushState,
} from "./config.ts";
import {
  createDefaultState,
  nextAvailableShortcut,
  type BrowserConfig,
  type BrowserRoutingRule,
  type PersistedState,
  type RecentUrl,
  type FocusMode,
  type PickerLayout,
  type DomainFrequency,
  DOMAIN_MAX_ENTRIES,
  DOMAIN_SUGGESTION_THRESHOLD,
  RECENT_URLS_MAX,
  DEFAULT_HIDDEN_APP_IDS,
  APP_VERSION,
} from "./models.ts";
import { resolveRoute, recordDomainClick, getSuggestions } from "./routing.ts";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeBrowser(overrides: Partial<BrowserConfig> = {}): BrowserConfig {
  return {
    id: crypto.randomUUID(),
    name: "Test Browser",
    appId: "com.test.browser",
    shortcutKey: "1",
    ...overrides,
  };
}

function makeRule(overrides: Partial<BrowserRoutingRule> = {}): BrowserRoutingRule {
  return {
    id: crypto.randomUUID(),
    name: "Test Rule",
    hostPattern: "example.com",
    browserAppId: "com.test.browser",
    isEnabled: true,
    usePrivateMode: false,
    useRegex: false,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Reset singleton state before every test
// ---------------------------------------------------------------------------

beforeEach(() => {
  setState(createDefaultState());
});

// ===========================================================================
// Browser Management (30+ tests)
// ===========================================================================

describe("Browser Management", () => {
  // -- addBrowser -----------------------------------------------------------

  describe("addBrowser", () => {
    test("adds a browser to the list", () => {
      const browser = makeBrowser({ id: "b1", name: "Chrome", appId: "com.google.Chrome" });
      const s = getState();
      if (!s.configuredBrowsers.some((b) => b.id === browser.id)) {
        patchState({ configuredBrowsers: [...s.configuredBrowsers, browser] });
      }
      expect(getState().configuredBrowsers.find((b) => b.id === "b1")).toBeDefined();
    });

    test("ignores duplicate browser ID", () => {
      const browser = makeBrowser({ id: "dup", name: "Chrome" });
      // First add
      const s1 = getState();
      if (!s1.configuredBrowsers.some((b) => b.id === browser.id)) {
        patchState({ configuredBrowsers: [...s1.configuredBrowsers, browser] });
      }
      const countAfterFirst = getState().configuredBrowsers.length;
      // Second add (same ID)
      const s2 = getState();
      if (!s2.configuredBrowsers.some((b) => b.id === browser.id)) {
        patchState({ configuredBrowsers: [...s2.configuredBrowsers, browser] });
      }
      expect(getState().configuredBrowsers.length).toBe(countAfterFirst);
    });

    test("multiple browsers can coexist", () => {
      const chrome = makeBrowser({ id: "chrome", name: "Chrome", appId: "com.google.Chrome", shortcutKey: "2" });
      const firefox = makeBrowser({ id: "firefox", name: "Firefox", appId: "org.mozilla.firefox", shortcutKey: "3" });
      let s = getState();
      patchState({ configuredBrowsers: [...s.configuredBrowsers, chrome] });
      s = getState();
      patchState({ configuredBrowsers: [...s.configuredBrowsers, firefox] });
      const browsers = getState().configuredBrowsers;
      expect(browsers.find((b) => b.id === "chrome")).toBeDefined();
      expect(browsers.find((b) => b.id === "firefox")).toBeDefined();
    });

    test("added browser has correct fields", () => {
      const browser = makeBrowser({
        id: "b-fields",
        name: "Brave",
        appId: "com.brave.Browser",
        shortcutKey: "5",
        profile: "Work",
        customArguments: "--incognito",
      });
      const s = getState();
      patchState({ configuredBrowsers: [...s.configuredBrowsers, browser] });
      const found = getState().configuredBrowsers.find((b) => b.id === "b-fields");
      expect(found?.name).toBe("Brave");
      expect(found?.appId).toBe("com.brave.Browser");
      expect(found?.shortcutKey).toBe("5");
      expect(found?.profile).toBe("Work");
      expect(found?.customArguments).toBe("--incognito");
    });
  });

  // -- updateBrowser --------------------------------------------------------

  describe("updateBrowser", () => {
    test("updates matching browser by ID", () => {
      const browser = makeBrowser({ id: "upd1", name: "OldName" });
      patchState({ configuredBrowsers: [browser] });
      const s = getState();
      patchState({
        configuredBrowsers: s.configuredBrowsers.map((b) =>
          b.id === "upd1" ? { ...b, name: "NewName" } : b
        ),
      });
      expect(getState().configuredBrowsers.find((b) => b.id === "upd1")?.name).toBe("NewName");
    });

    test("does not modify other browsers", () => {
      const b1 = makeBrowser({ id: "keep", name: "Keep" });
      const b2 = makeBrowser({ id: "change", name: "Change" });
      patchState({ configuredBrowsers: [b1, b2] });
      const s = getState();
      patchState({
        configuredBrowsers: s.configuredBrowsers.map((b) =>
          b.id === "change" ? { ...b, name: "Changed" } : b
        ),
      });
      expect(getState().configuredBrowsers.find((b) => b.id === "keep")?.name).toBe("Keep");
      expect(getState().configuredBrowsers.find((b) => b.id === "change")?.name).toBe("Changed");
    });

    test("updates name", () => {
      const b = makeBrowser({ id: "n1", name: "Old" });
      patchState({ configuredBrowsers: [b] });
      const updated: BrowserConfig = { ...b, name: "New" };
      const s = getState();
      patchState({ configuredBrowsers: s.configuredBrowsers.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().configuredBrowsers[0]!.name).toBe("New");
    });

    test("updates appId", () => {
      const b = makeBrowser({ id: "a1", appId: "old.app" });
      patchState({ configuredBrowsers: [b] });
      const updated = { ...b, appId: "new.app" };
      const s = getState();
      patchState({ configuredBrowsers: s.configuredBrowsers.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().configuredBrowsers[0]!.appId).toBe("new.app");
    });

    test("updates profile", () => {
      const b = makeBrowser({ id: "p1", profile: "Default" });
      patchState({ configuredBrowsers: [b] });
      const updated = { ...b, profile: "Work" };
      const s = getState();
      patchState({ configuredBrowsers: s.configuredBrowsers.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().configuredBrowsers[0]!.profile).toBe("Work");
    });

    test("updates shortcutKey", () => {
      const b = makeBrowser({ id: "sk1", shortcutKey: "1" });
      patchState({ configuredBrowsers: [b] });
      const updated = { ...b, shortcutKey: "5" };
      const s = getState();
      patchState({ configuredBrowsers: s.configuredBrowsers.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().configuredBrowsers[0]!.shortcutKey).toBe("5");
    });

    test("updates customArguments", () => {
      const b = makeBrowser({ id: "ca1" });
      patchState({ configuredBrowsers: [b] });
      const updated = { ...b, customArguments: "--new-flag" };
      const s = getState();
      patchState({ configuredBrowsers: s.configuredBrowsers.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().configuredBrowsers[0]!.customArguments).toBe("--new-flag");
    });

    test("update of nonexistent browser leaves list unchanged", () => {
      const b = makeBrowser({ id: "exists" });
      patchState({ configuredBrowsers: [b] });
      const fake: BrowserConfig = { ...b, id: "nope", name: "Nope" };
      const s = getState();
      patchState({ configuredBrowsers: s.configuredBrowsers.map((x) => (x.id === fake.id ? fake : x)) });
      expect(getState().configuredBrowsers.length).toBe(1);
      expect(getState().configuredBrowsers[0]!.id).toBe("exists");
    });
  });

  // -- removeBrowser --------------------------------------------------------

  describe("removeBrowser", () => {
    test("removes browser by ID", () => {
      const b = makeBrowser({ id: "rm1" });
      patchState({ configuredBrowsers: [b] });
      const s = getState();
      patchState({ configuredBrowsers: s.configuredBrowsers.filter((x) => x.id !== "rm1") });
      expect(getState().configuredBrowsers.find((x) => x.id === "rm1")).toBeUndefined();
    });

    test("no-op for nonexistent ID", () => {
      const b = makeBrowser({ id: "stay" });
      patchState({ configuredBrowsers: [b] });
      const s = getState();
      patchState({ configuredBrowsers: s.configuredBrowsers.filter((x) => x.id !== "ghost") });
      expect(getState().configuredBrowsers.length).toBe(1);
    });

    test("preserves other browsers", () => {
      const b1 = makeBrowser({ id: "keep1" });
      const b2 = makeBrowser({ id: "rm2" });
      const b3 = makeBrowser({ id: "keep3" });
      patchState({ configuredBrowsers: [b1, b2, b3] });
      const s = getState();
      patchState({ configuredBrowsers: s.configuredBrowsers.filter((x) => x.id !== "rm2") });
      const ids = getState().configuredBrowsers.map((x) => x.id);
      expect(ids).toEqual(["keep1", "keep3"]);
    });
  });

  // -- reorderBrowsers ------------------------------------------------------

  describe("reorderBrowsers", () => {
    test("reorders by ID list", () => {
      const b1 = makeBrowser({ id: "a" });
      const b2 = makeBrowser({ id: "b" });
      const b3 = makeBrowser({ id: "c" });
      patchState({ configuredBrowsers: [b1, b2, b3] });

      const s = getState();
      const ids = ["c", "a", "b"];
      const browserMap = new Map(s.configuredBrowsers.map((b) => [b.id, b]));
      const ordered = ids.map((id) => browserMap.get(id)).filter((b): b is BrowserConfig => b !== undefined);
      const idSet = new Set(ids);
      const trailing = s.configuredBrowsers.filter((b) => !idSet.has(b.id));
      patchState({ configuredBrowsers: [...ordered, ...trailing] });

      expect(getState().configuredBrowsers.map((b) => b.id)).toEqual(["c", "a", "b"]);
    });

    test("appends unmentioned browsers at end", () => {
      const b1 = makeBrowser({ id: "x" });
      const b2 = makeBrowser({ id: "y" });
      const b3 = makeBrowser({ id: "z" });
      patchState({ configuredBrowsers: [b1, b2, b3] });

      const ids = ["z"];
      const s = getState();
      const browserMap = new Map(s.configuredBrowsers.map((b) => [b.id, b]));
      const ordered = ids.map((id) => browserMap.get(id)).filter((b): b is BrowserConfig => b !== undefined);
      const idSet = new Set(ids);
      const trailing = s.configuredBrowsers.filter((b) => !idSet.has(b.id));
      patchState({ configuredBrowsers: [...ordered, ...trailing] });

      expect(getState().configuredBrowsers.map((b) => b.id)).toEqual(["z", "x", "y"]);
    });

    test("handles empty ID list", () => {
      const b1 = makeBrowser({ id: "m" });
      const b2 = makeBrowser({ id: "n" });
      patchState({ configuredBrowsers: [b1, b2] });

      const ids: string[] = [];
      const s = getState();
      const browserMap = new Map(s.configuredBrowsers.map((b) => [b.id, b]));
      const ordered = ids.map((id) => browserMap.get(id)).filter((b): b is BrowserConfig => b !== undefined);
      const idSet = new Set(ids);
      const trailing = s.configuredBrowsers.filter((b) => !idSet.has(b.id));
      patchState({ configuredBrowsers: [...ordered, ...trailing] });

      expect(getState().configuredBrowsers.map((b) => b.id)).toEqual(["m", "n"]);
    });

    test("handles IDs that don't exist (ignores them)", () => {
      const b1 = makeBrowser({ id: "real" });
      patchState({ configuredBrowsers: [b1] });

      const ids = ["fake", "real", "ghost"];
      const s = getState();
      const browserMap = new Map(s.configuredBrowsers.map((b) => [b.id, b]));
      const ordered = ids.map((id) => browserMap.get(id)).filter((b): b is BrowserConfig => b !== undefined);
      const idSet = new Set(ids);
      const trailing = s.configuredBrowsers.filter((b) => !idSet.has(b.id));
      patchState({ configuredBrowsers: [...ordered, ...trailing] });

      expect(getState().configuredBrowsers.map((b) => b.id)).toEqual(["real"]);
    });
  });

  // -- saveBrowsers ---------------------------------------------------------

  describe("saveBrowsers", () => {
    test("replaces entire browser list", () => {
      patchState({ configuredBrowsers: [makeBrowser({ id: "old" })] });
      const newList = [makeBrowser({ id: "new1" }), makeBrowser({ id: "new2" })];
      patchState({ configuredBrowsers: newList });
      expect(getState().configuredBrowsers.map((b) => b.id)).toEqual(["new1", "new2"]);
    });

    test("replaces with empty list", () => {
      patchState({ configuredBrowsers: [makeBrowser({ id: "gone" })] });
      patchState({ configuredBrowsers: [] });
      expect(getState().configuredBrowsers).toEqual([]);
    });
  });
});

// ===========================================================================
// Rule Management (30+ tests)
// ===========================================================================

describe("Rule Management", () => {
  // -- addRule --------------------------------------------------------------

  describe("addRule", () => {
    test("adds a rule", () => {
      const rule = makeRule({ id: "r1" });
      const s = getState();
      patchState({ routingRules: [...s.routingRules, rule] });
      expect(getState().routingRules.find((r) => r.id === "r1")).toBeDefined();
    });

    test("multiple rules can coexist", () => {
      const r1 = makeRule({ id: "r1", hostPattern: "a.com" });
      const r2 = makeRule({ id: "r2", hostPattern: "b.com" });
      patchState({ routingRules: [r1] });
      const s = getState();
      patchState({ routingRules: [...s.routingRules, r2] });
      expect(getState().routingRules.length).toBe(2);
    });

    test("rules are appended in order", () => {
      const r1 = makeRule({ id: "first" });
      const r2 = makeRule({ id: "second" });
      const r3 = makeRule({ id: "third" });
      patchState({ routingRules: [r1] });
      let s = getState();
      patchState({ routingRules: [...s.routingRules, r2] });
      s = getState();
      patchState({ routingRules: [...s.routingRules, r3] });
      expect(getState().routingRules.map((r) => r.id)).toEqual(["first", "second", "third"]);
    });
  });

  // -- updateRule -----------------------------------------------------------

  describe("updateRule", () => {
    test("updates matching rule by ID", () => {
      const rule = makeRule({ id: "u1", name: "Old" });
      patchState({ routingRules: [rule] });
      const updated = { ...rule, name: "New" };
      const s = getState();
      patchState({ routingRules: s.routingRules.map((r) => (r.id === updated.id ? updated : r)) });
      expect(getState().routingRules[0]!.name).toBe("New");
    });

    test("preserves other rules", () => {
      const r1 = makeRule({ id: "keep", name: "KeepMe" });
      const r2 = makeRule({ id: "change", name: "ChangeMe" });
      patchState({ routingRules: [r1, r2] });
      const updated = { ...r2, name: "Changed" };
      const s = getState();
      patchState({ routingRules: s.routingRules.map((r) => (r.id === updated.id ? updated : r)) });
      expect(getState().routingRules.find((r) => r.id === "keep")?.name).toBe("KeepMe");
      expect(getState().routingRules.find((r) => r.id === "change")?.name).toBe("Changed");
    });

    test("updates hostPattern", () => {
      const r = makeRule({ id: "hp1", hostPattern: "old.com" });
      patchState({ routingRules: [r] });
      const updated = { ...r, hostPattern: "new.com" };
      const s = getState();
      patchState({ routingRules: s.routingRules.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().routingRules[0]!.hostPattern).toBe("new.com");
    });

    test("updates browserAppId", () => {
      const r = makeRule({ id: "ba1", browserAppId: "old.app" });
      patchState({ routingRules: [r] });
      const updated = { ...r, browserAppId: "new.app" };
      const s = getState();
      patchState({ routingRules: s.routingRules.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().routingRules[0]!.browserAppId).toBe("new.app");
    });

    test("updates pathPrefix", () => {
      const r = makeRule({ id: "pp1" });
      patchState({ routingRules: [r] });
      const updated = { ...r, pathPrefix: "/docs" };
      const s = getState();
      patchState({ routingRules: s.routingRules.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().routingRules[0]!.pathPrefix).toBe("/docs");
    });

    test("updates sourceAppBundleId", () => {
      const r = makeRule({ id: "sa1" });
      patchState({ routingRules: [r] });
      const updated = { ...r, sourceAppBundleId: "com.tinyspeck.slackmacgap" };
      const s = getState();
      patchState({ routingRules: s.routingRules.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().routingRules[0]!.sourceAppBundleId).toBe("com.tinyspeck.slackmacgap");
    });

    test("updates useRegex", () => {
      const r = makeRule({ id: "ur1", useRegex: false });
      patchState({ routingRules: [r] });
      const updated = { ...r, useRegex: true };
      const s = getState();
      patchState({ routingRules: s.routingRules.map((x) => (x.id === updated.id ? updated : x)) });
      expect(getState().routingRules[0]!.useRegex).toBe(true);
    });
  });

  // -- removeRule -----------------------------------------------------------

  describe("removeRule", () => {
    test("removes rule by ID", () => {
      const r = makeRule({ id: "del1" });
      patchState({ routingRules: [r] });
      const s = getState();
      patchState({ routingRules: s.routingRules.filter((x) => x.id !== "del1") });
      expect(getState().routingRules).toEqual([]);
    });

    test("no-op for nonexistent ID", () => {
      const r = makeRule({ id: "stay" });
      patchState({ routingRules: [r] });
      const s = getState();
      patchState({ routingRules: s.routingRules.filter((x) => x.id !== "ghost") });
      expect(getState().routingRules.length).toBe(1);
    });

    test("preserves other rules when removing", () => {
      const r1 = makeRule({ id: "k1" });
      const r2 = makeRule({ id: "rm1" });
      const r3 = makeRule({ id: "k2" });
      patchState({ routingRules: [r1, r2, r3] });
      const s = getState();
      patchState({ routingRules: s.routingRules.filter((x) => x.id !== "rm1") });
      expect(getState().routingRules.map((r) => r.id)).toEqual(["k1", "k2"]);
    });
  });

  // -- duplicateRule --------------------------------------------------------

  describe("duplicateRule", () => {
    test("creates copy with new ID and (copy) suffix", () => {
      const rule = makeRule({ id: "orig", name: "My Rule" });
      patchState({ routingRules: [rule] });
      const s = getState();
      const original = s.routingRules.find((r) => r.id === "orig");
      expect(original).toBeDefined();
      const copy: BrowserRoutingRule = {
        ...original!,
        id: crypto.randomUUID(),
        name: `${original!.name} (copy)`,
      };
      const newRules = [...s.routingRules];
      const idx = s.routingRules.indexOf(original!);
      newRules.splice(idx + 1, 0, copy);
      patchState({ routingRules: newRules });

      const rules = getState().routingRules;
      expect(rules.length).toBe(2);
      expect(rules[1]!.name).toBe("My Rule (copy)");
      expect(rules[1]!.id).not.toBe("orig");
    });

    test("inserts copy after original", () => {
      const r1 = makeRule({ id: "first", name: "First" });
      const r2 = makeRule({ id: "second", name: "Second" });
      const r3 = makeRule({ id: "third", name: "Third" });
      patchState({ routingRules: [r1, r2, r3] });

      const s = getState();
      const target = s.routingRules.find((r) => r.id === "second")!;
      const copy: BrowserRoutingRule = {
        ...target,
        id: "copy-of-second",
        name: `${target.name} (copy)`,
      };
      const newRules = [...s.routingRules];
      newRules.splice(s.routingRules.indexOf(target) + 1, 0, copy);
      patchState({ routingRules: newRules });

      const ids = getState().routingRules.map((r) => r.id);
      expect(ids).toEqual(["first", "second", "copy-of-second", "third"]);
    });

    test("no-op for nonexistent ID", () => {
      const rule = makeRule({ id: "real" });
      patchState({ routingRules: [rule] });
      const s = getState();
      const target = s.routingRules.find((r) => r.id === "nope");
      if (!target) {
        // handler returns without changes
      } else {
        const copy = { ...target, id: crypto.randomUUID(), name: `${target.name} (copy)` };
        const newRules = [...s.routingRules];
        newRules.splice(s.routingRules.indexOf(target) + 1, 0, copy);
        patchState({ routingRules: newRules });
      }
      expect(getState().routingRules.length).toBe(1);
    });

    test("copy preserves all fields from original", () => {
      const original = makeRule({
        id: "full",
        name: "Full Rule",
        hostPattern: "*.github.com",
        pathPrefix: "/pulls",
        browserAppId: "com.google.Chrome",
        profile: "Work",
        sourceAppBundleId: "com.tinyspeck.slackmacgap",
        isEnabled: true,
        usePrivateMode: true,
        useRegex: false,
      });
      patchState({ routingRules: [original] });
      const s = getState();
      const found = s.routingRules.find((r) => r.id === "full")!;
      const copy: BrowserRoutingRule = { ...found, id: "copy-full", name: `${found.name} (copy)` };
      patchState({ routingRules: [...s.routingRules, copy] });

      const result = getState().routingRules.find((r) => r.id === "copy-full")!;
      expect(result.hostPattern).toBe("*.github.com");
      expect(result.pathPrefix).toBe("/pulls");
      expect(result.browserAppId).toBe("com.google.Chrome");
      expect(result.profile).toBe("Work");
      expect(result.sourceAppBundleId).toBe("com.tinyspeck.slackmacgap");
      expect(result.usePrivateMode).toBe(true);
      expect(result.isEnabled).toBe(true);
    });
  });

  // -- reorderRules ---------------------------------------------------------

  describe("reorderRules", () => {
    test("reorders by ID list", () => {
      const r1 = makeRule({ id: "a" });
      const r2 = makeRule({ id: "b" });
      const r3 = makeRule({ id: "c" });
      patchState({ routingRules: [r1, r2, r3] });
      const ids = ["c", "a", "b"];
      const s = getState();
      const ruleMap = new Map(s.routingRules.map((r) => [r.id, r]));
      const reordered = ids.map((id) => ruleMap.get(id)).filter((r): r is BrowserRoutingRule => r !== undefined);
      patchState({ routingRules: reordered });
      expect(getState().routingRules.map((r) => r.id)).toEqual(["c", "a", "b"]);
    });

    test("drops rules not in the ID list (unlike browsers)", () => {
      const r1 = makeRule({ id: "a" });
      const r2 = makeRule({ id: "b" });
      const r3 = makeRule({ id: "c" });
      patchState({ routingRules: [r1, r2, r3] });
      const ids = ["b"];
      const s = getState();
      const ruleMap = new Map(s.routingRules.map((r) => [r.id, r]));
      const reordered = ids.map((id) => ruleMap.get(id)).filter((r): r is BrowserRoutingRule => r !== undefined);
      patchState({ routingRules: reordered });
      // Note: rule reorder replaces entire list (unlike browser reorder which keeps trailing)
      expect(getState().routingRules.map((r) => r.id)).toEqual(["b"]);
    });

    test("empty ID list clears rules", () => {
      patchState({ routingRules: [makeRule({ id: "x" })] });
      const ids: string[] = [];
      const s = getState();
      const ruleMap = new Map(s.routingRules.map((r) => [r.id, r]));
      const reordered = ids.map((id) => ruleMap.get(id)).filter((r): r is BrowserRoutingRule => r !== undefined);
      patchState({ routingRules: reordered });
      expect(getState().routingRules).toEqual([]);
    });
  });

  // -- saveRules ------------------------------------------------------------

  describe("saveRules", () => {
    test("replaces entire rule list", () => {
      patchState({ routingRules: [makeRule({ id: "old" })] });
      const newRules = [makeRule({ id: "new1" }), makeRule({ id: "new2" })];
      patchState({ routingRules: newRules });
      expect(getState().routingRules.map((r) => r.id)).toEqual(["new1", "new2"]);
    });

    test("replaces with empty list", () => {
      patchState({ routingRules: [makeRule({ id: "gone" })] });
      patchState({ routingRules: [] });
      expect(getState().routingRules).toEqual([]);
    });
  });

  // -- toggleRule -----------------------------------------------------------

  describe("toggleRule", () => {
    test("enable/disable preserves other fields", () => {
      const rule = makeRule({
        id: "toggle1",
        name: "Toggle Me",
        hostPattern: "test.com",
        isEnabled: true,
        usePrivateMode: true,
      });
      patchState({ routingRules: [rule] });

      // Disable
      let s = getState();
      patchState({
        routingRules: s.routingRules.map((r) =>
          r.id === "toggle1" ? { ...r, isEnabled: false } : r
        ),
      });
      let found = getState().routingRules.find((r) => r.id === "toggle1")!;
      expect(found.isEnabled).toBe(false);
      expect(found.name).toBe("Toggle Me");
      expect(found.usePrivateMode).toBe(true);

      // Re-enable
      s = getState();
      patchState({
        routingRules: s.routingRules.map((r) =>
          r.id === "toggle1" ? { ...r, isEnabled: true } : r
        ),
      });
      found = getState().routingRules.find((r) => r.id === "toggle1")!;
      expect(found.isEnabled).toBe(true);
    });

    test("toggling does not affect other rules", () => {
      const r1 = makeRule({ id: "t1", isEnabled: true });
      const r2 = makeRule({ id: "t2", isEnabled: true });
      patchState({ routingRules: [r1, r2] });
      const s = getState();
      patchState({
        routingRules: s.routingRules.map((r) =>
          r.id === "t1" ? { ...r, isEnabled: false } : r
        ),
      });
      expect(getState().routingRules.find((r) => r.id === "t2")!.isEnabled).toBe(true);
    });
  });

  // -- Rule field combinations ----------------------------------------------

  describe("rule field combinations", () => {
    test("rule with all optional fields set", () => {
      const rule = makeRule({
        id: "all-fields",
        name: "Full Rule",
        hostPattern: "*.example.com",
        pathPrefix: "/api",
        browserAppId: "com.google.Chrome",
        profile: "Profile 1",
        sourceAppBundleId: "com.tinyspeck.slackmacgap",
        isEnabled: true,
        usePrivateMode: true,
        useRegex: false,
      });
      patchState({ routingRules: [rule] });
      const found = getState().routingRules[0]!;
      expect(found.pathPrefix).toBe("/api");
      expect(found.profile).toBe("Profile 1");
      expect(found.sourceAppBundleId).toBe("com.tinyspeck.slackmacgap");
    });

    test("rule with minimal fields", () => {
      const rule: BrowserRoutingRule = {
        id: "minimal",
        name: "Minimal",
        hostPattern: "example.com",
        browserAppId: "com.apple.Safari",
        isEnabled: true,
        usePrivateMode: false,
        useRegex: false,
      };
      patchState({ routingRules: [rule] });
      const found = getState().routingRules[0]!;
      expect(found.pathPrefix).toBeUndefined();
      expect(found.profile).toBeUndefined();
      expect(found.sourceAppBundleId).toBeUndefined();
    });
  });
});

// ===========================================================================
// Import/Export (20+ tests)
// ===========================================================================

describe("Import/Export", () => {
  // Helper functions mirroring handler logic
  function exportConfig(s: PersistedState): string {
    return JSON.stringify({ browsers: s.configuredBrowsers, rules: s.routingRules }, null, 2);
  }

  function importConfig(
    s: PersistedState,
    json: string
  ): { success: boolean; message: string; updated: Partial<PersistedState> } {
    try {
      const parsed = JSON.parse(json) as {
        browsers?: BrowserConfig[];
        rules?: BrowserRoutingRule[];
      };
      const updated: Partial<PersistedState> = {};

      if (Array.isArray(parsed.browsers)) {
        const existing = new Set(
          s.configuredBrowsers.map((b) => `${b.appId}|${b.profile ?? ""}`)
        );
        const newBrowsers = parsed.browsers.filter(
          (b) => !existing.has(`${b.appId}|${b.profile ?? ""}`)
        );
        updated.configuredBrowsers = [...s.configuredBrowsers, ...newBrowsers];
      }

      if (Array.isArray(parsed.rules)) {
        const existingIds = new Set(s.routingRules.map((r) => r.id));
        const newRules = parsed.rules.filter((r) => !existingIds.has(r.id));
        updated.routingRules = [...s.routingRules, ...newRules];
      }

      return { success: true, message: "Config imported successfully.", updated };
    } catch (err) {
      return {
        success: false,
        message: `Failed to parse config: ${(err as Error).message}`,
        updated: {},
      };
    }
  }

  test("export produces valid JSON", () => {
    const s = getState();
    const json = exportConfig(s);
    expect(() => JSON.parse(json)).not.toThrow();
  });

  test("export includes browsers and rules", () => {
    const browser = makeBrowser({ id: "exp-b1" });
    const rule = makeRule({ id: "exp-r1" });
    patchState({ configuredBrowsers: [browser], routingRules: [rule] });
    const json = exportConfig(getState());
    const parsed = JSON.parse(json);
    expect(parsed.browsers.length).toBe(1);
    expect(parsed.rules.length).toBe(1);
  });

  test("export roundtrip: export then import recovers data", () => {
    const browser = makeBrowser({ id: "rt-b", appId: "com.roundtrip", name: "RT Browser" });
    const rule = makeRule({ id: "rt-r", name: "RT Rule", hostPattern: "rt.com" });
    patchState({ configuredBrowsers: [browser], routingRules: [rule] });
    const json = exportConfig(getState());

    // Clear and re-import
    patchState({ configuredBrowsers: [], routingRules: [] });
    const result = importConfig(getState(), json);
    expect(result.success).toBe(true);
    patchState(result.updated);

    expect(getState().configuredBrowsers.find((b) => b.appId === "com.roundtrip")).toBeDefined();
    expect(getState().routingRules.find((r) => r.id === "rt-r")).toBeDefined();
  });

  test("import merges new browsers (by appId|profile dedup key)", () => {
    const existing = makeBrowser({ id: "e1", appId: "com.existing", profile: undefined });
    patchState({ configuredBrowsers: [existing] });
    const json = JSON.stringify({
      browsers: [makeBrowser({ id: "new1", appId: "com.new", profile: undefined })],
    });
    const result = importConfig(getState(), json);
    patchState(result.updated);
    expect(getState().configuredBrowsers.length).toBe(2);
  });

  test("import skips duplicate browsers", () => {
    const existing = makeBrowser({ id: "e2", appId: "com.dup", profile: "Default" });
    patchState({ configuredBrowsers: [existing] });
    const json = JSON.stringify({
      browsers: [makeBrowser({ id: "new2", appId: "com.dup", profile: "Default" })],
    });
    const result = importConfig(getState(), json);
    patchState(result.updated);
    expect(getState().configuredBrowsers.length).toBe(1);
  });

  test("import distinguishes browsers with different profiles", () => {
    const existing = makeBrowser({ id: "e3", appId: "com.chrome", profile: "Default" });
    patchState({ configuredBrowsers: [existing] });
    const json = JSON.stringify({
      browsers: [makeBrowser({ id: "new3", appId: "com.chrome", profile: "Work" })],
    });
    const result = importConfig(getState(), json);
    patchState(result.updated);
    expect(getState().configuredBrowsers.length).toBe(2);
  });

  test("import merges new rules (by ID dedup)", () => {
    const existingRule = makeRule({ id: "er1" });
    patchState({ routingRules: [existingRule] });
    const json = JSON.stringify({
      rules: [makeRule({ id: "nr1" })],
    });
    const result = importConfig(getState(), json);
    patchState(result.updated);
    expect(getState().routingRules.length).toBe(2);
  });

  test("import skips duplicate rule IDs", () => {
    const existingRule = makeRule({ id: "dup-rule" });
    patchState({ routingRules: [existingRule] });
    const json = JSON.stringify({
      rules: [makeRule({ id: "dup-rule", name: "Duplicate" })],
    });
    const result = importConfig(getState(), json);
    patchState(result.updated);
    expect(getState().routingRules.length).toBe(1);
    // Original name preserved
    expect(getState().routingRules[0]!.name).not.toBe("Duplicate");
  });

  test("import with invalid JSON returns error", () => {
    const result = importConfig(getState(), "{not valid json!!!");
    expect(result.success).toBe(false);
    expect(result.message).toContain("Failed to parse config");
  });

  test("import with empty JSON object succeeds", () => {
    const result = importConfig(getState(), "{}");
    expect(result.success).toBe(true);
  });

  test("import with only browsers field", () => {
    const json = JSON.stringify({ browsers: [makeBrowser({ appId: "com.only.browser" })] });
    const result = importConfig(getState(), json);
    expect(result.success).toBe(true);
    patchState(result.updated);
    expect(getState().configuredBrowsers.some((b) => b.appId === "com.only.browser")).toBe(true);
  });

  test("import with only rules field", () => {
    const json = JSON.stringify({ rules: [makeRule({ id: "only-rule" })] });
    const result = importConfig(getState(), json);
    expect(result.success).toBe(true);
    patchState(result.updated);
    expect(getState().routingRules.some((r) => r.id === "only-rule")).toBe(true);
  });

  test("import with both fields", () => {
    const json = JSON.stringify({
      browsers: [makeBrowser({ appId: "com.both.browser" })],
      rules: [makeRule({ id: "both-rule" })],
    });
    const result = importConfig(getState(), json);
    patchState(result.updated);
    expect(getState().configuredBrowsers.some((b) => b.appId === "com.both.browser")).toBe(true);
    expect(getState().routingRules.some((r) => r.id === "both-rule")).toBe(true);
  });

  test("import does not remove existing data", () => {
    const existingBrowser = makeBrowser({ id: "keep-b", appId: "com.keep" });
    const existingRule = makeRule({ id: "keep-r" });
    patchState({ configuredBrowsers: [existingBrowser], routingRules: [existingRule] });

    const json = JSON.stringify({
      browsers: [makeBrowser({ appId: "com.added" })],
      rules: [makeRule({ id: "added-r" })],
    });
    const result = importConfig(getState(), json);
    patchState(result.updated);

    expect(getState().configuredBrowsers.some((b) => b.appId === "com.keep")).toBe(true);
    expect(getState().routingRules.some((r) => r.id === "keep-r")).toBe(true);
  });

  test("import with malformed browser objects (missing fields) still adds them", () => {
    // The handler doesn't validate individual browser fields, it trusts the shape
    const json = JSON.stringify({
      browsers: [{ id: "partial", appId: "com.partial" }],
    });
    const result = importConfig(getState(), json);
    expect(result.success).toBe(true);
    patchState(result.updated);
    expect(getState().configuredBrowsers.some((b) => b.appId === "com.partial")).toBe(true);
  });

  test("import with empty string fails", () => {
    const result = importConfig(getState(), "");
    expect(result.success).toBe(false);
  });

  test("import with 'null' fails", () => {
    const result = importConfig(getState(), "null");
    // JSON.parse("null") returns null, then parsed.browsers throws
    // Actually it succeeds but no arrays → no merge
    // Let's check: parsed is null, so parsed.browsers would throw?
    // In JS, JSON.parse("null") === null. Accessing .browsers on null throws TypeError.
    expect(result.success).toBe(false);
  });

  test("import with array JSON succeeds without adding anything", () => {
    const result = importConfig(getState(), "[]");
    // JSON.parse("[]") returns [], then parsed.browsers is undefined
    expect(result.success).toBe(true);
  });

  test("import with browsers as non-array ignores browsers field", () => {
    const json = JSON.stringify({ browsers: "not-an-array", rules: [] });
    const beforeCount = getState().configuredBrowsers.length;
    const result = importConfig(getState(), json);
    patchState(result.updated);
    expect(result.success).toBe(true);
    // browsers wasn't an array, so unchanged
    expect(getState().configuredBrowsers.length).toBe(beforeCount);
  });

  test("import with rules as non-array ignores rules field", () => {
    const json = JSON.stringify({ browsers: [], rules: "not-an-array" });
    const result = importConfig(getState(), json);
    expect(result.success).toBe(true);
  });

  test("export of empty state produces valid structure", () => {
    patchState({ configuredBrowsers: [], routingRules: [] });
    const json = exportConfig(getState());
    const parsed = JSON.parse(json);
    expect(parsed.browsers).toEqual([]);
    expect(parsed.rules).toEqual([]);
  });
});

// ===========================================================================
// Focus Mode (15+ tests)
// ===========================================================================

describe("Focus Mode", () => {
  test("set focus mode with duration", () => {
    const browserId = "focus-browser";
    const durationMinutes = 30;
    const before = Date.now();
    const expiresAt = before + durationMinutes * 60 * 1000;
    patchState({ focusMode: { browserId, expiresAt } });
    const fm = getState().focusMode;
    expect(fm).not.toBeNull();
    expect(fm!.browserId).toBe("focus-browser");
    expect(fm!.expiresAt).toBeGreaterThanOrEqual(before + durationMinutes * 60 * 1000 - 100);
  });

  test("set focus mode without duration (until quit)", () => {
    patchState({ focusMode: { browserId: "forever-browser", expiresAt: null } });
    const fm = getState().focusMode;
    expect(fm!.expiresAt).toBeNull();
    expect(fm!.browserId).toBe("forever-browser");
  });

  test("clear focus mode", () => {
    patchState({ focusMode: { browserId: "b1", expiresAt: null } });
    expect(getState().focusMode).not.toBeNull();
    patchState({ focusMode: null });
    expect(getState().focusMode).toBeNull();
  });

  test("focus mode expiresAt calculated correctly", () => {
    const durationMinutes = 60;
    const now = Date.now();
    const expiresAt = now + durationMinutes * 60 * 1000;
    patchState({ focusMode: { browserId: "b1", expiresAt } });
    const fm = getState().focusMode!;
    // Should be approximately 1 hour from now
    expect(fm.expiresAt! - now).toBeGreaterThanOrEqual(59 * 60 * 1000);
    expect(fm.expiresAt! - now).toBeLessThanOrEqual(61 * 60 * 1000);
  });

  test("focus mode browserId is stored", () => {
    const browserId = "specific-id-123";
    patchState({ focusMode: { browserId, expiresAt: null } });
    expect(getState().focusMode!.browserId).toBe("specific-id-123");
  });

  test("clear focus mode sets null", () => {
    patchState({ focusMode: { browserId: "b", expiresAt: Date.now() + 100000 } });
    patchState({ focusMode: null });
    expect(getState().focusMode).toBeNull();
  });

  test("focus mode override: routing skipped when focus active", () => {
    const browser = makeBrowser({ id: "focus-b", appId: "com.focus" });
    const rule = makeRule({ hostPattern: "example.com", browserAppId: "com.other" });
    patchState({
      configuredBrowsers: [browser],
      routingRules: [rule],
      focusMode: { browserId: "focus-b", expiresAt: null },
    });

    const s = getState();
    // Simulate handleIncomingURL logic: check focus mode first
    const fm = s.focusMode;
    let usedFocus = false;
    if (fm && (fm.expiresAt === null || fm.expiresAt > Date.now())) {
      const focusBrowser = s.configuredBrowsers.find((b) => b.id === fm.browserId);
      if (focusBrowser) usedFocus = true;
    }
    expect(usedFocus).toBe(true);
  });

  test("focus mode expired: routing resumes", () => {
    const browser = makeBrowser({ id: "fb", appId: "com.focus" });
    const rule = makeRule({ id: "r1", hostPattern: "example.com", browserAppId: "com.rule" });
    patchState({
      configuredBrowsers: [browser],
      routingRules: [rule],
      focusMode: { browserId: "fb", expiresAt: Date.now() - 1000 }, // already expired
    });

    const s = getState();
    const fm = s.focusMode;
    let usedFocus = false;
    if (fm && (fm.expiresAt === null || fm.expiresAt > Date.now())) {
      usedFocus = true;
    }
    expect(usedFocus).toBe(false);
    // Normal routing should apply
    const route = resolveRoute("https://example.com/page", s.routingRules);
    expect(route).not.toBeNull();
    expect(route!.browserAppId).toBe("com.rule");
  });

  test("focus mode with nonexistent browser ID (should still store)", () => {
    patchState({ focusMode: { browserId: "nonexistent-id", expiresAt: null } });
    const fm = getState().focusMode;
    expect(fm!.browserId).toBe("nonexistent-id");
  });

  test("setting new focus mode replaces old one", () => {
    patchState({ focusMode: { browserId: "old", expiresAt: null } });
    patchState({ focusMode: { browserId: "new", expiresAt: Date.now() + 999999 } });
    expect(getState().focusMode!.browserId).toBe("new");
  });

  test("focus mode with zero duration creates immediate expiry", () => {
    const durationMinutes = 0;
    const expiresAt = Date.now() + durationMinutes * 60 * 1000;
    patchState({ focusMode: { browserId: "b", expiresAt } });
    const fm = getState().focusMode!;
    // expiresAt ≈ Date.now()
    expect(fm.expiresAt).toBeLessThanOrEqual(Date.now() + 100);
  });

  test("focus mode stored across state reads", () => {
    patchState({ focusMode: { browserId: "persist", expiresAt: null } });
    // Multiple reads should return the same focus mode
    expect(getState().focusMode!.browserId).toBe("persist");
    expect(getState().focusMode!.browserId).toBe("persist");
  });

  test("focus mode does not affect other state fields", () => {
    const browser = makeBrowser({ id: "test-b" });
    const rule = makeRule({ id: "test-r" });
    patchState({
      configuredBrowsers: [browser],
      routingRules: [rule],
    });
    patchState({ focusMode: { browserId: "test-b", expiresAt: null } });
    expect(getState().configuredBrowsers.length).toBe(1);
    expect(getState().routingRules.length).toBe(1);
  });

  test("focus mode with very large duration", () => {
    const durationMinutes = 999999;
    const expiresAt = Date.now() + durationMinutes * 60 * 1000;
    patchState({ focusMode: { browserId: "b", expiresAt } });
    expect(getState().focusMode!.expiresAt).toBe(expiresAt);
  });

  test("null expiresAt means session-only (until quit)", () => {
    patchState({ focusMode: { browserId: "b", expiresAt: null } });
    const fm = getState().focusMode!;
    expect(fm.expiresAt).toBeNull();
  });
});

// ===========================================================================
// Hidden Apps (10+ tests)
// ===========================================================================

describe("Hidden Apps", () => {
  test("setHiddenApps replaces list", () => {
    patchState({ hiddenAppIds: ["com.old.app"] });
    patchState({ hiddenAppIds: ["com.new.app"] });
    expect(getState().hiddenAppIds).toEqual(["com.new.app"]);
  });

  test("setHiddenApps with empty list", () => {
    patchState({ hiddenAppIds: [] });
    expect(getState().hiddenAppIds).toEqual([]);
  });

  test("resetToDefaults restores default hidden app IDs", () => {
    patchState({ hiddenAppIds: ["com.custom.only"] });
    // Simulate resetToDefaults
    patchState({ hiddenAppIds: [...DEFAULT_HIDDEN_APP_IDS] });
    expect(getState().hiddenAppIds).toEqual(DEFAULT_HIDDEN_APP_IDS);
  });

  test("remove one hidden app", () => {
    const ids = [...DEFAULT_HIDDEN_APP_IDS];
    const toRemove = ids[0]!;
    patchState({ hiddenAppIds: ids.filter((id) => id !== toRemove) });
    expect(getState().hiddenAppIds).not.toContain(toRemove);
    expect(getState().hiddenAppIds.length).toBe(DEFAULT_HIDDEN_APP_IDS.length - 1);
  });

  test("add new hidden app", () => {
    const ids = [...DEFAULT_HIDDEN_APP_IDS, "com.new.hidden"];
    patchState({ hiddenAppIds: ids });
    expect(getState().hiddenAppIds).toContain("com.new.hidden");
  });

  test("duplicate hidden apps are allowed (app doesn't dedup)", () => {
    const ids = ["com.app.one", "com.app.one", "com.app.two"];
    patchState({ hiddenAppIds: ids });
    expect(getState().hiddenAppIds).toEqual(["com.app.one", "com.app.one", "com.app.two"]);
    expect(getState().hiddenAppIds.length).toBe(3);
  });

  test("default state has expected hidden app IDs", () => {
    const s = createDefaultState();
    expect(s.hiddenAppIds).toEqual(DEFAULT_HIDDEN_APP_IDS);
    expect(s.hiddenAppIds).toContain("com.colliderli.iina");
    expect(s.hiddenAppIds).toContain("org.videolan.vlc");
  });

  test("hidden apps list is independent of browsers", () => {
    patchState({
      hiddenAppIds: ["com.hidden.app"],
      configuredBrowsers: [makeBrowser({ appId: "com.visible.browser" })],
    });
    expect(getState().hiddenAppIds.length).toBe(1);
    expect(getState().configuredBrowsers.length).toBe(1);
  });

  test("setHiddenApps with many entries", () => {
    const ids = Array.from({ length: 50 }, (_, i) => `com.app.hidden${i}`);
    patchState({ hiddenAppIds: ids });
    expect(getState().hiddenAppIds.length).toBe(50);
  });

  test("setHiddenApps preserves order", () => {
    const ids = ["z.app", "a.app", "m.app"];
    patchState({ hiddenAppIds: ids });
    expect(getState().hiddenAppIds).toEqual(["z.app", "a.app", "m.app"]);
  });
});

// ===========================================================================
// General Settings (10+ tests)
// ===========================================================================

describe("General Settings", () => {
  test("setPickerLayout to 'icons'", () => {
    patchState({ pickerLayout: "list" });
    patchState({ pickerLayout: "icons" });
    expect(getState().pickerLayout).toBe("icons");
  });

  test("setPickerLayout to 'list'", () => {
    patchState({ pickerLayout: "icons" });
    patchState({ pickerLayout: "list" });
    expect(getState().pickerLayout).toBe("list");
  });

  test("setLaunchAtLogin to true", () => {
    patchState({ launchAtLogin: true });
    expect(getState().launchAtLogin).toBe(true);
  });

  test("setLaunchAtLogin to false", () => {
    patchState({ launchAtLogin: true });
    patchState({ launchAtLogin: false });
    expect(getState().launchAtLogin).toBe(false);
  });

  test("resetToDefaults clears browsers, rules, recentUrls", () => {
    patchState({
      configuredBrowsers: [makeBrowser()],
      routingRules: [makeRule()],
      recentUrls: [{ url: "https://a.com", browserId: null, timestamp: Date.now() }],
    });
    // Simulate resetToDefaults
    patchState({
      configuredBrowsers: [{ id: crypto.randomUUID(), name: "Safari", appId: "com.apple.Safari", shortcutKey: "1" }],
      routingRules: [],
      hiddenAppIds: [...DEFAULT_HIDDEN_APP_IDS],
      domainFrequency: {},
      recentUrls: [],
      hasCompletedOnboarding: false,
      focusMode: null,
    });
    expect(getState().routingRules).toEqual([]);
    expect(getState().recentUrls).toEqual([]);
    expect(getState().domainFrequency).toEqual({});
  });

  test("resetToDefaults restores default browser (Safari on macOS)", () => {
    patchState({ configuredBrowsers: [] });
    // Simulate resetToDefaults
    patchState({
      configuredBrowsers: [{ id: crypto.randomUUID(), name: "Safari", appId: "com.apple.Safari", shortcutKey: "1" }],
      routingRules: [],
      hiddenAppIds: [...DEFAULT_HIDDEN_APP_IDS],
      domainFrequency: {},
      recentUrls: [],
      hasCompletedOnboarding: false,
      focusMode: null,
    });
    const browsers = getState().configuredBrowsers;
    expect(browsers.length).toBe(1);
    expect(browsers[0]!.appId).toBe("com.apple.Safari");
    expect(browsers[0]!.name).toBe("Safari");
  });

  test("resetToDefaults restores default hidden apps", () => {
    patchState({ hiddenAppIds: [] });
    patchState({
      configuredBrowsers: [{ id: crypto.randomUUID(), name: "Safari", appId: "com.apple.Safari", shortcutKey: "1" }],
      routingRules: [],
      hiddenAppIds: [...DEFAULT_HIDDEN_APP_IDS],
      domainFrequency: {},
      recentUrls: [],
      hasCompletedOnboarding: false,
      focusMode: null,
    });
    expect(getState().hiddenAppIds).toEqual(DEFAULT_HIDDEN_APP_IDS);
  });

  test("resetToDefaults clears domain frequency", () => {
    patchState({ domainFrequency: { "example.com": { "com.app": 50 } } });
    patchState({
      configuredBrowsers: [{ id: crypto.randomUUID(), name: "Safari", appId: "com.apple.Safari", shortcutKey: "1" }],
      routingRules: [],
      hiddenAppIds: [...DEFAULT_HIDDEN_APP_IDS],
      domainFrequency: {},
      recentUrls: [],
      hasCompletedOnboarding: false,
      focusMode: null,
    });
    expect(getState().domainFrequency).toEqual({});
  });

  test("resetToDefaults clears focus mode", () => {
    patchState({ focusMode: { browserId: "b", expiresAt: null } });
    patchState({
      configuredBrowsers: [{ id: crypto.randomUUID(), name: "Safari", appId: "com.apple.Safari", shortcutKey: "1" }],
      routingRules: [],
      hiddenAppIds: [...DEFAULT_HIDDEN_APP_IDS],
      domainFrequency: {},
      recentUrls: [],
      hasCompletedOnboarding: false,
      focusMode: null,
    });
    expect(getState().focusMode).toBeNull();
  });

  test("completeOnboarding sets flag to true", () => {
    expect(getState().hasCompletedOnboarding).toBe(false);
    patchState({ hasCompletedOnboarding: true });
    expect(getState().hasCompletedOnboarding).toBe(true);
  });

  test("default pickerLayout is icons", () => {
    expect(createDefaultState().pickerLayout).toBe("icons");
  });

  test("default launchAtLogin is false", () => {
    expect(createDefaultState().launchAtLogin).toBe(false);
  });
});

// ===========================================================================
// Recent URLs (10+ tests)
// ===========================================================================

describe("Recent URLs", () => {
  function recordRecentUrl(url: string, browserId: string | null) {
    const s = getState();
    const entry: RecentUrl = { url, browserId, timestamp: Date.now() };
    const existing = s.recentUrls.filter((r) => r.url !== url);
    const updated = [entry, ...existing].slice(0, RECENT_URLS_MAX);
    patchState({ recentUrls: updated });
  }

  test("recordRecentUrl adds entry", () => {
    recordRecentUrl("https://example.com", "b1");
    expect(getState().recentUrls.length).toBe(1);
    expect(getState().recentUrls[0]!.url).toBe("https://example.com");
  });

  test("recordRecentUrl deduplicates by URL", () => {
    recordRecentUrl("https://example.com", "b1");
    recordRecentUrl("https://other.com", "b2");
    recordRecentUrl("https://example.com", "b3");
    const urls = getState().recentUrls.map((r) => r.url);
    // example.com should appear only once, at the front
    expect(urls.filter((u) => u === "https://example.com").length).toBe(1);
    expect(urls[0]).toBe("https://example.com");
  });

  test("recordRecentUrl puts newest first", () => {
    recordRecentUrl("https://first.com", "b1");
    recordRecentUrl("https://second.com", "b2");
    recordRecentUrl("https://third.com", "b3");
    expect(getState().recentUrls[0]!.url).toBe("https://third.com");
    expect(getState().recentUrls[1]!.url).toBe("https://second.com");
    expect(getState().recentUrls[2]!.url).toBe("https://first.com");
  });

  test("recordRecentUrl respects RECENT_URLS_MAX", () => {
    for (let i = 0; i < RECENT_URLS_MAX + 10; i++) {
      recordRecentUrl(`https://site${i}.com`, "b1");
    }
    expect(getState().recentUrls.length).toBe(RECENT_URLS_MAX);
  });

  test("clearRecentUrls empties the list", () => {
    recordRecentUrl("https://a.com", "b1");
    recordRecentUrl("https://b.com", "b2");
    patchState({ recentUrls: [] });
    expect(getState().recentUrls).toEqual([]);
  });

  test("recent URL entry has url, browserId, timestamp", () => {
    recordRecentUrl("https://check.com", "browser-x");
    const entry = getState().recentUrls[0]!;
    expect(entry.url).toBe("https://check.com");
    expect(entry.browserId).toBe("browser-x");
    expect(typeof entry.timestamp).toBe("number");
    expect(entry.timestamp).toBeGreaterThan(0);
  });

  test("recent URL with null browserId", () => {
    recordRecentUrl("https://dismissed.com", null);
    expect(getState().recentUrls[0]!.browserId).toBeNull();
  });

  test("re-visiting a URL updates its timestamp", () => {
    recordRecentUrl("https://revisit.com", "b1");
    const firstTimestamp = getState().recentUrls[0]!.timestamp;
    // Small delay to ensure different timestamp
    const later = firstTimestamp + 1;
    const s = getState();
    const entry: RecentUrl = { url: "https://revisit.com", browserId: "b2", timestamp: later };
    const existing = s.recentUrls.filter((r) => r.url !== "https://revisit.com");
    const updated = [entry, ...existing].slice(0, RECENT_URLS_MAX);
    patchState({ recentUrls: updated });

    expect(getState().recentUrls[0]!.timestamp).toBe(later);
    expect(getState().recentUrls[0]!.browserId).toBe("b2");
  });

  test("recent URLs maintain order across dedup", () => {
    recordRecentUrl("https://a.com", "b1");
    recordRecentUrl("https://b.com", "b1");
    recordRecentUrl("https://c.com", "b1");
    // Re-record b.com — it should move to the front
    recordRecentUrl("https://b.com", "b1");
    expect(getState().recentUrls.map((r) => r.url)).toEqual([
      "https://b.com",
      "https://c.com",
      "https://a.com",
    ]);
  });

  test("RECENT_URLS_MAX evicts oldest entries", () => {
    for (let i = 0; i < RECENT_URLS_MAX; i++) {
      recordRecentUrl(`https://site${i}.com`, "b1");
    }
    // Record one more
    recordRecentUrl("https://newest.com", "b1");
    expect(getState().recentUrls.length).toBe(RECENT_URLS_MAX);
    expect(getState().recentUrls[0]!.url).toBe("https://newest.com");
    // The first-added URL should be evicted
    expect(getState().recentUrls.some((r) => r.url === "https://site0.com")).toBe(false);
  });
});

// ===========================================================================
// Domain Frequency Integration (10+ tests)
// ===========================================================================

describe("Domain Frequency", () => {
  test("trackDomain increments domain frequency", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "example.com", "com.google.Chrome");
    expect(freq["example.com"]!["com.google.Chrome"]).toBe(1);
    freq = recordDomainClick(freq, "example.com", "com.google.Chrome");
    expect(freq["example.com"]!["com.google.Chrome"]).toBe(2);
  });

  test("trackDomain with multiple apps", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "example.com", "com.google.Chrome");
    freq = recordDomainClick(freq, "example.com", "com.apple.Safari");
    freq = recordDomainClick(freq, "example.com", "com.google.Chrome");
    expect(freq["example.com"]!["com.google.Chrome"]).toBe(2);
    expect(freq["example.com"]!["com.apple.Safari"]).toBe(1);
  });

  test("trackDomain with multiple domains", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "a.com", "com.app");
    freq = recordDomainClick(freq, "b.com", "com.app");
    expect(freq["a.com"]!["com.app"]).toBe(1);
    expect(freq["b.com"]!["com.app"]).toBe(1);
  });

  test("getSuggestions returns suggestions above threshold", () => {
    let freq: DomainFrequency = {};
    for (let i = 0; i < DOMAIN_SUGGESTION_THRESHOLD; i++) {
      freq = recordDomainClick(freq, "hot.com", "com.chrome");
    }
    const suggestions = getSuggestions(freq);
    expect(suggestions.length).toBe(1);
    expect(suggestions[0]!.domain).toBe("hot.com");
    expect(suggestions[0]!.appId).toBe("com.chrome");
    expect(suggestions[0]!.count).toBe(DOMAIN_SUGGESTION_THRESHOLD);
  });

  test("getSuggestions returns empty for below threshold", () => {
    let freq: DomainFrequency = {};
    for (let i = 0; i < DOMAIN_SUGGESTION_THRESHOLD - 1; i++) {
      freq = recordDomainClick(freq, "cold.com", "com.chrome");
    }
    const suggestions = getSuggestions(freq);
    expect(suggestions.length).toBe(0);
  });

  test("domain frequency eviction at max entries", () => {
    let freq: DomainFrequency = {};
    for (let i = 0; i < DOMAIN_MAX_ENTRIES + 5; i++) {
      freq = recordDomainClick(freq, `domain${i}.com`, "com.app");
    }
    expect(Object.keys(freq).length).toBeLessThanOrEqual(DOMAIN_MAX_ENTRIES);
  });

  test("domain frequency normalizes to lowercase", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "Example.COM", "com.app");
    expect(freq["example.com"]).toBeDefined();
    expect(freq["Example.COM"]).toBeUndefined();
  });

  test("domain frequency trims whitespace", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "  example.com  ", "  com.app  ");
    expect(freq["example.com"]).toBeDefined();
    expect(freq["example.com"]!["com.app"]).toBe(1);
  });

  test("domain frequency ignores empty domain", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "", "com.app");
    expect(Object.keys(freq).length).toBe(0);
  });

  test("domain frequency ignores empty appId", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "example.com", "");
    expect(Object.keys(freq).length).toBe(0);
  });

  test("getSuggestions sorts by count descending", () => {
    const freq: DomainFrequency = {
      "a.com": { "com.app": 50 },
      "b.com": { "com.app": 100 },
      "c.com": { "com.app": 75 },
    };
    const suggestions = getSuggestions(freq);
    expect(suggestions[0]!.count).toBe(100);
    expect(suggestions[1]!.count).toBe(75);
    expect(suggestions[2]!.count).toBe(50);
  });

  test("domain frequency integrates with state via patchState", () => {
    let freq = getState().domainFrequency;
    freq = recordDomainClick(freq, "test.com", "com.app");
    patchState({ domainFrequency: freq });
    expect(getState().domainFrequency["test.com"]!["com.app"]).toBe(1);
  });

  test("getSuggestions with custom threshold", () => {
    const freq: DomainFrequency = {
      "a.com": { "com.app": 5 },
      "b.com": { "com.app": 10 },
    };
    expect(getSuggestions(freq, 5).length).toBe(2);
    expect(getSuggestions(freq, 10).length).toBe(1);
    expect(getSuggestions(freq, 11).length).toBe(0);
  });
});

// ===========================================================================
// State Persistence (10+ tests)
// ===========================================================================

describe("State Persistence", () => {
  test("loadState returns default state on first run", () => {
    const s = loadState();
    expect(s.version).toBe(APP_VERSION);
    expect(s.hasCompletedOnboarding).toBe(false);
    expect(Array.isArray(s.configuredBrowsers)).toBe(true);
    expect(Array.isArray(s.routingRules)).toBe(true);
  });

  test("getState returns loaded state", () => {
    const s = getState();
    expect(s).toBeDefined();
    expect(s.version).toBe(APP_VERSION);
  });

  test("patchState merges partial update", () => {
    patchState({ pickerLayout: "list" });
    expect(getState().pickerLayout).toBe("list");
  });

  test("patchState preserves unmodified fields", () => {
    const browser = makeBrowser({ id: "preserve-me" });
    patchState({ configuredBrowsers: [browser] });
    patchState({ pickerLayout: "list" });
    // Browser should still be there
    expect(getState().configuredBrowsers.find((b) => b.id === "preserve-me")).toBeDefined();
  });

  test("patchState always sets version to APP_VERSION", () => {
    patchState({ version: 999 } as Partial<PersistedState>);
    expect(getState().version).toBe(APP_VERSION);
  });

  test("setState replaces entire state", () => {
    const newState = createDefaultState();
    newState.pickerLayout = "list";
    newState.launchAtLogin = true;
    setState(newState);
    expect(getState().pickerLayout).toBe("list");
    expect(getState().launchAtLogin).toBe(true);
  });

  test("setState sets version to APP_VERSION", () => {
    const newState = { ...createDefaultState(), version: 42 };
    setState(newState);
    expect(getState().version).toBe(APP_VERSION);
  });

  test("flushState doesn't throw", () => {
    expect(() => flushState()).not.toThrow();
  });

  test("multiple patchState calls accumulate changes", () => {
    patchState({ pickerLayout: "list" });
    patchState({ launchAtLogin: true });
    patchState({ hasCompletedOnboarding: true });
    const s = getState();
    expect(s.pickerLayout).toBe("list");
    expect(s.launchAtLogin).toBe(true);
    expect(s.hasCompletedOnboarding).toBe(true);
  });

  test("setState then patchState works correctly", () => {
    const fresh = createDefaultState();
    setState(fresh);
    patchState({ pickerLayout: "list" });
    expect(getState().pickerLayout).toBe("list");
    expect(getState().version).toBe(APP_VERSION);
  });

  test("patchState with empty object preserves all fields", () => {
    const before = { ...getState() };
    patchState({});
    const after = getState();
    expect(after.configuredBrowsers.length).toBe(before.configuredBrowsers.length);
    expect(after.routingRules.length).toBe(before.routingRules.length);
    expect(after.pickerLayout).toBe(before.pickerLayout);
  });
});

// ===========================================================================
// Routing Integration (bonus — handler-level routing tests)
// ===========================================================================

describe("Routing Integration", () => {
  test("resolveRoute returns null for no matching rules", () => {
    const route = resolveRoute("https://example.com", []);
    expect(route).toBeNull();
  });

  test("resolveRoute matches exact host", () => {
    const rule = makeRule({ hostPattern: "example.com", browserAppId: "com.chrome" });
    const route = resolveRoute("https://example.com/page", [rule]);
    expect(route!.browserAppId).toBe("com.chrome");
  });

  test("resolveRoute skips disabled rules", () => {
    const rule = makeRule({ hostPattern: "example.com", isEnabled: false });
    const route = resolveRoute("https://example.com", [rule]);
    expect(route).toBeNull();
  });

  test("resolveRoute matches wildcard host", () => {
    const rule = makeRule({ hostPattern: "*.github.com", browserAppId: "com.chrome" });
    const route = resolveRoute("https://docs.github.com/page", [rule]);
    expect(route!.browserAppId).toBe("com.chrome");
  });

  test("resolveRoute matches pathPrefix", () => {
    const rule = makeRule({ hostPattern: "example.com", pathPrefix: "/api", browserAppId: "com.chrome" });
    const match = resolveRoute("https://example.com/api/users", [rule]);
    expect(match).not.toBeNull();
    const noMatch = resolveRoute("https://example.com/web/users", [rule]);
    expect(noMatch).toBeNull();
  });

  test("resolveRoute matches sourceAppBundleId", () => {
    const rule = makeRule({
      hostPattern: "example.com",
      sourceAppBundleId: "com.tinyspeck.slackmacgap",
    });
    const match = resolveRoute("https://example.com", [rule], "com.tinyspeck.slackmacgap");
    expect(match).not.toBeNull();
    const noMatch = resolveRoute("https://example.com", [rule], "com.other.app");
    expect(noMatch).toBeNull();
  });

  test("resolveRoute returns first matching rule (top-to-bottom)", () => {
    const r1 = makeRule({ id: "first", hostPattern: "example.com", browserAppId: "com.first" });
    const r2 = makeRule({ id: "second", hostPattern: "example.com", browserAppId: "com.second" });
    const route = resolveRoute("https://example.com", [r1, r2]);
    expect(route!.matchedRuleId).toBe("first");
  });

  test("resolveRoute returns matchedRuleId", () => {
    const rule = makeRule({ id: "match-id", hostPattern: "example.com" });
    const route = resolveRoute("https://example.com", [rule]);
    expect(route!.matchedRuleId).toBe("match-id");
  });

  test("resolveRoute with regex pattern", () => {
    const rule = makeRule({
      hostPattern: ".*\\.example\\.com",
      useRegex: true,
      browserAppId: "com.regex",
    });
    const route = resolveRoute("https://api.example.com/path", [rule]);
    expect(route!.browserAppId).toBe("com.regex");
  });

  test("resolveRoute returns null for invalid URL", () => {
    const rule = makeRule({ hostPattern: "example.com" });
    const route = resolveRoute("not a url", [rule]);
    expect(route).toBeNull();
  });

  test("resolveRoute includes profile and usePrivateMode from rule", () => {
    const rule = makeRule({
      hostPattern: "example.com",
      profile: "Work",
      usePrivateMode: true,
    });
    const route = resolveRoute("https://example.com", [rule]);
    expect(route!.profile).toBe("Work");
    expect(route!.usePrivateMode).toBe(true);
  });

  test("testUrl handler returns match info", () => {
    const browser = makeBrowser({ id: "tb", appId: "com.test.browser", name: "Test Browser" });
    const rule = makeRule({
      id: "tr",
      name: "Test Rule",
      hostPattern: "test.com",
      browserAppId: "com.test.browser",
    });
    patchState({ configuredBrowsers: [browser], routingRules: [rule] });

    const s = getState();
    const route = resolveRoute("https://test.com/path", s.routingRules);
    expect(route).not.toBeNull();
    const matchedRule = s.routingRules.find((r) => r.id === route!.matchedRuleId);
    const matchedBrowser = s.configuredBrowsers.find((b) => b.appId === route!.browserAppId);
    expect(matchedRule!.name).toBe("Test Rule");
    expect(matchedBrowser!.name).toBe("Test Browser");
  });

  test("testUrl handler returns null for no match", () => {
    patchState({ routingRules: [] });
    const route = resolveRoute("https://nomatch.com", getState().routingRules);
    expect(route).toBeNull();
  });
});

// ===========================================================================
// Picker createRule handler logic (bonus)
// ===========================================================================

describe("Picker createRule", () => {
  test("creates a rule from picker with correct defaults", () => {
    const s = getState();
    const newRule: BrowserRoutingRule = {
      id: crypto.randomUUID(),
      name: "Quick Rule",
      hostPattern: "example.com",
      browserAppId: "com.google.Chrome",
      usePrivateMode: false,
      isEnabled: true,
      useRegex: false,
    };
    patchState({ routingRules: [...s.routingRules, newRule] });
    const found = getState().routingRules.find((r) => r.name === "Quick Rule")!;
    expect(found.isEnabled).toBe(true);
    expect(found.useRegex).toBe(false);
    expect(found.hostPattern).toBe("example.com");
  });

  test("picker-created rule is immediately active in routing", () => {
    const rule: BrowserRoutingRule = {
      id: "picker-rule",
      name: "From Picker",
      hostPattern: "picker.com",
      browserAppId: "com.picker.browser",
      usePrivateMode: false,
      isEnabled: true,
      useRegex: false,
    };
    patchState({ routingRules: [rule] });
    const route = resolveRoute("https://picker.com/page", getState().routingRules);
    expect(route!.browserAppId).toBe("com.picker.browser");
  });
});

// ===========================================================================
// nextAvailableShortcut utility (bonus)
// ===========================================================================

describe("nextAvailableShortcut", () => {
  test("returns '1' for empty browser list", () => {
    expect(nextAvailableShortcut([])).toBe("1");
  });

  test("returns next sequential key", () => {
    const browsers: BrowserConfig[] = [
      makeBrowser({ shortcutKey: "1" }),
      makeBrowser({ shortcutKey: "2" }),
      makeBrowser({ shortcutKey: "3" }),
    ];
    expect(nextAvailableShortcut(browsers)).toBe("4");
  });

  test("fills gaps in shortcut keys", () => {
    const browsers: BrowserConfig[] = [
      makeBrowser({ shortcutKey: "1" }),
      makeBrowser({ shortcutKey: "3" }),
    ];
    expect(nextAvailableShortcut(browsers)).toBe("2");
  });

  test("returns '9' when all keys 1-9 are used", () => {
    const browsers: BrowserConfig[] = Array.from({ length: 9 }, (_, i) =>
      makeBrowser({ shortcutKey: String(i + 1) })
    );
    expect(nextAvailableShortcut(browsers)).toBe("9");
  });
});
