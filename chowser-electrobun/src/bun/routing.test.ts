import { describe, expect, test } from "bun:test";
import {
  resolveRoute,
  recordDomainClick,
  getSuggestions,
  ruleDescription,
} from "./routing.ts";
import type { BrowserRoutingRule, DomainFrequency } from "./models.ts";
import { DOMAIN_SUGGESTION_THRESHOLD, DOMAIN_MAX_ENTRIES } from "./models.ts";

// ---------------------------------------------------------------------------
// Helper to build rule objects with sensible defaults
// ---------------------------------------------------------------------------

function rule(partial: Partial<BrowserRoutingRule> = {}): BrowserRoutingRule {
  return {
    id: "r1",
    name: "rule",
    hostPattern: "example.com",
    browserAppId: "com.apple.Safari",
    isEnabled: true,
    usePrivateMode: false,
    useRegex: false,
    ...partial,
  };
}

// ===========================================================================
// resolveRoute
// ===========================================================================

describe("resolveRoute", () => {
  // -- Basic matching --

  test("returns null when no rules", () => {
    expect(resolveRoute("https://example.com", [])).toBeNull();
  });

  test("returns null when URL is invalid", () => {
    expect(resolveRoute("not-a-url", [rule()])).toBeNull();
  });

  test("matches exact hostname", () => {
    const result = resolveRoute("https://example.com/page", [rule()]);
    expect(result).not.toBeNull();
    expect(result!.browserAppId).toBe("com.apple.Safari");
  });

  test("URL https://github.com with rule 'github.com' matches", () => {
    const result = resolveRoute("https://github.com", [
      rule({ hostPattern: "github.com" }),
    ]);
    expect(result).not.toBeNull();
  });

  test("URL https://GITHUB.COM with rule 'github.com' matches (case-insensitive)", () => {
    const result = resolveRoute("https://GITHUB.COM/repo", [
      rule({ hostPattern: "github.com" }),
    ]);
    expect(result).not.toBeNull();
  });

  // -- Glob wildcard matching --

  test("wildcard *.github.com matches sub.github.com", () => {
    const result = resolveRoute("https://docs.github.com/en", [
      rule({ hostPattern: "*.github.com" }),
    ]);
    expect(result).not.toBeNull();
  });

  test("wildcard *.github.com does NOT match github.com itself", () => {
    const result = resolveRoute("https://github.com", [
      rule({ hostPattern: "*.github.com" }),
    ]);
    expect(result).toBeNull();
  });

  test("double-wildcard ** matches across multiple dots", () => {
    const result = resolveRoute("https://a.b.c.example.com", [
      rule({ hostPattern: "**.example.com" }),
    ]);
    expect(result).not.toBeNull();
  });

  test("single-wildcard * within segment matches single segment", () => {
    const result = resolveRoute("https://docs.google.com", [
      rule({ hostPattern: "docs.*.com" }),
    ]);
    expect(result).not.toBeNull();
  });

  test("glob *.example.com does not match notexample.com", () => {
    const result = resolveRoute("https://notexample.com", [
      rule({ hostPattern: "*.example.com" }),
    ]);
    expect(result).toBeNull();
  });

  // -- Disabled rules --

  test("skips disabled rules (isEnabled: false)", () => {
    const result = resolveRoute("https://example.com", [
      rule({ isEnabled: false }),
    ]);
    expect(result).toBeNull();
  });

  // -- Priority order --

  test("returns first matching rule (priority order)", () => {
    const result = resolveRoute("https://example.com", [
      rule({ id: "first", browserAppId: "com.google.Chrome" }),
      rule({ id: "second", browserAppId: "com.apple.Safari" }),
    ]);
    expect(result!.matchedRuleId).toBe("first");
    expect(result!.browserAppId).toBe("com.google.Chrome");
  });

  test("multiple rules, first match wins even if later is more specific", () => {
    const result = resolveRoute("https://docs.github.com/repos", [
      rule({ id: "broad", hostPattern: "*.github.com" }),
      rule({ id: "specific", hostPattern: "docs.github.com", pathPrefix: "/repos" }),
    ]);
    expect(result!.matchedRuleId).toBe("broad");
  });

  // -- Path prefix --

  test("respects path prefix matching (case-insensitive)", () => {
    const result = resolveRoute("https://example.com/Work/docs", [
      rule({ pathPrefix: "/work" }),
    ]);
    expect(result).not.toBeNull();
  });

  test("ignores path prefix when not set on rule", () => {
    const result = resolveRoute("https://example.com/any/path", [rule()]);
    expect(result).not.toBeNull();
  });

  test("path prefix '/work' matches '/work/something'", () => {
    const result = resolveRoute("https://example.com/work/something", [
      rule({ pathPrefix: "/work" }),
    ]);
    expect(result).not.toBeNull();
  });

  test("path prefix '/work' DOES match '/workshop' (prefix match)", () => {
    const result = resolveRoute("https://example.com/workshop", [
      rule({ pathPrefix: "/work" }),
    ]);
    // startsWith("/work") is true for "/workshop"
    expect(result).not.toBeNull();
  });

  test("path prefix '/admin' does NOT match '/user/admin'", () => {
    const result = resolveRoute("https://example.com/user/admin", [
      rule({ pathPrefix: "/admin" }),
    ]);
    expect(result).toBeNull();
  });

  test("URL with trailing slash path matches path prefix", () => {
    const result = resolveRoute("https://example.com/docs/", [
      rule({ pathPrefix: "/docs" }),
    ]);
    expect(result).not.toBeNull();
  });

  // -- Source app matching --

  test("rule with sourceAppBundleId matches when source app matches", () => {
    const result = resolveRoute(
      "https://example.com",
      [rule({ sourceAppBundleId: "com.tinyspeck.slackmacgap" })],
      "com.tinyspeck.slackmacgap"
    );
    expect(result).not.toBeNull();
  });

  test("rule with sourceAppBundleId does NOT match when source app differs", () => {
    const result = resolveRoute(
      "https://example.com",
      [rule({ sourceAppBundleId: "com.tinyspeck.slackmacgap" })],
      "com.apple.mail"
    );
    expect(result).toBeNull();
  });

  test("rule without sourceAppBundleId matches regardless of source app", () => {
    const result = resolveRoute(
      "https://example.com",
      [rule()],
      "com.any.app"
    );
    expect(result).not.toBeNull();
  });

  // -- Return values --

  test("returns profile when set on rule", () => {
    const result = resolveRoute("https://example.com", [
      rule({ profile: "Work" }),
    ]);
    expect(result!.profile).toBe("Work");
  });

  test("returns usePrivateMode when set", () => {
    const result = resolveRoute("https://example.com", [
      rule({ usePrivateMode: true }),
    ]);
    expect(result!.usePrivateMode).toBe(true);
  });

  test("returns matchedRuleId", () => {
    const result = resolveRoute("https://example.com", [
      rule({ id: "my-rule" }),
    ]);
    expect(result!.matchedRuleId).toBe("my-rule");
  });

  // -- Regex mode --

  test("regex mode: simple regex matches", () => {
    const result = resolveRoute("https://github.com", [
      rule({ useRegex: true, hostPattern: "github\\.com" }),
    ]);
    expect(result).not.toBeNull();
  });

  test("regex mode: full-string match (anchored)", () => {
    const match = resolveRoute("https://api.example.com", [
      rule({ useRegex: true, hostPattern: "api\\.example\\.com" }),
    ]);
    expect(match).not.toBeNull();

    const noMatch = resolveRoute("https://xapi.example.com", [
      rule({ useRegex: true, hostPattern: "api\\.example\\.com" }),
    ]);
    expect(noMatch).toBeNull();
  });

  test("regex mode: alternation matches both sides", () => {
    const r = rule({ useRegex: true, hostPattern: "github\\.com|gitlab\\.com" });
    expect(resolveRoute("https://github.com", [r])).not.toBeNull();
    expect(resolveRoute("https://gitlab.com", [r])).not.toBeNull();
    expect(resolveRoute("https://bitbucket.org", [r])).toBeNull();
  });

  test("regex mode: invalid regex returns no match (doesn't crash)", () => {
    const result = resolveRoute("https://example.com", [
      rule({ useRegex: true, hostPattern: "[invalid(" }),
    ]);
    expect(result).toBeNull();
  });

  test("regex mode: case-insensitive matching", () => {
    const result = resolveRoute("https://GITHUB.COM", [
      rule({ useRegex: true, hostPattern: "github\\.com" }),
    ]);
    expect(result).not.toBeNull();
  });

  // -- Compound rules --

  test("rules with path + host both required", () => {
    const r = rule({ hostPattern: "example.com", pathPrefix: "/api" });
    expect(resolveRoute("https://example.com/api/v1", [r])).not.toBeNull();
    expect(resolveRoute("https://example.com/web", [r])).toBeNull();
    expect(resolveRoute("https://other.com/api/v1", [r])).toBeNull();
  });

  test("rule with source app + host + path all required", () => {
    const r = rule({
      hostPattern: "example.com",
      pathPrefix: "/dashboard",
      sourceAppBundleId: "com.slack",
    });
    expect(
      resolveRoute("https://example.com/dashboard", [r], "com.slack")
    ).not.toBeNull();
    expect(
      resolveRoute("https://example.com/dashboard", [r], "com.other")
    ).toBeNull();
    expect(
      resolveRoute("https://example.com/other", [r], "com.slack")
    ).toBeNull();
  });

  // -- Empty/wildcard host patterns --

  test("empty hostPattern matches everything", () => {
    const result = resolveRoute("https://anything.com", [
      rule({ hostPattern: "" }),
    ]);
    expect(result).not.toBeNull();
  });

  test('hostPattern "*" matches everything', () => {
    const result = resolveRoute("https://anything.com", [
      rule({ hostPattern: "*" }),
    ]);
    expect(result).not.toBeNull();
  });

  // -- URL edge cases --

  test("URL with port is matched against hostname only", () => {
    const result = resolveRoute("https://example.com:8080/path", [
      rule({ hostPattern: "example.com" }),
    ]);
    expect(result).not.toBeNull();
  });

  test("URL with auth/userinfo is parsed correctly", () => {
    const result = resolveRoute("https://user:pass@example.com/path", [
      rule({ hostPattern: "example.com" }),
    ]);
    expect(result).not.toBeNull();
  });

  test("skips disabled rule and matches next enabled rule", () => {
    const result = resolveRoute("https://example.com", [
      rule({ id: "disabled", isEnabled: false, browserAppId: "com.google.Chrome" }),
      rule({ id: "enabled", isEnabled: true, browserAppId: "com.apple.Safari" }),
    ]);
    expect(result!.matchedRuleId).toBe("enabled");
  });

  test("returns null when all rules are disabled", () => {
    const result = resolveRoute("https://example.com", [
      rule({ isEnabled: false }),
      rule({ id: "r2", isEnabled: false }),
    ]);
    expect(result).toBeNull();
  });

  test("profile is undefined when not set on rule", () => {
    const result = resolveRoute("https://example.com", [rule()]);
    expect(result!.profile).toBeUndefined();
  });
});

