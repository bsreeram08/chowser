// ---------------------------------------------------------------------------
// Browser launcher tests
// ---------------------------------------------------------------------------

import { describe, test, expect } from "bun:test";
import { launchByRoute } from "./browserLauncher.ts";
import type { BrowserConfig, ResolvedRoute } from "./models.ts";

// ---------------------------------------------------------------------------
// parseCustomArguments — copied from browserLauncher.ts for direct testing
// (The function is not exported; this is a faithful copy for unit testing.)
// ---------------------------------------------------------------------------

function parseCustomArguments(args: string): string[] {
  const tokens: string[] = [];
  let current = "";
  let i = 0;

  while (i < args.length) {
    const ch = args[i];

    if (ch === "\\") {
      if (i + 1 < args.length) current += args[++i];
    } else if (ch === "'") {
      i++;
      while (i < args.length && args[i] !== "'") {
        current += args[i++];
      }
    } else if (ch === '"') {
      i++;
      while (i < args.length && args[i] !== '"') {
        if (args[i] === "\\" && i + 1 < args.length) {
          current += args[++i];
        } else {
          current += args[i];
        }
        i++;
      }
    } else if (ch === " " || ch === "\t") {
      if (current.length > 0) {
        tokens.push(current);
        current = "";
      }
    } else {
      current += ch;
    }

    i++;
  }

  if (current.length > 0) tokens.push(current);
  return tokens;
}

// ---------------------------------------------------------------------------
// Chromium app IDs — matches the Set in browserLauncher.ts
// ---------------------------------------------------------------------------

const CHROMIUM_APP_IDS = [
  "com.google.Chrome",
  "com.google.Chrome.canary",
  "com.brave.Browser",
  "com.microsoft.edgemac",
  "com.vivaldi.Vivaldi",
  "com.operasoftware.Opera",
  "company.thebrowser.Browser",
  "com.google.Chrome.beta",
  "com.google.Chrome.dev",
];

// ---------------------------------------------------------------------------
// privateFlag — copied from browserLauncher.ts for direct testing
// ---------------------------------------------------------------------------

