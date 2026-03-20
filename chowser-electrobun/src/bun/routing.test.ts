import { describe, expect, test } from "bun:test";
import { resolveRoute } from "./routing.ts";
import type { BrowserRoutingRule } from "./models.ts";

function rule(partial: Partial<BrowserRoutingRule>): BrowserRoutingRule {
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

describe("resolveRoute", () => {
  test("matches pathPrefix case-insensitively", () => {
    const route = resolveRoute("https://example.com/Work/docs", [
      rule({ pathPrefix: "/work" }),
    ]);
    expect(route?.browserAppId).toBe("com.apple.Safari");
  });

  test("regex requires full host match", () => {
    const full = resolveRoute("https://api.example.com", [
      rule({ useRegex: true, hostPattern: "api\\.example\\.com" }),
    ]);
    expect(full).not.toBeNull();

    const partial = resolveRoute("https://xapi.example.com", [
      rule({ useRegex: true, hostPattern: "api\\.example\\.com" }),
    ]);
    expect(partial).toBeNull();
  });

  test("matches source app when provided", () => {
    const route = resolveRoute(
      "https://example.com",
      [rule({ sourceAppBundleId: "com.tinyspeck.slackmacgap" })],
      "com.tinyspeck.slackmacgap"
    );
    expect(route).not.toBeNull();
  });
});