// ===========================================================================
// recordDomainClick
// ===========================================================================

describe("recordDomainClick", () => {
  test("records a new domain click", () => {
    const result = recordDomainClick({}, "github.com", "com.google.Chrome");
    expect(result["github.com"]!["com.google.Chrome"]).toBe(1);
  });

  test("increments existing domain click", () => {
    const freq: DomainFrequency = {
      "github.com": { "com.google.Chrome": 5 },
    };
    const result = recordDomainClick(freq, "github.com", "com.google.Chrome");
    expect(result["github.com"]!["com.google.Chrome"]).toBe(6);
  });

  test("multiple apps on same domain", () => {
    let freq: DomainFrequency = {};
    freq = recordDomainClick(freq, "github.com", "com.google.Chrome");
    freq = recordDomainClick(freq, "github.com", "com.apple.Safari");
    expect(freq["github.com"]!["com.google.Chrome"]).toBe(1);
    expect(freq["github.com"]!["com.apple.Safari"]).toBe(1);
  });

  test("empty domain is ignored", () => {
    const result = recordDomainClick({}, "", "com.google.Chrome");
    expect(Object.keys(result)).toHaveLength(0);
  });

  test("empty appId is ignored", () => {
    const result = recordDomainClick({}, "github.com", "");
    expect(Object.keys(result)).toHaveLength(0);
  });

  test("trims and lowercases domain", () => {
    const result = recordDomainClick({}, "  GitHub.COM  ", "app");
    expect(result["github.com"]).toBeDefined();
    expect(result["github.com"]!["app"]).toBe(1);
  });

  test("trims appId", () => {
    const result = recordDomainClick({}, "example.com", "  com.app  ");
    expect(result["example.com"]!["com.app"]).toBe(1);
  });

  test("evicts oldest entry when over DOMAIN_MAX_ENTRIES", () => {
    const freq: DomainFrequency = {};
    // Fill to exactly the limit
    for (let i = 0; i < DOMAIN_MAX_ENTRIES; i++) {
      freq[`domain${String(i).padStart(4, "0")}.com`] = { app: 1 };
    }
    expect(Object.keys(freq)).toHaveLength(DOMAIN_MAX_ENTRIES);

    // Adding one more should evict
    const result = recordDomainClick(freq, "newdomain.com", "app");
    expect(Object.keys(result)).toHaveLength(DOMAIN_MAX_ENTRIES);
    expect(result["newdomain.com"]).toBeDefined();
  });

  test("returns new object (immutable)", () => {
    const original: DomainFrequency = {};
    const result = recordDomainClick(original, "test.com", "app");
    expect(result).not.toBe(original);
  });

  test("does not mutate input", () => {
    const original: DomainFrequency = {
      "github.com": { "com.google.Chrome": 3 },
    };
    const originalCopy = JSON.parse(JSON.stringify(original));
    recordDomainClick(original, "github.com", "com.google.Chrome");
    expect(original).toEqual(originalCopy);
  });

  test("whitespace-only domain is ignored", () => {
    const result = recordDomainClick({}, "   ", "app");
    expect(Object.keys(result)).toHaveLength(0);
  });

  test("whitespace-only appId is ignored", () => {
    const result = recordDomainClick({}, "test.com", "   ");
    expect(Object.keys(result)).toHaveLength(0);
  });
});

