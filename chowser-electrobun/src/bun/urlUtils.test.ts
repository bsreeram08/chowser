import { describe, expect, test, mock, beforeEach, afterEach } from "bun:test";
import { cleanUrl, isHttpUrl, unshortenUrl } from "./urlUtils.ts";

// ---------------------------------------------------------------------------
// cleanUrl
// ---------------------------------------------------------------------------

describe("cleanUrl", () => {
  // -- UTM parameters --
  test("removes utm_source", () => {
    expect(cleanUrl("https://example.com?utm_source=twitter")).toBe("https://example.com/");
  });

  test("removes utm_medium", () => {
    expect(cleanUrl("https://example.com?utm_medium=social")).toBe("https://example.com/");
  });

  test("removes utm_campaign", () => {
    expect(cleanUrl("https://example.com?utm_campaign=spring")).toBe("https://example.com/");
  });

  test("removes utm_term", () => {
    expect(cleanUrl("https://example.com?utm_term=shoes")).toBe("https://example.com/");
  });

  test("removes utm_content", () => {
    expect(cleanUrl("https://example.com?utm_content=banner")).toBe("https://example.com/");
  });

  test("removes utm_id", () => {
    expect(cleanUrl("https://example.com?utm_id=abc123")).toBe("https://example.com/");
  });

  test("removes multiple utm params in single pass", () => {
    const url = "https://example.com/page?utm_source=x&utm_medium=y&utm_campaign=z";
    expect(cleanUrl(url)).toBe("https://example.com/page");
  });

  // -- Social/ad platform trackers --
  test("removes fbclid", () => {
    expect(cleanUrl("https://example.com?fbclid=abc")).toBe("https://example.com/");
  });

  test("removes gclid", () => {
    expect(cleanUrl("https://example.com?gclid=abc")).toBe("https://example.com/");
  });

  test("removes msclkid", () => {
    expect(cleanUrl("https://example.com?msclkid=abc")).toBe("https://example.com/");
  });

  test("removes twclid", () => {
    expect(cleanUrl("https://example.com?twclid=abc")).toBe("https://example.com/");
  });

  test("removes yclid", () => {
    expect(cleanUrl("https://example.com?yclid=abc")).toBe("https://example.com/");
  });

  test("removes igshid", () => {
    expect(cleanUrl("https://example.com?igshid=abc")).toBe("https://example.com/");
  });

  // -- Marketing/email trackers --
  test("removes _hsenc", () => {
    expect(cleanUrl("https://example.com?_hsenc=abc")).toBe("https://example.com/");
  });

  test("removes _hsmi", () => {
    expect(cleanUrl("https://example.com?_hsmi=abc")).toBe("https://example.com/");
  });

  test("removes hsCtaTracking", () => {
    expect(cleanUrl("https://example.com?hsCtaTracking=abc")).toBe("https://example.com/");
  });

  test("removes mc_cid", () => {
    expect(cleanUrl("https://example.com?mc_cid=abc")).toBe("https://example.com/");
  });

  test("removes mc_eid", () => {
    expect(cleanUrl("https://example.com?mc_eid=abc")).toBe("https://example.com/");
  });

  test("removes mkt_tok", () => {
    expect(cleanUrl("https://example.com?mkt_tok=abc")).toBe("https://example.com/");
  });

  // -- Preserving non-tracking params --
  test("preserves non-tracking params like q and page", () => {
    const url = "https://example.com/search?q=test&page=2";
    expect(cleanUrl(url)).toBe(url);
  });

  test("removes tracking but preserves non-tracking params", () => {
    const url = "https://example.com/search?q=test&utm_source=google&page=2";
    const cleaned = cleanUrl(url);
    expect(cleaned).toContain("q=test");
    expect(cleaned).toContain("page=2");
    expect(cleaned).not.toContain("utm_source");
  });

  test("returns original URL when no tracking params present", () => {
    const url = "https://example.com/path?key=value";
    expect(cleanUrl(url)).toBe(url);
  });

  // -- Edge cases --
  test("returns original URL for invalid URL", () => {
    const url = "not-a-url";
    expect(cleanUrl(url)).toBe(url);
  });

  test("handles URL with only tracking params (removes trailing ?)", () => {
    const result = cleanUrl("https://example.com/?utm_source=twitter");
    expect(result).not.toContain("utm_source");
    expect(result).not.toEndWith("?");
  });

  test("handles URL with fragment correctly", () => {
    const url = "https://example.com/page?utm_source=fb#section";
    const cleaned = cleanUrl(url);
    expect(cleaned).toContain("#section");
    expect(cleaned).not.toContain("utm_source");
  });

  test("handles URL with no query string", () => {
    const url = "https://example.com/path";
    expect(cleanUrl(url)).toBe(url);
  });

  test("handles empty string", () => {
    expect(cleanUrl("")).toBe("");
  });

  test("handles URL with special characters in non-tracking params", () => {
    const url = "https://example.com/search?q=hello+world%21&utm_source=x";
    const cleaned = cleanUrl(url);
    expect(cleaned).not.toContain("utm_source");
    expect(cleaned).toContain("q=hello");
  });

  test("handles URL with encoded tracking param values", () => {
    const url = "https://example.com?utm_source=my%20campaign";
    expect(cleanUrl(url)).toBe("https://example.com/");
  });

  test("removes ref tracking param", () => {
    expect(cleanUrl("https://example.com?ref=homepage")).toBe("https://example.com/");
  });

  test("removes si tracking param", () => {
    expect(cleanUrl("https://example.com?si=abc")).toBe("https://example.com/");
  });

  test("preserves path when removing query params", () => {
    const url = "https://example.com/a/b/c?utm_source=x";
    expect(cleanUrl(url)).toBe("https://example.com/a/b/c");
  });

  test("handles URL with port and tracking params", () => {
    const url = "https://example.com:8080/path?utm_source=x&id=5";
    const cleaned = cleanUrl(url);
    expect(cleaned).toContain(":8080");
    expect(cleaned).toContain("id=5");
    expect(cleaned).not.toContain("utm_source");
  });

  test("handles URL with username:password and tracking params", () => {
    const url = "https://user:pass@example.com/path?fbclid=abc";
    const cleaned = cleanUrl(url);
    expect(cleaned).not.toContain("fbclid");
  });

  test("does not remove params that are substrings of tracking params", () => {
    // "source" is not in the tracking list (utm_source is)
    const url = "https://example.com?source=internal";
    expect(cleanUrl(url)).toBe(url);
  });
});

