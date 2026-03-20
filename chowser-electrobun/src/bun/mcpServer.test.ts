// ---------------------------------------------------------------------------
// MCP Server tests — exercises the HTTP REST API on localhost
// ---------------------------------------------------------------------------

import { describe, test, expect, beforeAll, afterAll, beforeEach } from "bun:test";
import {
  startMcpServer,
  stopMcpServer,
  getMcpStatus,
  MCP_PORT,
} from "./mcpServer.ts";
import type {
  PersistedState,
  BrowserConfig,
  BrowserRoutingRule,
} from "./models.ts";
import { createDefaultState } from "./models.ts";

// ---------------------------------------------------------------------------
// Mock state
// ---------------------------------------------------------------------------

let state: PersistedState;
const getState = () => state;
const patchState = (patch: Partial<PersistedState>) => {
  state = { ...state, ...patch };
};

const BASE = `http://127.0.0.1:${MCP_PORT}`;

function resetState() {
  state = createDefaultState();
  state.configuredBrowsers = [];
  state.routingRules = [];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let token: string;

function authHeaders(): Record<string, string> {
  return { "X-Chowser-Token": token, "Content-Type": "application/json" };
}

function jsonHeaders(): Record<string, string> {
  return { "Content-Type": "application/json" };
}

async function post(path: string, body: unknown, headers?: Record<string, string>) {
  return fetch(`${BASE}${path}`, {
    method: "POST",
    headers: headers ?? authHeaders(),
    body: JSON.stringify(body),
  });
}

async function del(path: string, headers?: Record<string, string>) {
  return fetch(`${BASE}${path}`, {
    method: "DELETE",
    headers: headers ?? authHeaders(),
  });
}

async function get(path: string) {
  return fetch(`${BASE}${path}`);
}

// ---------------------------------------------------------------------------
// Pre-start tests (server not running)
// ---------------------------------------------------------------------------

describe("MCP Server — pre-start", () => {
  test("getMcpStatus returns not running before start", () => {
    const status = getMcpStatus();
    expect(status.running).toBe(false);
  });

  test("getMcpStatus has port set even when not running", () => {
    const status = getMcpStatus();
    expect(status.port).toBe(MCP_PORT);
  });

  test("getMcpStatus token is null before start", () => {
    const status = getMcpStatus();
    expect(status.token).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Running server tests
// ---------------------------------------------------------------------------

describe("MCP Server — running", () => {
  beforeAll(async () => {
    resetState();
    const status = startMcpServer(getState, patchState);
    token = status.token!;
    // Wait for server to be listening
    await new Promise((r) => setTimeout(r, 100));
  });

  afterAll(() => {
    stopMcpServer();
  });

  beforeEach(() => {
    resetState();
  });

  // -----------------------------------------------------------------------
  // Server lifecycle
  // -----------------------------------------------------------------------

  describe("lifecycle", () => {
    test("startMcpServer returns status with running=true", () => {
      const status = getMcpStatus();
      expect(status.running).toBe(true);
    });

    test("startMcpServer returns a token", () => {
      expect(token).toBeTruthy();
      expect(typeof token).toBe("string");
    });

    test("getMcpStatus returns running after start", () => {
      const status = getMcpStatus();
      expect(status.running).toBe(true);
      expect(status.port).toBe(MCP_PORT);
      expect(status.token).toBe(token);
    });

    test("multiple start calls don't create duplicate servers", () => {
      // Should return same status without error
      const status = startMcpServer(getState, patchState);
      expect(status.running).toBe(true);
      expect(status.token).toBe(token); // same token, not regenerated
    });
  });

  // -----------------------------------------------------------------------
  // GET /status
  // -----------------------------------------------------------------------

  describe("GET /status", () => {
    test("returns 200", async () => {
      const res = await get("/status");
      expect(res.status).toBe(200);
    });

    test("contains name field", async () => {
      const res = await get("/status");
      const data = await res.json();
      expect(data.name).toBe("Chowser");
    });

    test("contains version field", async () => {
      const res = await get("/status");
      const data = await res.json();
      expect(data.version).toBe("0.1.0");
    });

    test("contains mcp flag", async () => {
      const res = await get("/status");
      const data = await res.json();
      expect(data.mcp).toBe(true);
    });

    test("contains endpoints list", async () => {
      const res = await get("/status");
      const data = await res.json();
      expect(Array.isArray(data.endpoints)).toBe(true);
      expect(data.endpoints.length).toBeGreaterThan(0);
    });

    test("endpoints include browser routes", async () => {
      const res = await get("/status");
      const data = await res.json();
      const joined = data.endpoints.join(" ");
      expect(joined).toContain("/browsers");
    });

    test("endpoints include rule routes", async () => {
      const res = await get("/status");
      const data = await res.json();
      const joined = data.endpoints.join(" ");
      expect(joined).toContain("/rules");
    });

    test("contains auth info", async () => {
      const res = await get("/status");
      const data = await res.json();
      expect(data.auth).toBeTruthy();
    });

    test("does not require authentication", async () => {
      const res = await get("/status");
      expect(res.status).toBe(200);
    });
  });

  // -----------------------------------------------------------------------
  // GET /browsers
  // -----------------------------------------------------------------------

  describe("GET /browsers", () => {
    test("returns 200", async () => {
      const res = await get("/browsers");
      expect(res.status).toBe(200);
    });

    test("returns empty array when no browsers configured", async () => {
      const res = await get("/browsers");
      const data = await res.json();
      expect(data.browsers).toEqual([]);
    });

    test("returns configured browsers", async () => {
      state.configuredBrowsers = [
        { id: "b1", name: "Safari", appId: "com.apple.Safari", shortcutKey: "1" },
      ];
      const res = await get("/browsers");
      const data = await res.json();
      expect(data.browsers).toHaveLength(1);
      expect(data.browsers[0].name).toBe("Safari");
    });

    test("does not require authentication", async () => {
      const res = await get("/browsers");
      expect(res.status).toBe(200);
    });

    test("returns browsers with all fields", async () => {
      state.configuredBrowsers = [
        { id: "b2", name: "Chrome", appId: "com.google.Chrome", shortcutKey: "2", profile: "Default" },
      ];
      const res = await get("/browsers");
      const data = await res.json();
      expect(data.browsers[0].profile).toBe("Default");
      expect(data.browsers[0].appId).toBe("com.google.Chrome");
    });
  });

  // -----------------------------------------------------------------------
  // POST /browsers
  // -----------------------------------------------------------------------

  describe("POST /browsers", () => {
    test("without auth returns 401", async () => {
      const res = await post("/browsers", { name: "X", appId: "com.x" }, jsonHeaders());
      expect(res.status).toBe(401);
    });

    test("with wrong token returns 401", async () => {
      const res = await post("/browsers", { name: "X", appId: "com.x" }, {
        "X-Chowser-Token": "wrong-token",
        "Content-Type": "application/json",
      });
      expect(res.status).toBe(401);
    });

    test("with valid auth adds a browser", async () => {
      const res = await post("/browsers", { name: "Chrome", appId: "com.google.Chrome" });
      expect(res.status).toBe(201);
      const data = await res.json();
      expect(data.browser.name).toBe("Chrome");
      expect(data.browser.appId).toBe("com.google.Chrome");
      expect(data.browser.id).toBeTruthy();
    });

    test("requires name field", async () => {
      const res = await post("/browsers", { appId: "com.x" });
      expect(res.status).toBe(400);
      const data = await res.json();
      expect(data.error).toContain("name");
    });

    test("requires appId field", async () => {
      const res = await post("/browsers", { name: "X" });
      expect(res.status).toBe(400);
      const data = await res.json();
      expect(data.error).toContain("appId");
    });

    test("updates existing browser with same appId + profile", async () => {
      state.configuredBrowsers = [
        { id: "existing-1", name: "Chrome", appId: "com.google.Chrome", shortcutKey: "1" },
      ];
      const res = await post("/browsers", {
        name: "Chrome Updated",
        appId: "com.google.Chrome",
      });
      expect(res.status).toBe(200);
      const data = await res.json();
      expect(data.browser.name).toBe("Chrome Updated");
      expect(data.browser.id).toBe("existing-1"); // ID preserved
    });

    test("creates new browser when appId differs", async () => {
      state.configuredBrowsers = [
        { id: "existing-1", name: "Chrome", appId: "com.google.Chrome", shortcutKey: "1" },
      ];
      const res = await post("/browsers", {
        name: "Firefox",
        appId: "org.mozilla.firefox",
      });
      expect(res.status).toBe(201);
      expect(state.configuredBrowsers).toHaveLength(2);
    });

    test("with profile creates distinct entry from profileless same appId", async () => {
      state.configuredBrowsers = [
        { id: "existing-1", name: "Chrome", appId: "com.google.Chrome", shortcutKey: "1" },
      ];
      const res = await post("/browsers", {
        name: "Chrome Work",
        appId: "com.google.Chrome",
        profile: "Profile 1",
      });
      expect(res.status).toBe(201);
      expect(state.configuredBrowsers).toHaveLength(2);
    });

    test("updates existing browser matched by appId + profile", async () => {
      state.configuredBrowsers = [
        { id: "p1", name: "Chrome Work", appId: "com.google.Chrome", shortcutKey: "2", profile: "Profile 1" },
      ];
      const res = await post("/browsers", {
        name: "Chrome Work Updated",
        appId: "com.google.Chrome",
        profile: "Profile 1",
      });
      expect(res.status).toBe(200);
      const data = await res.json();
      expect(data.browser.name).toBe("Chrome Work Updated");
      expect(data.browser.id).toBe("p1");
    });

    test("assigns default shortcutKey '9' when not provided", async () => {
      const res = await post("/browsers", { name: "X", appId: "com.x" });
      const data = await res.json();
      expect(data.browser.shortcutKey).toBe("9");
    });

    test("uses provided shortcutKey", async () => {
      const res = await post("/browsers", { name: "X", appId: "com.x", shortcutKey: "3" });
      const data = await res.json();
      expect(data.browser.shortcutKey).toBe("3");
    });

    test("preserves customArguments on create", async () => {
      const res = await post("/browsers", {
        name: "X",
        appId: "com.x",
        customArguments: "--no-sandbox",
      });
      const data = await res.json();
      expect(data.browser.customArguments).toBe("--no-sandbox");
    });

    test("new browser gets a UUID id", async () => {
      const res = await post("/browsers", { name: "X", appId: "com.x" });
      const data = await res.json();
      // UUID v4 format
      expect(data.browser.id).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
      );
    });
  });

  // -----------------------------------------------------------------------
  // DELETE /browsers
  // -----------------------------------------------------------------------

  describe("DELETE /browsers", () => {
    test("without auth returns 401", async () => {
      const res = await fetch(`${BASE}/browsers?id=abc`, { method: "DELETE" });
      expect(res.status).toBe(401);
    });

    test("without id param returns 400", async () => {
      const res = await del("/browsers", authHeaders());
      expect(res.status).toBe(400);
    });

    test("with nonexistent id returns 404", async () => {
      const res = await del("/browsers?id=nonexistent", authHeaders());
      expect(res.status).toBe(404);
    });

    test("removes browser successfully", async () => {
      state.configuredBrowsers = [
        { id: "del-me", name: "Del", appId: "com.del", shortcutKey: "1" },
      ];
      const res = await del("/browsers?id=del-me", authHeaders());
      expect(res.status).toBe(200);
      const data = await res.json();
      expect(data.success).toBe(true);
      expect(state.configuredBrowsers).toHaveLength(0);
    });

    test("only removes the targeted browser", async () => {
      state.configuredBrowsers = [
        { id: "keep", name: "Keep", appId: "com.keep", shortcutKey: "1" },
        { id: "del-me", name: "Del", appId: "com.del", shortcutKey: "2" },
      ];
      await del("/browsers?id=del-me", authHeaders());
      expect(state.configuredBrowsers).toHaveLength(1);
      expect(state.configuredBrowsers[0].id).toBe("keep");
    });
  });

  // -----------------------------------------------------------------------
  // GET /rules
  // -----------------------------------------------------------------------

  describe("GET /rules", () => {
    test("returns 200", async () => {
      const res = await get("/rules");
      expect(res.status).toBe(200);
    });

    test("returns empty array when no rules", async () => {
      const res = await get("/rules");
      const data = await res.json();
      expect(data.rules).toEqual([]);
    });

    test("returns configured rules", async () => {
      state.routingRules = [
        {
          id: "r1",
          name: "GitHub",
          hostPattern: "github.com",
          browserAppId: "com.google.Chrome",
          isEnabled: true,
          usePrivateMode: false,
          useRegex: false,
        },
      ];
      const res = await get("/rules");
      const data = await res.json();
      expect(data.rules).toHaveLength(1);
      expect(data.rules[0].hostPattern).toBe("github.com");
    });

    test("does not require authentication", async () => {
      const res = await get("/rules");
      expect(res.status).toBe(200);
    });
  });

  // -----------------------------------------------------------------------
  // POST /rules
  // -----------------------------------------------------------------------

  describe("POST /rules", () => {
    test("without auth returns 401", async () => {
      const res = await post("/rules", { hostPattern: "x.com", browserAppId: "com.x" }, jsonHeaders());
      expect(res.status).toBe(401);
    });

    test("with wrong token returns 401", async () => {
      const res = await post("/rules", { hostPattern: "x.com", browserAppId: "com.x" }, {
        "X-Chowser-Token": "bad",
        "Content-Type": "application/json",
      });
      expect(res.status).toBe(401);
    });

    test("adds a new rule", async () => {
      const res = await post("/rules", {
        hostPattern: "github.com",
        browserAppId: "com.google.Chrome",
      });
      expect(res.status).toBe(201);
      const data = await res.json();
      expect(data.rule.hostPattern).toBe("github.com");
      expect(data.rule.browserAppId).toBe("com.google.Chrome");
    });

    test("requires hostPattern", async () => {
      const res = await post("/rules", { browserAppId: "com.x" });
      expect(res.status).toBe(400);
      const data = await res.json();
      expect(data.error).toContain("hostPattern");
    });

    test("requires browserAppId", async () => {
      const res = await post("/rules", { hostPattern: "x.com" });
      expect(res.status).toBe(400);
      const data = await res.json();
      expect(data.error).toContain("browserAppId");
    });

    test("updates existing rule by id", async () => {
      state.routingRules = [
        {
          id: "upd-rule",
          name: "Old",
          hostPattern: "old.com",
          browserAppId: "com.old",
          isEnabled: true,
          usePrivateMode: false,
          useRegex: false,
        },
      ];
      const res = await post("/rules", {
        id: "upd-rule",
        name: "Updated",
        hostPattern: "new.com",
        browserAppId: "com.new",
      });
      expect(res.status).toBe(200);
      const data = await res.json();
      expect(data.rule.name).toBe("Updated");
      expect(data.rule.id).toBe("upd-rule");
    });

    test("creates new rule when no id provided", async () => {
      const res = await post("/rules", {
        hostPattern: "example.com",
        browserAppId: "com.apple.Safari",
      });
      expect(res.status).toBe(201);
      expect(state.routingRules).toHaveLength(1);
    });

    test("creates new rule when id doesn't match existing", async () => {
      state.routingRules = [];
      const res = await post("/rules", {
        id: "nonexistent-id",
        hostPattern: "example.com",
        browserAppId: "com.apple.Safari",
      });
      expect(res.status).toBe(201);
      expect(state.routingRules).toHaveLength(1);
    });

    test("defaults isEnabled to true", async () => {
      const res = await post("/rules", {
        hostPattern: "x.com",
        browserAppId: "com.x",
      });
      const data = await res.json();
      expect(data.rule.isEnabled).toBe(true);
    });

    test("defaults usePrivateMode to false", async () => {
      const res = await post("/rules", {
        hostPattern: "x.com",
        browserAppId: "com.x",
      });
      const data = await res.json();
      expect(data.rule.usePrivateMode).toBe(false);
    });

    test("defaults useRegex to false", async () => {
      const res = await post("/rules", {
        hostPattern: "x.com",
        browserAppId: "com.x",
      });
      const data = await res.json();
      expect(data.rule.useRegex).toBe(false);
    });

    test("auto-generates name from hostPattern when name not provided", async () => {
      const res = await post("/rules", {
        hostPattern: "docs.github.com",
        browserAppId: "com.google.Chrome",
      });
      const data = await res.json();
      expect(data.rule.name).toContain("docs.github.com");
    });

    test("uses provided name", async () => {
      const res = await post("/rules", {
        name: "My Rule",
        hostPattern: "x.com",
        browserAppId: "com.x",
      });
      const data = await res.json();
      expect(data.rule.name).toBe("My Rule");
    });

    test("preserves all optional fields", async () => {
      const res = await post("/rules", {
        hostPattern: "work.com",
        browserAppId: "com.google.Chrome",
        pathPrefix: "/docs",
        profile: "Work",
        sourceAppBundleId: "com.tinyspeck.slackmacgap",
        isEnabled: false,
        usePrivateMode: true,
        useRegex: true,
      });
      const data = await res.json();
      expect(data.rule.pathPrefix).toBe("/docs");
      expect(data.rule.profile).toBe("Work");
      expect(data.rule.sourceAppBundleId).toBe("com.tinyspeck.slackmacgap");
      expect(data.rule.isEnabled).toBe(false);
      expect(data.rule.usePrivateMode).toBe(true);
      expect(data.rule.useRegex).toBe(true);
    });

    test("new rule gets a UUID id", async () => {
      const res = await post("/rules", {
        hostPattern: "x.com",
        browserAppId: "com.x",
      });
      const data = await res.json();
      expect(data.rule.id).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
      );
    });
  });

  // -----------------------------------------------------------------------
  // DELETE /rules
  // -----------------------------------------------------------------------

  describe("DELETE /rules", () => {
    test("without auth returns 401", async () => {
      const res = await fetch(`${BASE}/rules?id=abc`, { method: "DELETE" });
      expect(res.status).toBe(401);
    });

    test("without id returns 400", async () => {
      const res = await del("/rules", authHeaders());
      expect(res.status).toBe(400);
    });

    test("with nonexistent id returns 404", async () => {
      const res = await del("/rules?id=nonexistent", authHeaders());
      expect(res.status).toBe(404);
    });

    test("removes rule successfully", async () => {
      state.routingRules = [
        {
          id: "del-rule",
          name: "Delete Me",
          hostPattern: "del.com",
          browserAppId: "com.del",
          isEnabled: true,
          usePrivateMode: false,
          useRegex: false,
        },
      ];
      const res = await del("/rules?id=del-rule", authHeaders());
      expect(res.status).toBe(200);
      const data = await res.json();
      expect(data.success).toBe(true);
      expect(state.routingRules).toHaveLength(0);
    });

    test("only removes the targeted rule", async () => {
      state.routingRules = [
        {
          id: "keep",
          name: "Keep",
          hostPattern: "keep.com",
          browserAppId: "com.keep",
          isEnabled: true,
          usePrivateMode: false,
          useRegex: false,
        },
        {
          id: "del-rule",
          name: "Del",
          hostPattern: "del.com",
          browserAppId: "com.del",
          isEnabled: true,
          usePrivateMode: false,
          useRegex: false,
        },
      ];
      await del("/rules?id=del-rule", authHeaders());
      expect(state.routingRules).toHaveLength(1);
      expect(state.routingRules[0].id).toBe("keep");
    });
  });

  // -----------------------------------------------------------------------
  // 404 / unknown routes
  // -----------------------------------------------------------------------

  describe("unknown routes", () => {
    test("GET /nonexistent returns 404", async () => {
      const res = await get("/nonexistent");
      expect(res.status).toBe(404);
    });

    test("GET / returns 404", async () => {
      const res = await get("/");
      expect(res.status).toBe(404);
    });

    test("POST /nonexistent returns 404", async () => {
      const res = await fetch(`${BASE}/nonexistent`, {
        method: "POST",
        headers: authHeaders(),
        body: JSON.stringify({}),
      });
      expect(res.status).toBe(404);
    });

    test("DELETE /nonexistent returns 404", async () => {
      const res = await fetch(`${BASE}/nonexistent`, {
        method: "DELETE",
        headers: authHeaders(),
      });
      expect(res.status).toBe(404);
    });
  });

  // -----------------------------------------------------------------------
  // Error handling
  // -----------------------------------------------------------------------

  describe("error handling", () => {
    test("malformed JSON body returns 500", async () => {
      const res = await fetch(`${BASE}/browsers`, {
        method: "POST",
        headers: { "X-Chowser-Token": token, "Content-Type": "application/json" },
        body: "{ not valid json",
      });
      expect(res.status).toBe(500);
    });

    test("empty POST body to /browsers returns 500", async () => {
      const res = await fetch(`${BASE}/browsers`, {
        method: "POST",
        headers: { "X-Chowser-Token": token, "Content-Type": "application/json" },
        body: "",
      });
      expect(res.status).toBe(500);
    });

    test("empty POST body to /rules returns 500", async () => {
      const res = await fetch(`${BASE}/rules`, {
        method: "POST",
        headers: { "X-Chowser-Token": token, "Content-Type": "application/json" },
        body: "",
      });
      expect(res.status).toBe(500);
    });
  });

  // -----------------------------------------------------------------------
  // Response format
  // -----------------------------------------------------------------------

  describe("response format", () => {
    test("responses are JSON", async () => {
      const res = await get("/status");
      expect(res.headers.get("content-type")).toBe("application/json");
    });

    test("responses include CORS header", async () => {
      const res = await get("/status");
      expect(res.headers.get("access-control-allow-origin")).toBe("*");
    });
  });
});

// ---------------------------------------------------------------------------
// Post-stop tests
// ---------------------------------------------------------------------------

describe("MCP Server — post-stop", () => {
  test("stopMcpServer stops the server", () => {
    // Start first, then stop
    resetState();
    startMcpServer(getState, patchState);
    stopMcpServer();
    const status = getMcpStatus();
    expect(status.running).toBe(false);
  });

  test("getMcpStatus returns not running after stop", () => {
    const status = getMcpStatus();
    expect(status.running).toBe(false);
  });

  test("token is null after stop", () => {
    const status = getMcpStatus();
    expect(status.token).toBeNull();
  });

  test("token changes on each start", async () => {
    resetState();
    const s1 = startMcpServer(getState, patchState);
    const t1 = s1.token;
    stopMcpServer();
    await new Promise((r) => setTimeout(r, 50));
    const s2 = startMcpServer(getState, patchState);
    const t2 = s2.token;
    stopMcpServer();
    expect(t1).not.toBe(t2);
  });

  test("stopMcpServer is idempotent", () => {
    stopMcpServer();
    stopMcpServer(); // should not throw
    expect(getMcpStatus().running).toBe(false);
  });
});