// ===========================================================================
// getSuggestions
// ===========================================================================

describe("getSuggestions", () => {
  test("returns empty for empty frequency", () => {
    expect(getSuggestions({})).toEqual([]);
  });

  test("returns items meeting threshold", () => {
    const freq: DomainFrequency = {
      "github.com": { "com.google.Chrome": DOMAIN_SUGGESTION_THRESHOLD },
    };
    const suggestions = getSuggestions(freq);
    expect(suggestions).toHaveLength(1);
    expect(suggestions[0]!.domain).toBe("github.com");
    expect(suggestions[0]!.count).toBe(DOMAIN_SUGGESTION_THRESHOLD);
  });

  test("does NOT return items below threshold", () => {
    const freq: DomainFrequency = {
      "github.com": { "com.google.Chrome": DOMAIN_SUGGESTION_THRESHOLD - 1 },
    };
    expect(getSuggestions(freq)).toHaveLength(0);
  });

  test("returns sorted by count descending", () => {
    const freq: DomainFrequency = {
      "a.com": { app: 50 },
      "b.com": { app: 100 },
      "c.com": { app: 75 },
    };
    const suggestions = getSuggestions(freq);
    expect(suggestions[0]!.count).toBe(100);
    expect(suggestions[1]!.count).toBe(75);
    expect(suggestions[2]!.count).toBe(50);
  });

  test("returns multiple suggestions from different domains", () => {
    const freq: DomainFrequency = {
      "github.com": { "com.google.Chrome": 40 },
      "gitlab.com": { "com.apple.Safari": 35 },
    };
    const suggestions = getSuggestions(freq);
    expect(suggestions).toHaveLength(2);
  });

  test("returns multiple suggestions from same domain with different apps", () => {
    const freq: DomainFrequency = {
      "github.com": { "com.google.Chrome": 40, "com.apple.Safari": 32 },
    };
    const suggestions = getSuggestions(freq);
    expect(suggestions).toHaveLength(2);
  });

  test("threshold parameter override", () => {
    const freq: DomainFrequency = {
      "github.com": { app: 5 },
    };
    expect(getSuggestions(freq, 10)).toHaveLength(0);
    expect(getSuggestions(freq, 5)).toHaveLength(1);
    expect(getSuggestions(freq, 3)).toHaveLength(1);
  });

  test("sorts by domain then appId when counts are equal", () => {
    const freq: DomainFrequency = {
      "b.com": { "app-z": 50 },
      "a.com": { "app-a": 50 },
    };
    const suggestions = getSuggestions(freq);
    expect(suggestions).toHaveLength(2);
    // Same count → alphabetical by domain
    expect(suggestions[0]!.domain).toBe("a.com");
    expect(suggestions[1]!.domain).toBe("b.com");
  });

  test("sorts by appId when domain and count are equal", () => {
    const freq: DomainFrequency = {
      "github.com": { "com.b": 50, "com.a": 50 },
    };
    const suggestions = getSuggestions(freq);
    expect(suggestions[0]!.appId).toBe("com.a");
    expect(suggestions[1]!.appId).toBe("com.b");
  });

  test("ignores entries where all apps are below threshold", () => {
    const freq: DomainFrequency = {
      "low.com": { "app1": 5, "app2": 10 },
    };
    expect(getSuggestions(freq)).toHaveLength(0);
  });

  test("only returns the app entries above threshold, not all", () => {
    const freq: DomainFrequency = {
      "github.com": { "above": 40, "below": 10 },
    };
    const suggestions = getSuggestions(freq);
    expect(suggestions).toHaveLength(1);
    expect(suggestions[0]!.appId).toBe("above");
  });
});

