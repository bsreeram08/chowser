// ---------------------------------------------------------------------------
// Chowser — main Bun process
//
// This is the "backend" that runs persistently in the background.
// It handles:
//   • macOS URL interception (open-url events from the OS)
//   • Browser picker window (shows when no routing rule matches)
//   • Settings window
//   • System tray / menu-bar icon
//   • All business logic (routing, browser management, config)
//   • MCP Server (REST API for AI management)
//   • Focus Mode (temporary browser override)
//   • Recent URLs tracking
// ---------------------------------------------------------------------------

import Electrobun, {
  Tray,
  BrowserWindow,
  BrowserView,
  Utils,
  type ElectrobunRPCSchema,
} from "electrobun/bun";
import type { MenuItemConfig } from "electrobun/bun";

import {
  loadState,
  getState,
  patchState,
  flushState,
} from "./config.ts";
import {
  type BrowserConfig,
  type BrowserRoutingRule,
  type InstalledBrowser,
  type RecentUrl,
  type FocusMode,
  type PickerLayout,
  RECENT_URLS_MAX,
  DEFAULT_HIDDEN_APP_IDS,
  nextAvailableShortcut,
} from "./models.ts";
import { resolveRoute, recordDomainClick, getSuggestions } from "./routing.ts";
import { detectInstalledBrowsers } from "./browserDetector.ts";
import { launchBrowser, launchByRoute } from "./browserLauncher.ts";
import { cleanUrl, isHttpUrl } from "./urlUtils.ts";
import {
  startMcpServer,
  stopMcpServer,
  getMcpStatus,
  type McpStatus,
} from "./mcpServer.ts";

// ---------------------------------------------------------------------------
// Boot — load persisted state
// ---------------------------------------------------------------------------

const state = loadState();
console.log(
  `[chowser] booted. ${state.configuredBrowsers.length} browsers, ${state.routingRules.length} rules.`
);

// ---------------------------------------------------------------------------
// Focus Mode timer — auto-expire when expiresAt is reached
// ---------------------------------------------------------------------------

let _focusModeTimer: ReturnType<typeof setTimeout> | null = null;

function scheduleFocusModeExpiry() {
  if (_focusModeTimer) clearTimeout(_focusModeTimer);
  const fm = getState().focusMode;
  if (!fm || fm.expiresAt === null) return;
  const delay = fm.expiresAt - Date.now();
  if (delay <= 0) {
    patchState({ focusMode: null });
    updateTrayMenu();
    return;
  }
  _focusModeTimer = setTimeout(() => {
    patchState({ focusMode: null });
    updateTrayMenu();
    console.log("[chowser] Focus mode expired");
  }, delay);
}

scheduleFocusModeExpiry();

// ---------------------------------------------------------------------------
// System tray icon
// ---------------------------------------------------------------------------

const tray = new Tray({ title: "⟳", template: true });
updateTrayMenu();