// ---------------------------------------------------------------------------
// isHttpUrl
// ---------------------------------------------------------------------------

describe("isHttpUrl", () => {
  test("returns true for http://example.com", () => {
    expect(isHttpUrl("http://example.com")).toBe(true);
  });

  test("returns true for https://example.com", () => {
    expect(isHttpUrl("https://example.com")).toBe(true);
  });

  test("returns true for https://example.com/path?q=1#frag", () => {
    expect(isHttpUrl("https://example.com/path?q=1#frag")).toBe(true);
  });

  test("returns false for ftp://example.com", () => {
    expect(isHttpUrl("ftp://example.com")).toBe(false);
  });

  test("returns false for javascript:void(0)", () => {
    expect(isHttpUrl("javascript:void(0)")).toBe(false);
  });

  test("returns false for data:text/html,hello", () => {
    expect(isHttpUrl("data:text/html,hello")).toBe(false);
  });

  test("returns false for mailto:test@test.com", () => {
    expect(isHttpUrl("mailto:test@test.com")).toBe(false);
  });

  test("returns false for file:///Users/test", () => {
    expect(isHttpUrl("file:///Users/test")).toBe(false);
  });

  test("returns false for empty string", () => {
    expect(isHttpUrl("")).toBe(false);
  });

  test("returns false for 'not a url'", () => {
    expect(isHttpUrl("not a url")).toBe(false);
  });

  test("returns false for '://missing-protocol'", () => {
    expect(isHttpUrl("://missing-protocol")).toBe(false);
  });

  test("returns true for http://localhost:3000", () => {
    expect(isHttpUrl("http://localhost:3000")).toBe(true);
  });

  test("returns true for https://192.168.1.1", () => {
    expect(isHttpUrl("https://192.168.1.1")).toBe(true);
  });

  test("returns true for http://example.com:8080/path", () => {
    expect(isHttpUrl("http://example.com:8080/path")).toBe(true);
  });

  test("returns true for HTTP:// (case-insensitive protocol)", () => {
    expect(isHttpUrl("HTTP://example.com")).toBe(true);
  });

  test("returns true for HTTPS:// (case-insensitive protocol)", () => {
    expect(isHttpUrl("HTTPS://EXAMPLE.COM")).toBe(true);
  });

  test("returns false for 'http' without colon-slash-slash", () => {
    expect(isHttpUrl("http")).toBe(false);
  });

  test("returns true for URL with auth info", () => {
    expect(isHttpUrl("https://user:pass@example.com")).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// unshortenUrl
// ---------------------------------------------------------------------------

describe("unshortenUrl", () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  test("returns original URL when no redirect (200 response)", async () => {
    globalThis.fetch = (async () => {
      return new Response(null, { status: 200 });
    }) as unknown as typeof fetch;

    const result = await unshortenUrl("https://example.com/page");
    expect(result).toBe("https://example.com/page");
  });

  test("follows a single redirect", async () => {
    let callCount = 0;
    globalThis.fetch = (async (input: RequestInfo | URL) => {
      callCount++;
      if (callCount === 1) {
        return new Response(null, {
          status: 301,
          headers: { location: "https://destination.com/final" },
        });
      }
      return new Response(null, { status: 200 });
    }) as unknown as typeof fetch;

    const result = await unshortenUrl("https://t.co/abc");
    expect(result).toBe("https://destination.com/final");
  });

  test("follows multiple redirects", async () => {
    let callCount = 0;
    globalThis.fetch = (async () => {
      callCount++;
      if (callCount === 1) {
        return new Response(null, {
          status: 302,
          headers: { location: "https://mid.com/step" },
        });
      }
      if (callCount === 2) {
        return new Response(null, {
          status: 301,
          headers: { location: "https://final.com/done" },
        });
      }
      return new Response(null, { status: 200 });
    }) as unknown as typeof fetch;

    const result = await unshortenUrl("https://bit.ly/xyz");
    expect(result).toBe("https://final.com/done");
  });

  test("stops following when maxRedirects is reached", async () => {
    globalThis.fetch = (async (_input: RequestInfo | URL) => {
      return new Response(null, {
        status: 301,
        headers: { location: "https://loop.com/next" },
      });
    }) as unknown as typeof fetch;

    const result = await unshortenUrl("https://bit.ly/loop", 2);
    expect(result).toBe("https://loop.com/next");
  });

  test("returns original URL when fetch throws", async () => {
    globalThis.fetch = (async () => {
      throw new Error("Network error");
    }) as unknown as typeof fetch;

    const result = await unshortenUrl("https://broken.com/link");
    expect(result).toBe("https://broken.com/link");
  });

  test("resolves relative redirect locations", async () => {
    let callCount = 0;
    globalThis.fetch = (async () => {
      callCount++;
      if (callCount === 1) {
        return new Response(null, {
          status: 302,
          headers: { location: "/resolved-path" },
        });
      }
      return new Response(null, { status: 200 });
    }) as unknown as typeof fetch;

    const result = await unshortenUrl("https://example.com/short");
    expect(result).toBe("https://example.com/resolved-path");
  });
});