// ===========================================================================
// ruleDescription
// ===========================================================================

describe("ruleDescription", () => {
  test("basic rule with host only", () => {
    const desc = ruleDescription(rule({ hostPattern: "github.com" }));
    expect(desc).toBe("host: github.com");
  });

  test("rule with host and path", () => {
    const desc = ruleDescription(
      rule({ hostPattern: "github.com", pathPrefix: "/repos" })
    );
    expect(desc).toBe("host: github.com, path: /repos");
  });

  test("rule with host and source app", () => {
    const desc = ruleDescription(
      rule({ hostPattern: "github.com", sourceAppBundleId: "com.slack" })
    );
    expect(desc).toBe("host: github.com, from: com.slack");
  });

  test("rule with all fields", () => {
    const desc = ruleDescription(
      rule({
        hostPattern: "*.example.com",
        pathPrefix: "/api",
        sourceAppBundleId: "com.slack",
      })
    );
    expect(desc).toBe("host: *.example.com, path: /api, from: com.slack");
  });

  test("rule with wildcard host", () => {
    const desc = ruleDescription(rule({ hostPattern: "*" }));
    expect(desc).toBe("host: *");
  });

  test("rule with empty hostPattern", () => {
    const desc = ruleDescription(rule({ hostPattern: "" }));
    expect(desc).toBe("host: ");
  });

  test("rule with regex hostPattern", () => {
    const desc = ruleDescription(
      rule({ hostPattern: "github\\.com|gitlab\\.com", useRegex: true })
    );
    expect(desc).toContain("github\\.com|gitlab\\.com");
  });

  test("description does not include path when pathPrefix is undefined", () => {
    const desc = ruleDescription(rule({ pathPrefix: undefined }));
    expect(desc).not.toContain("path:");
  });

  test("description does not include 'from:' when sourceAppBundleId is undefined", () => {
    const desc = ruleDescription(rule({ sourceAppBundleId: undefined }));
    expect(desc).not.toContain("from:");
  });
});
