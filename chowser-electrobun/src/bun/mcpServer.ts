// ---------------------------------------------------------------------------
// MCP Server — lightweight local HTTP REST API on localhost:24245
//
// Provides AI-accessible endpoints for managing browsers and routing rules.
// All mutating endpoints require the X-Chowser-Token header.
// ---------------------------------------------------------------------------

import * as net from "node:net";
import type { PersistedState, BrowserConfig, BrowserRoutingRule } from "./models.ts";

export const MCP_PORT = 24245;

export interface McpStatus {
  running: boolean;
  port: number;
  token: string | null;
}

type StateGetter = () => PersistedState;
type StatePatcher = (patch: Partial<PersistedState>) => void;

let _server: net.Server | null = null;
let _token: string | null = null;

export function getMcpStatus(): McpStatus {
  return {
    running: _server !== null && _server.listening,
    port: MCP_PORT,
    token: _token,
  };
}

export function startMcpServer(
  getState: StateGetter,
  patchState: StatePatcher
): McpStatus {
  if (_server && _server.listening) return getMcpStatus();

  _token = crypto.randomUUID();

  _server = net.createServer((socket) => {
    let buf = "";
    socket.on("data", (chunk) => {
      buf += chunk.toString();
      // Wait until we have the full headers + body
      const headerEnd = buf.indexOf("\r\n\r\n");
      if (headerEnd === -1) return;

      const headerPart = buf.slice(0, headerEnd);
      const bodyStart = headerEnd + 4;
      const lines = headerPart.split("\r\n");
      const requestLine = lines[0] ?? "";
      const [method, rawPath] = requestLine.split(" ");

      // Parse Content-Length to wait for full body
      const clMatch = headerPart.match(/Content-Length:\s*(\d+)/i);
      const contentLength = clMatch ? parseInt(clMatch[1]!, 10) : 0;
      if (buf.length < bodyStart + contentLength) return; // wait for more data

      const body = buf.slice(bodyStart, bodyStart + contentLength);
      const url = new URL(rawPath ?? "/", `http://localhost:${MCP_PORT}`);
      const path = url.pathname;

      // Headers
      const headers: Record<string, string> = {};
      for (let i = 1; i < lines.length; i++) {
        const colon = lines[i]!.indexOf(":");
        if (colon === -1) continue;
        headers[lines[i]!.slice(0, colon).trim().toLowerCase()] =
          lines[i]!.slice(colon + 1).trim();
      }

      const respond = (status: number, data: unknown) => {
        const json = JSON.stringify(data, null, 2);
        const response = [
          `HTTP/1.1 ${status} ${statusText(status)}`,
          "Content-Type: application/json",
          `Content-Length: ${Buffer.byteLength(json)}`,
          "Connection: close",
          "Access-Control-Allow-Origin: *",
          "",
          json,
        ].join("\r\n");
        socket.write(response);
        socket.end();
      };

      const auth = () => {
        if (!_token) return true; // no token required if not set
        return headers["x-chowser-token"] === _token;
      };

      try {
        // ---------------------------------------------------------------
        // Routes
        // ---------------------------------------------------------------
        if (method === "GET" && path === "/status") {
          respond(200, {
            name: "Chowser",
            version: "0.1.0",
            mcp: true,
            endpoints: [
              "GET  /status",
              "GET  /browsers",
              "POST /browsers",
              "DELETE /browsers?id=<uuid>",
              "GET  /rules",
              "POST /rules",
              "DELETE /rules?id=<uuid>",
            ],
            auth: "Include X-Chowser-Token header for POST/DELETE",
          });
        } else if (method === "GET" && path === "/browsers") {
          respond(200, { browsers: getState().configuredBrowsers });
        } else if (method === "POST" && path === "/browsers") {
          if (!auth()) return respond(401, { error: "Unauthorized" });
          const b = JSON.parse(body) as Partial<BrowserConfig>;
          if (!b.name || !b.appId) {
            return respond(400, { error: "name and appId are required" });
          }
          const s = getState();
          const existing = s.configuredBrowsers.find(
            (x) =>
              x.appId === b.appId &&
              (x.profile ?? "") === (b.profile ?? "")
          );
          if (existing) {
            const updated = s.configuredBrowsers.map((x) =>
              x.id === existing.id ? { ...x, ...b, id: x.id } : x
            );
            patchState({ configuredBrowsers: updated });
            respond(200, { browser: getState().configuredBrowsers.find((x) => x.id === existing.id) });
          } else {
            const newBrowser: BrowserConfig = {
              id: crypto.randomUUID(),
              name: b.name,
              appId: b.appId,
              shortcutKey: b.shortcutKey ?? "9",
              profile: b.profile,
              customArguments: b.customArguments,
            };
            patchState({ configuredBrowsers: [...s.configuredBrowsers, newBrowser] });
            respond(201, { browser: newBrowser });
          }
        } else if (method === "DELETE" && path === "/browsers") {
          if (!auth()) return respond(401, { error: "Unauthorized" });
          const id = url.searchParams.get("id");
          if (!id) return respond(400, { error: "id query param required" });
          const s = getState();
          const found = s.configuredBrowsers.some((b) => b.id === id);
          if (!found) return respond(404, { error: "Browser not found" });
          patchState({
            configuredBrowsers: s.configuredBrowsers.filter((b) => b.id !== id),
          });
          respond(200, { success: true });
        } else if (method === "GET" && path === "/rules") {
          respond(200, { rules: getState().routingRules });
        } else if (method === "POST" && path === "/rules") {
          if (!auth()) return respond(401, { error: "Unauthorized" });
          const r = JSON.parse(body) as Partial<BrowserRoutingRule>;
          if (!r.hostPattern || !r.browserAppId) {
            return respond(400, { error: "hostPattern and browserAppId are required" });
          }
          const s = getState();
          const existing = r.id ? s.routingRules.find((x) => x.id === r.id) : null;
          if (existing) {
            const updated = s.routingRules.map((x) =>
              x.id === r.id ? { ...x, ...r, id: x.id } : x
            );
            patchState({ routingRules: updated });
            respond(200, { rule: updated.find((x) => x.id === r.id) });
          } else {
            const newRule: BrowserRoutingRule = {
              id: crypto.randomUUID(),
              name: r.name ?? `Rule for ${r.hostPattern}`,
              hostPattern: r.hostPattern,
              pathPrefix: r.pathPrefix,
              browserAppId: r.browserAppId,
              profile: r.profile,
              sourceAppBundleId: r.sourceAppBundleId,
              isEnabled: r.isEnabled ?? true,
              usePrivateMode: r.usePrivateMode ?? false,
              useRegex: r.useRegex ?? false,
            };
            patchState({ routingRules: [...s.routingRules, newRule] });
            respond(201, { rule: newRule });
          }
        } else if (method === "DELETE" && path === "/rules") {
          if (!auth()) return respond(401, { error: "Unauthorized" });
          const id = url.searchParams.get("id");
          if (!id) return respond(400, { error: "id query param required" });
          const s = getState();
          const found = s.routingRules.some((r) => r.id === id);
          if (!found) return respond(404, { error: "Rule not found" });
          patchState({
            routingRules: s.routingRules.filter((r) => r.id !== id),
          });
          respond(200, { success: true });
        } else {
          respond(404, { error: "Not found" });
        }
      } catch (err) {
        respond(500, { error: String(err) });
      }
    });

    socket.on("error", () => {});
  });

  _server.on("error", (err) => {
    console.error("[mcp] Server error:", err);
    _server = null;
  });

  _server.listen(MCP_PORT, "127.0.0.1", () => {
    console.log(`[mcp] Listening on 127.0.0.1:${MCP_PORT}`);
    console.log(`[mcp] Auth token: ${_token}`);
  });

  return getMcpStatus();
}

export function stopMcpServer(): void {
  if (_server) {
    _server.close();
    _server = null;
    _token = null;
    console.log("[mcp] Server stopped");
  }
}

function statusText(code: number): string {
  const map: Record<number, string> = {
    200: "OK",
    201: "Created",
    400: "Bad Request",
    401: "Unauthorized",
    404: "Not Found",
    500: "Internal Server Error",
  };
  return map[code] ?? "Unknown";
}
