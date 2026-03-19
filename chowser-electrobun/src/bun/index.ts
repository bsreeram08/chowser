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
// ---------------------------------------------------------------------------

import Electrobun, {
  Tray,
  BrowserWindow,
  BrowserView,
  Utils,
  type ElectrobunRPCSchema,
} from "electrobun/bun";

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
  nextAvailableShortcut,
} from "./models.ts";
import { resolveRoute, recordDomainClick, getSuggestions } from "./routing.ts";
import { detectInstalledBrowsers } from "./browserDetector.ts";
import { launchBrowser, launchByRoute } from "./browserLauncher.ts";

// ---------------------------------------------------------------------------
// Boot — load persisted state
// ---------------------------------------------------------------------------

const state = loadState();
console.log(
  `[chowser] booted. ${state.configuredBrowsers.length} browsers, ${state.routingRules.length} rules.`
);

// ---------------------------------------------------------------------------
// System tray icon
// ---------------------------------------------------------------------------

const tray = new Tray({ title: "⟳", template: true });
updateTrayMenu();

function updateTrayMenu() {
  const s = getState();
  tray.setMenu([
    {
      label: "Open Picker",
      type: "normal" as const,
      action: "open-picker",
    },
    { type: "divider" as const },
    {
      label: "Settings…",
      type: "normal" as const,
      action: "open-settings",
    },
    { type: "divider" as const },
    {
      label: "Set as Default Browser",
      type: "normal" as const,
      action: "set-default-browser",
    },
    { type: "divider" as const },
    { label: "Quit Chowser", type: "normal" as const, action: "quit" },
  ]);
}

tray.on("tray-clicked", (_event: unknown) => {
  // Left-click opens picker, right-click shows menu (handled natively)
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
  }
}

// ---------------------------------------------------------------------------
// URL interception — the core of Chowser
// ---------------------------------------------------------------------------

/**
 * The OS fires this event when Chowser is registered as the default handler
 * for http/https and a link is clicked anywhere on the system.
 */
Electrobun.events.on("open-url", (event) => {
  const { url } = (event as { data: { url: string } }).data;
  console.log(`[chowser] intercepted URL: ${url}`);
  handleIncomingURL(url);
});

function handleIncomingURL(url: string, sourceApp?: string) {
  const s = getState();

  // Try to resolve a routing rule
  const route = resolveRoute(url, s.routingRules, sourceApp);

  if (route) {
    // A rule matched — open directly
    const launched = launchByRoute(url, route, s.configuredBrowsers);
    if (launched) {
      // Track domain frequency
      trackDomain(url, route.browserAppId);
      return;
    }
    // Browser not found — fall through to picker
    console.warn(`[chowser] browser ${route.browserAppId} not found, showing picker`);
  }

  // No rule matched (or browser not found) — show the picker
  showPicker(url, sourceApp);
}

function trackDomain(url: string, appId: string) {
  try {
    const host = new URL(url).hostname;
    const s = getState();
    const newFreq = recordDomainClick(s.domainFrequency, host, appId);
    patchState({ domainFrequency: newFreq });

    // Check if we should suggest a new rule
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

// ---------------------------------------------------------------------------
// Picker window
// ---------------------------------------------------------------------------

let pickerWindow: InstanceType<typeof BrowserWindow> | null = null;
let pendingPickerUrl: string | null = null;
let pendingPickerSourceApp: string | null = null;

// RPC schema for the Picker webview ↔ Bun communication
// bun.requests  = requests that Bun handles (called by the webview)
// webview.messages = messages that the webview receives (sent from Bun)
type PickerSchema = ElectrobunRPCSchema & {
  bun: {
    requests: {
      getPickerData: {
        params: undefined;
        response: {
          url: string;
          browsers: BrowserConfig[];
          suggestedRuleHostPattern: string;
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

  // Reuse an existing picker window if open — just refresh it
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
          };
        },
        openInBrowser: ({ browserId, usePrivateMode }) => {
          const s = getState();
          const browser = s.configuredBrowsers.find((b) => b.id === browserId);
          if (!browser || !pendingPickerUrl) return;
          launchBrowser(pendingPickerUrl, browser, usePrivateMode);
          trackDomain(pendingPickerUrl, browser.appId);
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
        createRule: ({ name, hostPattern, browserAppId, usePrivateMode }) => {
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
      },
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
  // Show picker without a URL (for clipboard or typed URL)
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

// RPC schema for the Settings webview ↔ Bun communication
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
        };
      };
      saveBrowsers: { params: { browsers: BrowserConfig[] }; response: void };
      saveRules: { params: { rules: BrowserRoutingRule[] }; response: void };
      addBrowser: { params: BrowserConfig; response: void };
      removeBrowser: { params: { id: string }; response: void };
      addRule: { params: BrowserRoutingRule; response: void };
      removeRule: { params: { id: string }; response: void };
      reorderRules: { params: { ids: string[] }; response: void };
      detectBrowsers: { params: undefined; response: InstalledBrowser[] };
      completeOnboarding: { params: undefined; response: void };
      exportConfig: { params: undefined; response: string };
      importConfig: {
        params: { json: string };
        response: { success: boolean; message: string };
      };
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
          };
        },
        saveBrowsers: ({ browsers }) => {
          patchState({ configuredBrowsers: browsers });
        },
        saveRules: ({ rules }) => {
          patchState({ routingRules: rules });
        },
        addBrowser: (browser) => {
          const s = getState();
          if (s.configuredBrowsers.some((b) => b.id === browser.id)) return;
          patchState({
            configuredBrowsers: [...s.configuredBrowsers, browser],
          });
        },
        removeBrowser: ({ id }) => {
          const s = getState();
          patchState({
            configuredBrowsers: s.configuredBrowsers.filter((b) => b.id !== id),
          });
        },
        addRule: (rule) => {
          const s = getState();
          patchState({ routingRules: [...s.routingRules, rule] });
        },
        removeRule: ({ id }) => {
          const s = getState();
          patchState({
            routingRules: s.routingRules.filter((r) => r.id !== id),
          });
        },
        reorderRules: ({ ids }) => {
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
        importConfig: ({ json }) => {
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
      },
    },
  });

  settingsWindow = new BrowserWindow({
    title: "Chowser Settings",
    frame: { x: 100, y: 100, width: 860, height: 620 },
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
});

console.log("[chowser] ready.");