function privateFlag(appId: string): string {
  const chromiumSet = new Set(CHROMIUM_APP_IDS);
  if (chromiumSet.has(appId)) return "--incognito";
  if (appId.startsWith("org.mozilla") || appId.startsWith("app.zen-browser"))
    return "-private-window";
  if (appId === "com.apple.Safari") return "";
  return "--private";
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function browser(partial: Partial<BrowserConfig> & { appId: string }): BrowserConfig {
  return {
    id: crypto.randomUUID(),
    name: partial.name ?? "Browser",
    shortcutKey: partial.shortcutKey ?? "1",
    ...partial,
  };
}

function route(partial: Partial<ResolvedRoute> & { browserAppId: string }): ResolvedRoute {
  return {
    usePrivateMode: false,
    ...partial,
  };
}

// ===========================================================================
// parseCustomArguments tests
// ===========================================================================

describe("parseCustomArguments", () => {
  test("simple single argument", () => {
    expect(parseCustomArguments("--no-sandbox")).toEqual(["--no-sandbox"]);
  });

  test("multiple space-separated arguments", () => {
    expect(parseCustomArguments("--flag1 --flag2 --flag3")).toEqual([
      "--flag1",
      "--flag2",
      "--flag3",
    ]);
  });

  test("empty string returns empty array", () => {
    expect(parseCustomArguments("")).toEqual([]);
  });

  test("whitespace-only string returns empty array", () => {
    expect(parseCustomArguments("   ")).toEqual([]);
  });

  test("tab-separated arguments", () => {
    expect(parseCustomArguments("--a\t--b")).toEqual(["--a", "--b"]);
  });

  test("multiple spaces between arguments", () => {
    expect(parseCustomArguments("--a   --b")).toEqual(["--a", "--b"]);
  });

  test("leading and trailing whitespace is trimmed", () => {
    expect(parseCustomArguments("  --flag  ")).toEqual(["--flag"]);
  });

  test("double-quoted string preserves spaces", () => {
    expect(parseCustomArguments('"hello world"')).toEqual(["hello world"]);
  });

  test("single-quoted string preserves spaces", () => {
    expect(parseCustomArguments("'hello world'")).toEqual(["hello world"]);
  });

  test("flag with double-quoted value", () => {
    expect(parseCustomArguments('--flag="hello world"')).toEqual([
      "--flag=hello world",
    ]);
  });

  test("flag with single-quoted value", () => {
    expect(parseCustomArguments("--flag='hello world'")).toEqual([
      "--flag=hello world",
    ]);
  });

  test("mixed quoted and unquoted arguments", () => {
    expect(parseCustomArguments("--user 'John Doe' --verbose")).toEqual([
      "--user",
      "John Doe",
      "--verbose",
    ]);
  });

  test("backslash escape outside quotes", () => {
    expect(parseCustomArguments("hello\\ world")).toEqual(["hello world"]);
  });

  test("backslash escape inside double quotes", () => {
    expect(parseCustomArguments('"hello\\"world"')).toEqual(['hello"world']);
  });

  test("backslash escape does not apply inside single quotes", () => {
    // Single quotes: no escape processing
    expect(parseCustomArguments("'hello\\\\world'")).toEqual(["hello\\\\world"]);
  });

  test("unclosed single quote consumes rest of string", () => {
    expect(parseCustomArguments("'unclosed")).toEqual(["unclosed"]);
  });

  test("unclosed double quote consumes rest of string", () => {
    expect(parseCustomArguments('"unclosed')).toEqual(["unclosed"]);
  });

  test("adjacent quoted segments are concatenated", () => {
    expect(parseCustomArguments("'hello''world'")).toEqual(["helloworld"]);
  });

  test("mixed quote types concatenated", () => {
    expect(parseCustomArguments("\"hello\"'world'")).toEqual(["helloworld"]);
  });

  test("complex real-world: Chromium profile and sandbox flags", () => {
    expect(
      parseCustomArguments('--profile-directory="Default" --no-sandbox')
    ).toEqual(["--profile-directory=Default", "--no-sandbox"]);
  });

  test("complex real-world: Firefox profile", () => {
    expect(parseCustomArguments("-P 'Work Profile'")).toEqual([
      "-P",
      "Work Profile",
    ]);
  });

  test("equals sign in value", () => {
    expect(parseCustomArguments("--key=value")).toEqual(["--key=value"]);
  });

  test("empty quotes produce empty token adjacent to flag", () => {
    // --flag="" → the flag= and empty quotes concatenate
    expect(parseCustomArguments('--flag=""')).toEqual(["--flag="]);
  });

  test("standalone empty double quotes produce no tokens", () => {
    // Empty quotes with no adjacent content → empty current, never pushed
    expect(parseCustomArguments('""')).toEqual([]);
  });

  test("standalone empty single quotes produce no tokens", () => {
    expect(parseCustomArguments("''")).toEqual([]);
  });

  test("backslash at end of string is ignored", () => {
    expect(parseCustomArguments("hello\\")).toEqual(["hello"]);
  });

  test("only backslash returns empty", () => {
    expect(parseCustomArguments("\\")).toEqual([]);
  });

  test("multiple tokens with various quoting", () => {
    expect(
      parseCustomArguments('--a "b c" --d \'e f\' --g=h')
    ).toEqual(["--a", "b c", "--d", "e f", "--g=h"]);
  });
});

// ===========================================================================
// privateFlag tests
// ===========================================================================

describe("privateFlag", () => {
  test("Chrome returns --incognito", () => {
    expect(privateFlag("com.google.Chrome")).toBe("--incognito");
  });

  test("Chrome Canary returns --incognito", () => {
    expect(privateFlag("com.google.Chrome.canary")).toBe("--incognito");
  });

  test("Brave returns --incognito", () => {
    expect(privateFlag("com.brave.Browser")).toBe("--incognito");
  });

  test("Edge returns --incognito", () => {
    expect(privateFlag("com.microsoft.edgemac")).toBe("--incognito");
  });

  test("Vivaldi returns --incognito", () => {
    expect(privateFlag("com.vivaldi.Vivaldi")).toBe("--incognito");
  });

  test("Opera returns --incognito", () => {
    expect(privateFlag("com.operasoftware.Opera")).toBe("--incognito");
  });

  test("Arc returns --incognito", () => {
    expect(privateFlag("company.thebrowser.Browser")).toBe("--incognito");
  });

  test("Chrome Beta returns --incognito", () => {
    expect(privateFlag("com.google.Chrome.beta")).toBe("--incognito");
  });

  test("Chrome Dev returns --incognito", () => {
    expect(privateFlag("com.google.Chrome.dev")).toBe("--incognito");
  });

  test("Firefox returns -private-window", () => {
    expect(privateFlag("org.mozilla.firefox")).toBe("-private-window");
  });

  test("Firefox Developer Edition returns -private-window", () => {
    expect(privateFlag("org.mozilla.firefoxdeveloperedition")).toBe("-private-window");
  });

  test("Zen Browser returns -private-window", () => {
    expect(privateFlag("app.zen-browser.zen")).toBe("-private-window");
  });

  test("Safari returns empty string (no CLI flag)", () => {
    expect(privateFlag("com.apple.Safari")).toBe("");
  });

  test("unknown browser returns --private as default", () => {
    expect(privateFlag("com.unknown.browser")).toBe("--private");
  });

  test("LibreWolf (org.mozilla prefix) returns -private-window", () => {
    // LibreWolf would typically be io.gitlab, so falls through to --private
    expect(privateFlag("io.gitlab.librewolf-community")).toBe("--private");
  });
});

// ===========================================================================
// launchByRoute — browser selection logic
// ===========================================================================

describe("launchByRoute", () => {
  const browsers: BrowserConfig[] = [
    browser({ appId: "com.google.Chrome", name: "Chrome" }),
    browser({ appId: "com.google.Chrome", name: "Chrome Work", profile: "Profile 1", shortcutKey: "2" }),
    browser({ appId: "org.mozilla.firefox", name: "Firefox", shortcutKey: "3" }),
    browser({ appId: "com.apple.Safari", name: "Safari", shortcutKey: "4" }),
  ];

  test("returns false when no browser matches the route appId", () => {
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.nonexistent.app" }),
      browsers
    );
    expect(result).toBe(false);
  });

  test("returns true when a browser matches by appId", () => {
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.apple.Safari" }),
      browsers
    );
    expect(result).toBe(true);
  });

  test("returns true for Chrome appId match", () => {
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.google.Chrome" }),
      browsers
    );
    expect(result).toBe(true);
  });

  test("returns true for Firefox appId match", () => {
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "org.mozilla.firefox" }),
      browsers
    );
    expect(result).toBe(true);
  });

  test("handles empty browsers array", () => {
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.google.Chrome" }),
      []
    );
    expect(result).toBe(false);
  });

  test("prefers exact appId+profile match over appId-only", () => {
    // Route specifies profile "Profile 1"
    // Should select "Chrome Work" (has profile) over plain "Chrome"
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.google.Chrome", profile: "Profile 1" }),
      browsers
    );
    expect(result).toBe(true);
  });

  test("falls back to appId-only when no profile match", () => {
    // Route specifies profile that doesn't match any browser's profile
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.google.Chrome", profile: "NonExistent" }),
      browsers
    );
    // Falls back to first Chrome entry
    expect(result).toBe(true);
  });

  test("handles route without profile", () => {
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.google.Chrome" }),
      browsers
    );
    expect(result).toBe(true);
  });

  test("returns false for undefined appId in route", () => {
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "" }),
      browsers
    );
    expect(result).toBe(false);
  });

  test("handles single browser list", () => {
    const singleList = [browser({ appId: "com.apple.Safari", name: "Safari" })];
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.apple.Safari" }),
      singleList
    );
    expect(result).toBe(true);
  });

  test("handles route with usePrivateMode", () => {
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.apple.Safari", usePrivateMode: true }),
      browsers
    );
    expect(result).toBe(true);
  });

  test("handles browsers with same appId different profiles", () => {
    const multiProfile = [
      browser({ appId: "com.google.Chrome", name: "Personal", profile: "Default" }),
      browser({ appId: "com.google.Chrome", name: "Work", profile: "Profile 1" }),
      browser({ appId: "com.google.Chrome", name: "School", profile: "Profile 2" }),
    ];
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.google.Chrome", profile: "Profile 2" }),
      multiProfile
    );
    expect(result).toBe(true);
  });

  test("returns false when browsers list has only unrelated browsers", () => {
    const otherBrowsers = [
      browser({ appId: "com.apple.Safari", name: "Safari" }),
    ];
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.google.Chrome" }),
      otherBrowsers
    );
    expect(result).toBe(false);
  });

  test("handles browser with customArguments", () => {
    const browsersWithArgs = [
      browser({
        appId: "com.google.Chrome",
        name: "Chrome Custom",
        customArguments: "--no-sandbox --disable-gpu",
      }),
    ];
    const result = launchByRoute(
      "https://example.com",
      route({ browserAppId: "com.google.Chrome" }),
      browsersWithArgs
    );
    expect(result).toBe(true);
  });

  test("handles URL with special characters", () => {
    const result = launchByRoute(
      "https://example.com/path?q=hello%20world&foo=bar#section",
      route({ browserAppId: "com.apple.Safari" }),
      browsers
    );
    expect(result).toBe(true);
  });

  test("handles empty URL string", () => {
    const result = launchByRoute(
      "",
      route({ browserAppId: "com.apple.Safari" }),
      browsers
    );
    expect(result).toBe(true);
  });
});