function buildFocusModeMenu(): MenuItemConfig[] {
  const s = getState();
  const fm = s.focusMode;
  if (!fm) {
    return [
      {
        label: "Set Focus Mode…",
        type: "normal" as const,
        action: "focus-mode-menu",
      },
    ];
  }
  const browser = s.configuredBrowsers.find((b) => b.id === fm.browserId);
  const browserName = browser?.name ?? "Unknown";
  const expLabel =
    fm.expiresAt === null
      ? "Until quit"
      : `Until ${new Date(fm.expiresAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
  return [
    {
      label: `🎯 Focus: ${browserName} (${expLabel})`,
      type: "normal" as const,
      action: "noop",
    },
    {
      label: "Clear Focus Mode",
      type: "normal" as const,
      action: "clear-focus-mode",
    },
  ];
}

function buildClipboardMenu(): MenuItemConfig[] {
  try {
    const text = Utils.clipboardReadText() ?? "";
    if (isHttpUrl(text)) {
      const truncated = text.length > 60 ? text.slice(0, 60) + "…" : text;
      return [
        {
          label: `Open Clipboard URL`,
          type: "normal" as const,
          action: "open-clipboard-url",
        },
        {
          label: truncated,
          type: "normal" as const,
          action: "noop",
        },
      ];
    }
  } catch {}
  return [];
}

function buildRecentUrlsMenu(): MenuItemConfig[] {
  const recents = getState().recentUrls.slice(0, 10);
  if (recents.length === 0) return [];

  const items: MenuItemConfig[] = [
    { type: "divider" as const },
    {
      label: "Recent URLs",
      type: "normal" as const,
      action: "noop",
    },
    ...recents.map((r, i): MenuItemConfig => {
      let display = r.url;
      try {
        display = new URL(r.url).hostname;
      } catch {}
      if (display.length > 55) display = display.slice(0, 55) + "…";
      return {
        label: display,
        type: "normal" as const,
        action: `open-recent-${i}`,
      };
    }),
  ];
  return items;
}

function updateTrayMenu() {
  const s = getState();
  const clipboardItems = buildClipboardMenu();
  const focusItems = buildFocusModeMenu();
  const recentItems = buildRecentUrlsMenu();

  const items: MenuItemConfig[] = [
    {
      label: "Open Picker",
      type: "normal" as const,
      action: "open-picker",
    },
  ];

  if (clipboardItems.length > 0) {
    items.push({ type: "divider" as const }, ...clipboardItems);
  }

  items.push(
    { type: "divider" as const },
    ...focusItems,
    { type: "divider" as const },
    {
      label: "Settings…",
      type: "normal" as const,
      action: "open-settings",
    }
  );

  // MCP Server toggle
  const mcpStatus = getMcpStatus();
  items.push({
    label: mcpStatus.running
      ? `API Server Running (port ${mcpStatus.port})`
      : "Start API Server",
    type: "normal" as const,
    action: "toggle-mcp-server",
  });

  if (!s.hasCompletedOnboarding) {
    items.push({ type: "divider" as const });
    items.push({
      label: "Set as Default Browser",
      type: "normal" as const,
      action: "set-default-browser",
    });
  }

  items.push(...recentItems);

  items.push(
    { type: "divider" as const },
    { label: "Quit Chowser", type: "normal" as const, action: "quit" }
  );

  tray.setMenu(items);
}

tray.on("tray-clicked", (_event: unknown) => {
  // Left-click opens picker; right-click shows menu (handled natively)
});

// Handle tray menu actions
Electrobun.events.on("context-menu-clicked", (event) => {
  const action = (event as { data: { action: string } }).data?.action;
  handleMenuAction(action);
});

Electrobun.events.on("application-menu-clicked", (event) => {
  const action = (event as { data: { action: string } }).data?.action;
  handleMenuAction(action);
});

function handleMenuAction(action: string) {
  switch (action) {
    case "open-picker":
      showPickerForManualOpen();
      break;
    case "open-settings":
      openSettings();
      break;
    case "set-default-browser":
      Utils.openExternal(
        "x-apple.systempreferences:com.apple.preferences.generalIn"
      );
      break;
    case "quit":
      flushState();
      Utils.quit();
      break;
    case "open-clipboard-url": {
      const text = Utils.clipboardReadText() ?? "";
      if (isHttpUrl(text)) handleIncomingURL(text);
      break;
    }
    case "clear-focus-mode":
      patchState({ focusMode: null });
      updateTrayMenu();
      break;
    case "focus-mode-menu":
      openSettings();
      break;
    case "toggle-mcp-server": {
      const status = getMcpStatus();
      if (status.running) {
        stopMcpServer();
      } else {
        startMcpServer(getState, patchState);
      }
      updateTrayMenu();
      break;
    }
    case "noop":
      break;
    default:
      // Handle "open-recent-N"
      if (action.startsWith("open-recent-")) {
        const idx = parseInt(action.slice("open-recent-".length), 10);
        const recents = getState().recentUrls;
        const entry = recents[idx];
        if (entry) showPicker(entry.url);
      }
      break;
  }
}

// ---------------------------------------------------------------------------
// URL interception — the core of Chowser
// ---------------------------------------------------------------------------

Electrobun.events.on("open-url", (event) => {
  const { url } = (event as { data: { url: string } }).data;
  console.log(`[chowser] intercepted URL: ${url}`);
  handleIncomingURL(url);
});

function handleIncomingURL(rawUrl: string, sourceApp?: string) {
  // Clean tracking parameters
  const url = cleanUrl(rawUrl);

  const s = getState();

  // Focus Mode override — route to focus browser regardless of rules
  if (s.focusMode) {
    const fm = s.focusMode;
    if (fm.expiresAt === null || fm.expiresAt > Date.now()) {
      const browser = s.configuredBrowsers.find((b) => b.id === fm.browserId);
      if (browser) {
        launchBrowser(url, browser, false);
        trackDomain(url, browser.appId);
        recordRecentUrl(url, browser.id);
        return;
      }
    } else {
      // Expired
      patchState({ focusMode: null });
      updateTrayMenu();
    }
  }

  // Try to resolve a routing rule
  const route = resolveRoute(url, s.routingRules, sourceApp);

  if (route) {
    const launched = launchByRoute(url, route, s.configuredBrowsers);
    if (launched) {
      trackDomain(url, route.browserAppId);
      const browser = s.configuredBrowsers.find(
        (b) => b.appId === route.browserAppId
      );
      recordRecentUrl(url, browser?.id ?? null);
      return;
    }
    console.warn(
      `[chowser] browser ${route.browserAppId} not found, showing picker`
    );
  }

  // No rule matched — show the picker
  showPicker(url, sourceApp);
}

function trackDomain(url: string, appId: string) {
  try {
    const host = new URL(url).hostname;
    const s = getState();
    const newFreq = recordDomainClick(s.domainFrequency, host, appId);
    patchState({ domainFrequency: newFreq });

    const suggestions = getSuggestions(newFreq);
    const relevant = suggestions.find(
      (sug) => sug.domain === host && sug.appId === appId
    );
    if (relevant && relevant.count % 30 === 0) {
      showRuleSuggestion(host, appId);
    }
  } catch {
    // URL parsing failure — ignore
  }
}

function recordRecentUrl(url: string, browserId: string | null) {
  const s = getState();
  const entry: RecentUrl = { url, browserId, timestamp: Date.now() };
  const existing = s.recentUrls.filter((r) => r.url !== url);
  const updated = [entry, ...existing].slice(0, RECENT_URLS_MAX);
  patchState({ recentUrls: updated });
  updateTrayMenu();
}

// ---------------------------------------------------------------------------
// Picker window
// ---------------------------------------------------------------------------

let pickerWindow: InstanceType<typeof BrowserWindow> | null = null;
let pendingPickerUrl: string | null = null;
let pendingPickerSourceApp: string | null = null;

type PickerSchema = ElectrobunRPCSchema & {
  bun: {
    requests: {
      getPickerData: {
        params: undefined;
        response: {
          url: string;
          browsers: BrowserConfig[];
          suggestedRuleHostPattern: string;
          focusMode: FocusMode | null;
        };
      };
      openInBrowser: {
        params: { browserId: string; usePrivateMode: boolean };
        response: void;
      };
      dismissPicker: { params: undefined; response: void };
      createRule: {
        params: {
          name: string;
          hostPattern: string;
          browserAppId: string;
          usePrivateMode: boolean;
        };
        response: void;
      };
    };
    messages: Record<string, never>;
  };
  webview: {
    requests: Record<string, never>;
    messages: {
      refreshPicker: undefined;
    };
  };
};

let pickerRPC: ReturnType<typeof BrowserView.defineRPC<PickerSchema>> | null =
  null;

function showPicker(url: string, sourceApp?: string) {
  pendingPickerUrl = url;
  pendingPickerSourceApp = sourceApp ?? null;

  if (pickerWindow && pickerRPC) {
    (pickerRPC.send as unknown as { refreshPicker: () => void }).refreshPicker();
    return;
  }

  const rpc = BrowserView.defineRPC<PickerSchema>({
    handlers: {
      requests: {
        getPickerData: () => {
          const s = getState();
          let suggestedHostPattern = "";
          try {
            suggestedHostPattern = new URL(pendingPickerUrl ?? url).hostname;
          } catch {}
          return {
            url: pendingPickerUrl ?? url,
            browsers: s.configuredBrowsers,
            suggestedRuleHostPattern: suggestedHostPattern,
            focusMode: s.focusMode,
          };
        },
        openInBrowser: (params: unknown) => {
          const { browserId, usePrivateMode } = params as {
            browserId: string;
            usePrivateMode: boolean;
          };
          const s = getState();
          const browser = s.configuredBrowsers.find((b) => b.id === browserId);
          if (!browser || !pendingPickerUrl) return;
          launchBrowser(pendingPickerUrl, browser, usePrivateMode);
          trackDomain(pendingPickerUrl, browser.appId);
          recordRecentUrl(pendingPickerUrl, browser.id);
          pickerWindow?.close();
          pickerWindow = null;
          pickerRPC = null;
          pendingPickerUrl = null;
        },
        dismissPicker: () => {
          pickerWindow?.close();
          pickerWindow = null;
          pickerRPC = null;
          pendingPickerUrl = null;
        },
        createRule: (params: unknown) => {
          const { name, hostPattern, browserAppId, usePrivateMode } =
            params as {
              name: string;
              hostPattern: string;
              browserAppId: string;
              usePrivateMode: boolean;
            };
          const s = getState();
          const newRule: BrowserRoutingRule = {
            id: crypto.randomUUID(),
            name,
            hostPattern,
            browserAppId,
            usePrivateMode,
            isEnabled: true,
            useRegex: false,
          };
          patchState({ routingRules: [...s.routingRules, newRule] });
        },
      } as unknown as Parameters<typeof BrowserView.defineRPC<PickerSchema>>[0]["handlers"]["requests"],
    },
  });

  pickerRPC = rpc;

  pickerWindow = new BrowserWindow({
    title: "Chowser — Pick a Browser",
    frame: { x: 0, y: 0, width: 560, height: 340 },
    url: "views://picker/index.html",
    titleBarStyle: "hiddenInset",
    transparent: false,
    passthrough: false,
    rpc,
    navigationRules: "deny-all",
    sandbox: false,
  } as never);

  pickerWindow.on("close", () => {
    pickerWindow = null;
    pickerRPC = null;
    pendingPickerUrl = null;
  });
}

function showPickerForManualOpen() {
  const clipboardText = Utils.clipboardReadText() ?? "";
  let clipUrl = "";
  try {
    const u = new URL(clipboardText);
    if (u.protocol === "http:" || u.protocol === "https:") {
      clipUrl = clipboardText;
    }
  } catch {}
  showPicker(clipUrl || "https://");
}

// ---------------------------------------------------------------------------
// Settings window
// ---------------------------------------------------------------------------

let settingsWindow: InstanceType<typeof BrowserWindow> | null = null;

type SettingsSchema = ElectrobunRPCSchema & {
  bun: {
    requests: {
      getState: {
        params: undefined;
        response: {
          browsers: BrowserConfig[];
          rules: BrowserRoutingRule[];
          installedBrowsers: InstalledBrowser[];
          hasCompletedOnboarding: boolean;
          hiddenAppIds: string[];
          recentUrls: RecentUrl[];
          pickerLayout: PickerLayout;
          launchAtLogin: boolean;
          focusMode: FocusMode | null;
          mcpStatus: McpStatus;
        };
      };
      saveBrowsers: { params: { browsers: BrowserConfig[] }; response: void };
      saveRules: { params: { rules: BrowserRoutingRule[] }; response: void };
      addBrowser: { params: BrowserConfig; response: void };
      updateBrowser: { params: BrowserConfig; response: void };
      removeBrowser: { params: { id: string }; response: void };
      addRule: { params: BrowserRoutingRule; response: void };
      updateRule: { params: BrowserRoutingRule; response: void };
      duplicateRule: { params: { id: string }; response: void };
      removeRule: { params: { id: string }; response: void };
      reorderRules: { params: { ids: string[] }; response: void };
      detectBrowsers: { params: undefined; response: InstalledBrowser[] };
      completeOnboarding: { params: undefined; response: void };
      exportConfig: { params: undefined; response: string };
      importConfig: {
        params: { json: string };
        response: { success: boolean; message: string };
      };
      testUrl: {
        params: { url: string };
        response: { matched: boolean; ruleName: string; browserName: string } | null;
      };
      setHiddenApps: { params: { ids: string[] }; response: void };
      resetToDefaults: { params: undefined; response: void };
      setPickerLayout: { params: { layout: PickerLayout }; response: void };
      setFocusMode: {
        params: { browserId: string; durationMinutes: number | null };
        response: void;
      };
      clearFocusMode: { params: undefined; response: void };
      clearRecentUrls: { params: undefined; response: void };
      openUrl: { params: { url: string; browserId?: string }; response: void };
      toggleMcpServer: { params: undefined; response: McpStatus };
    };
    messages: Record<string, never>;
  };
  webview: {
    requests: Record<string, never>;
    messages: Record<string, never>;
  };
};

function openSettings() {
  if (settingsWindow) {
    settingsWindow.focus?.();
    return;
  }

  const settingsRPC = BrowserView.defineRPC<SettingsSchema>({
    handlers: {
      requests: {
        getState: () => {
          const s = getState();
          return {
            browsers: s.configuredBrowsers,
            rules: s.routingRules,
            installedBrowsers: detectInstalledBrowsers(),
            hasCompletedOnboarding: s.hasCompletedOnboarding,
            hiddenAppIds: s.hiddenAppIds,
            recentUrls: s.recentUrls,
            pickerLayout: s.pickerLayout,
            launchAtLogin: s.launchAtLogin,
            focusMode: s.focusMode,
            mcpStatus: getMcpStatus(),
          };
        },
        saveBrowsers: (params: unknown) => {
          const { browsers } = params as { browsers: BrowserConfig[] };
          patchState({ configuredBrowsers: browsers });
        },
        saveRules: (params: unknown) => {
          const { rules } = params as { rules: BrowserRoutingRule[] };
          patchState({ routingRules: rules });
        },
        addBrowser: (params: unknown) => {
          const browser = params as BrowserConfig;
          const s = getState();
          if (s.configuredBrowsers.some((b) => b.id === browser.id)) return;
          patchState({
            configuredBrowsers: [...s.configuredBrowsers, browser],
          });
        },
        updateBrowser: (params: unknown) => {
          const browser = params as BrowserConfig;
          const s = getState();
          patchState({
            configuredBrowsers: s.configuredBrowsers.map((b) =>
              b.id === browser.id ? browser : b
            ),
          });
        },
        removeBrowser: (params: unknown) => {
          const { id } = params as { id: string };
          const s = getState();
          patchState({
            configuredBrowsers: s.configuredBrowsers.filter((b) => b.id !== id),
          });
        },
        addRule: (params: unknown) => {
          const rule = params as BrowserRoutingRule;
          const s = getState();
          patchState({ routingRules: [...s.routingRules, rule] });
        },
        updateRule: (params: unknown) => {
          const rule = params as BrowserRoutingRule;
          const s = getState();
          patchState({
            routingRules: s.routingRules.map((r) =>
              r.id === rule.id ? rule : r
            ),
          });
        },
        duplicateRule: (params: unknown) => {
          const { id } = params as { id: string };
          const s = getState();
          const rule = s.routingRules.find((r) => r.id === id);
          if (!rule) return;
          const idx = s.routingRules.indexOf(rule);
          const copy: BrowserRoutingRule = {
            ...rule,
            id: crypto.randomUUID(),
            name: `${rule.name} (copy)`,
          };
          const newRules = [...s.routingRules];
          newRules.splice(idx + 1, 0, copy);
          patchState({ routingRules: newRules });
        },
        removeRule: (params: unknown) => {
          const { id } = params as { id: string };
          const s = getState();
          patchState({
            routingRules: s.routingRules.filter((r) => r.id !== id),
          });
        },
        reorderRules: (params: unknown) => {
          const { ids } = params as { ids: string[] };
          const s = getState();
          const ruleMap = new Map(s.routingRules.map((r) => [r.id, r]));
          const reordered = ids
            .map((id) => ruleMap.get(id))
            .filter((r): r is BrowserRoutingRule => r !== undefined);
          patchState({ routingRules: reordered });
        },
        detectBrowsers: () => detectInstalledBrowsers(),
        completeOnboarding: () => {
          patchState({ hasCompletedOnboarding: true });
        },
        exportConfig: () => {
          const s = getState();
          return JSON.stringify(
            { browsers: s.configuredBrowsers, rules: s.routingRules },
            null,
            2
          );
        },
        importConfig: (params: unknown) => {
          const { json } = params as { json: string };
          try {
            const parsed = JSON.parse(json) as {
              browsers?: BrowserConfig[];
              rules?: BrowserRoutingRule[];
            };
            const s = getState();
            let updated = { ...s };

            if (Array.isArray(parsed.browsers)) {
              const existing = new Set(
                s.configuredBrowsers.map(
                  (b) => `${b.appId}|${b.profile ?? ""}`
                )
              );
              const newBrowsers = parsed.browsers.filter(
                (b) => !existing.has(`${b.appId}|${b.profile ?? ""}`)
              );
              updated.configuredBrowsers = [
                ...s.configuredBrowsers,
                ...newBrowsers,
              ];
            }

            if (Array.isArray(parsed.rules)) {
              const existingIds = new Set(s.routingRules.map((r) => r.id));
              const newRules = parsed.rules.filter(
                (r) => !existingIds.has(r.id)
              );
              updated.routingRules = [...s.routingRules, ...newRules];
            }

            patchState(updated);
            return { success: true, message: "Config imported successfully." };
          } catch (err) {
            return {
              success: false,
              message: `Failed to parse config: ${(err as Error).message}`,
            };
          }
        },
        testUrl: (params: unknown) => {
          const { url } = params as { url: string };
          const s = getState();
          const route = resolveRoute(url, s.routingRules);
          if (!route) return null;
          const rule = s.routingRules.find(
            (r) => r.id === route.matchedRuleId
          );
          const browser = s.configuredBrowsers.find(
            (b) => b.appId === route.browserAppId
          );
          return {
            matched: true,
            ruleName: rule?.name ?? "Unknown rule",
            browserName: browser?.name ?? route.browserAppId,
          };
        },
        setHiddenApps: (params: unknown) => {
          const { ids } = params as { ids: string[] };
          patchState({ hiddenAppIds: ids });
        },
        resetToDefaults: () => {
          const s = getState();
          patchState({
            configuredBrowsers: [
              {
                id: crypto.randomUUID(),
                name: "Safari",
                appId: "com.apple.Safari",
                shortcutKey: "1",
              },
            ],
            routingRules: [],
            hiddenAppIds: [...DEFAULT_HIDDEN_APP_IDS],
            domainFrequency: {},
            recentUrls: [],
            hasCompletedOnboarding: false,
            focusMode: null,
          });
          updateTrayMenu();
        },
        setPickerLayout: (params: unknown) => {
          const { layout } = params as { layout: PickerLayout };
          patchState({ pickerLayout: layout });
        },
        setFocusMode: (params: unknown) => {
          const { browserId, durationMinutes } = params as {
            browserId: string;
            durationMinutes: number | null;
          };
          const expiresAt =
            durationMinutes !== null
              ? Date.now() + durationMinutes * 60 * 1000
              : null;
          patchState({ focusMode: { browserId, expiresAt } });
          scheduleFocusModeExpiry();
          updateTrayMenu();
        },
        clearFocusMode: () => {
          patchState({ focusMode: null });
          updateTrayMenu();
        },
        clearRecentUrls: () => {
          patchState({ recentUrls: [] });
          updateTrayMenu();
        },
        openUrl: (params: unknown) => {
          const { url, browserId } = params as {
            url: string;
            browserId?: string;
          };
          if (browserId) {
            const s = getState();
            const browser = s.configuredBrowsers.find(
              (b) => b.id === browserId
            );
            if (browser) {
              launchBrowser(url, browser, false);
              recordRecentUrl(url, browser.id);
              return;
            }
          }
          handleIncomingURL(url);
        },
        toggleMcpServer: () => {
          const status = getMcpStatus();
          if (status.running) {
            stopMcpServer();
          } else {
            startMcpServer(getState, patchState);
          }
          updateTrayMenu();
          return getMcpStatus();
        },
      } as unknown as Parameters<typeof BrowserView.defineRPC<SettingsSchema>>[0]["handlers"]["requests"],
    },
  });

  settingsWindow = new BrowserWindow({
    title: "Chowser Settings",
    frame: { x: 100, y: 100, width: 900, height: 640 },
    url: "views://settings/index.html",
    titleBarStyle: "default",
    transparent: false,
    passthrough: false,
    rpc: settingsRPC,
    navigationRules: "deny-all",
    sandbox: false,
  } as never);

  settingsWindow.on("close", () => {
    settingsWindow = null;
  });
}

// ---------------------------------------------------------------------------
// Rule suggestion notification
// ---------------------------------------------------------------------------

function showRuleSuggestion(domain: string, appId: string) {
  const s = getState();
  const browser = s.configuredBrowsers.find((b) => b.appId === appId);
  const browserName = browser?.name ?? appId;

  Utils.showNotification({
    title: "Chowser — Auto-Rule Suggestion",
    body: `You've opened ${domain} in ${browserName} 30+ times. Create a rule?`,
  });
}

// ---------------------------------------------------------------------------
// On app reopen (dock click / spotlight launch) show settings
// ---------------------------------------------------------------------------

Electrobun.events.on("reopen", () => {
  openSettings();
});

// ---------------------------------------------------------------------------
// Graceful shutdown — flush state before the process exits
// ---------------------------------------------------------------------------

process.on("exit", () => {
  flushState();
  stopMcpServer();
});

console.log("[chowser] ready.");
