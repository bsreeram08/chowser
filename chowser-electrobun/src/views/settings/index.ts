// ---------------------------------------------------------------------------
// Settings webview — TypeScript that runs inside the settings window
// ---------------------------------------------------------------------------

import { Electroview, type ElectrobunRPCSchema } from "electrobun/view";
import type {
  BrowserConfig,
  BrowserRoutingRule,
  InstalledBrowser,
  RecentUrl,
  FocusMode,
  PickerLayout,
} from "../../bun/models.ts";

// ---------------------------------------------------------------------------
// RPC schema (must mirror src/bun/index.ts SettingsSchema)
// ---------------------------------------------------------------------------

interface McpStatus {
  running: boolean;
  port: number;
  token: string | null;
}

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

const settingsRpc = Electroview.defineRPC<SettingsSchema>({
  handlers: {},
});

new Electroview({ rpc: settingsRpc });

interface AppState {
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
}

let appState: AppState | null = null;
let activeTab: "browsers" | "rules" | "apps" | "general" = "browsers";
let modal: HTMLElement | null = null;
let ruleTestResult: { matched: boolean; ruleName: string; browserName: string } | null | undefined = undefined;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

async function init() {
  try {
    appState = await settingsRpc.request.getState();
    render();
  } catch (err) {
    document.getElementById("root")!.innerHTML = `
      <div style="padding:24px;color:#ff453a">
        Failed to load settings: ${String(err)}
      </div>`;
  }
}

// ---------------------------------------------------------------------------
// Main render
// ---------------------------------------------------------------------------

function render() {
  if (!appState) return;

  const { browsers, rules, hasCompletedOnboarding } = appState;

  document.getElementById("root")!.innerHTML = `
    <div class="layout">
      <nav class="sidebar">
        <div class="sidebar-item${activeTab === "browsers" ? " active" : ""}" data-tab="browsers">
          <span class="sidebar-icon">🌐</span> Browsers
        </div>
        <div class="sidebar-item${activeTab === "rules" ? " active" : ""}" data-tab="rules">
          <span class="sidebar-icon">📋</span> Rules
        </div>
        <div class="sidebar-item${activeTab === "apps" ? " active" : ""}" data-tab="apps">
          <span class="sidebar-icon">🙈</span> Hidden Apps
        </div>
        <div class="sidebar-item${activeTab === "general" ? " active" : ""}" data-tab="general">
          <span class="sidebar-icon">⚙️</span> General
        </div>
      </nav>

      <main class="content">
        ${!hasCompletedOnboarding ? onboardingBannerHTML() : ""}

        <div class="tab-panel${activeTab === "browsers" ? " active" : ""}" id="tab-browsers">
          ${renderBrowsersTab(browsers, appState.installedBrowsers)}
        </div>
        <div class="tab-panel${activeTab === "rules" ? " active" : ""}" id="tab-rules">
          ${renderRulesTab(rules, browsers)}
        </div>
        <div class="tab-panel${activeTab === "apps" ? " active" : ""}" id="tab-apps">
          ${renderAppsTab(appState.hiddenAppIds)}
        </div>
        <div class="tab-panel${activeTab === "general" ? " active" : ""}" id="tab-general">
          ${renderGeneralTab()}
        </div>
      </main>
    </div>`;

  setupEventListeners();
}

// ---------------------------------------------------------------------------
// Onboarding banner
// ---------------------------------------------------------------------------

function onboardingBannerHTML(): string {
  return `
    <div class="onboarding-banner">
      <div class="onboarding-banner-icon">👋</div>
      <div class="onboarding-banner-body">
        <h3>Welcome to Chowser!</h3>
        <p>To intercept links, set Chowser as your default browser in macOS System Settings → Desktop &amp; Dock → Default web browser.</p>
        <div style="display:flex;gap:8px">
          <button class="btn btn-primary" id="openDefaultBrowserSettings">Open System Settings</button>
          <button class="btn btn-ghost" id="dismissOnboarding">Got it</button>
        </div>
      </div>
    </div>`;
}

// ---------------------------------------------------------------------------
// Browsers tab
// ---------------------------------------------------------------------------

function browserEmoji(name: string): string {
  const lower = name.toLowerCase();
  if (lower.includes("chrome")) return "🔵";
  if (lower.includes("firefox") || lower.includes("fox")) return "🦊";
  if (lower.includes("safari")) return "🧭";
  if (lower.includes("brave")) return "🦁";
  if (lower.includes("edge")) return "🌀";
  if (lower.includes("opera")) return "🔴";
  if (lower.includes("arc")) return "🌈";
  if (lower.includes("vivaldi")) return "🎻";
  if (lower.includes("zen")) return "🧘";
  return "🌐";
}

function renderBrowsersTab(
  browsers: BrowserConfig[],
  installed: InstalledBrowser[]
): string {
  const browsersHTML =
    browsers.length === 0
      ? `<div class="empty-state">
           <div class="empty-state-icon">🌐</div>
           <div>No browsers configured</div>
           <div style="font-size:11px">Add a browser to get started</div>
         </div>`
      : browsers
          .map(
            (b) =>
              `<div class="list-item" data-browser-id="${esc(b.id)}">
                <div class="list-item-icon">${browserEmoji(b.name)}</div>
                <div class="list-item-body">
                  <div class="list-item-title">${esc(b.name)}</div>
                  <div class="list-item-subtitle">
                    ${esc(b.appId)}${b.profile ? ` · ${esc(b.profile)}` : ""}
                    · shortcut: <strong>${esc(b.shortcutKey)}</strong>
                    ${b.customArguments ? ` · args: <code>${esc(b.customArguments)}</code>` : ""}
                  </div>
                </div>
                <div class="list-item-actions">
                  <button class="btn btn-ghost btn-sm edit-browser-btn" data-browser-id="${esc(b.id)}">Edit</button>
                  <button class="btn btn-danger btn-sm remove-browser-btn" data-browser-id="${esc(b.id)}">Remove</button>
                </div>
              </div>`
          )
          .join("");

  const installedCount = installed.length;
  return `
    <div class="section-header">
      <h2>Browsers</h2>
      <div style="display:flex;gap:8px">
        <button class="btn btn-ghost" id="detectBrowsersBtn">🔍 Detect${installedCount > 0 ? ` (${installedCount})` : ""}</button>
        <button class="btn btn-primary" id="addBrowserBtn">＋ Add Browser</button>
      </div>
    </div>
    <p style="font-size:12px;color:var(--text-secondary);margin-bottom:14px">
      Shortcut keys (1–9) let you quickly pick a browser from the picker.
      Drag to reorder (coming soon).
    </p>
    <div class="card">${browsersHTML}</div>`;
}

// ---------------------------------------------------------------------------
// Rules tab
// ---------------------------------------------------------------------------

function renderRulesTab(
  rules: BrowserRoutingRule[],
  browsers: BrowserConfig[]
): string {
  const browserName = (appId: string) =>
    browsers.find((b) => b.appId === appId)?.name ?? appId;

  const rulesHTML =
    rules.length === 0
      ? `<div class="empty-state">
           <div class="empty-state-icon">📋</div>
           <div>No routing rules</div>
           <div style="font-size:11px">Rules let you automatically open URLs in a specific browser</div>
         </div>`
      : rules
          .map(
            (r, i) =>
              `<div class="list-item" data-rule-id="${esc(r.id)}">
                <span class="rule-priority">${i + 1}</span>
                <div class="list-item-body">
                  <div class="list-item-title">
                    ${esc(r.name)}
                    <span class="tag ${r.isEnabled ? "enabled" : "disabled"}" style="margin-left:6px">
                      ${r.isEnabled ? "on" : "off"}
                    </span>
                    ${r.usePrivateMode ? `<span class="tag" style="margin-left:4px;color:#bf5af2">private</span>` : ""}
                    ${r.useRegex ? `<span class="tag" style="margin-left:4px">regex</span>` : ""}
                  </div>
                  <div class="list-item-subtitle">
                    ${esc(r.hostPattern)}${r.pathPrefix ? ` · path: ${esc(r.pathPrefix)}` : ""}
                    → ${esc(browserName(r.browserAppId))}${r.profile ? ` (${esc(r.profile)})` : ""}
                    ${r.sourceAppBundleId ? ` · from ${esc(r.sourceAppBundleId)}` : ""}
                  </div>
                </div>
                <div class="list-item-actions">
                  <button class="btn btn-ghost btn-sm toggle-rule-btn" data-rule-id="${esc(r.id)}" data-enabled="${r.isEnabled}">
                    ${r.isEnabled ? "Disable" : "Enable"}
                  </button>
                  <button class="btn btn-ghost btn-sm edit-rule-btn" data-rule-id="${esc(r.id)}">Edit</button>
                  <button class="btn btn-ghost btn-sm duplicate-rule-btn" data-rule-id="${esc(r.id)}">Copy</button>
                  <button class="btn btn-danger btn-sm remove-rule-btn" data-rule-id="${esc(r.id)}">Remove</button>
                </div>
              </div>`
          )
          .join("");

  const testResultHTML =
    ruleTestResult === undefined
      ? ""
      : ruleTestResult === null
        ? `<div class="rule-test-result miss">No rule matched — picker would show</div>`
        : `<div class="rule-test-result hit">✓ Matched: <strong>${esc(ruleTestResult.ruleName)}</strong> → ${esc(ruleTestResult.browserName)}</div>`;

  return `
    <div class="section-header">
      <h2>Routing Rules</h2>
      <button class="btn btn-primary" id="addRuleBtn">＋ Add Rule</button>
    </div>
    <p style="font-size:12px;color:var(--text-secondary);margin-bottom:14px">
      Rules are checked top-to-bottom. The first match wins.
    </p>

    <div class="rule-tester card" style="margin-bottom:16px">
      <div class="list-item" style="gap:8px">
        <input type="url" id="ruleTestInput" placeholder="Test a URL, e.g. https://github.com/…" style="flex:1;min-width:0" />
        <button class="btn btn-ghost" id="ruleTestBtn">Test</button>
      </div>
      ${testResultHTML ? `<div style="padding:8px 14px;border-top:1px solid var(--border)">${testResultHTML}</div>` : ""}
    </div>

    <div class="card">${rulesHTML}</div>`;
}

// ---------------------------------------------------------------------------
// Hidden Apps tab
// ---------------------------------------------------------------------------

function renderAppsTab(hiddenAppIds: string[]): string {
  const rows = hiddenAppIds
    .map(
      (id) =>
        `<div class="list-item" data-app-id="${esc(id)}">
          <div class="list-item-body">
            <div class="list-item-title" style="font-family:monospace;font-size:12.5px">${esc(id)}</div>
          </div>
          <div class="list-item-actions">
            <button class="btn btn-danger btn-sm remove-hidden-app-btn" data-app-id="${esc(id)}">Unhide</button>
          </div>
        </div>`
    )
    .join("");

  return `
    <div class="section-header">
      <h2>Hidden Apps</h2>
    </div>
    <p style="font-size:12px;color:var(--text-secondary);margin-bottom:14px">
      Apps listed here won't appear in the browser picker. Add apps that handle
      URLs but aren't real browsers (e.g. media players, communication apps).
    </p>
    <div style="display:flex;gap:8px;margin-bottom:14px">
      <input type="text" id="newHiddenAppInput" placeholder="Bundle ID, e.g. org.videolan.vlc" style="flex:1" />
      <button class="btn btn-primary" id="addHiddenAppBtn">Hide App</button>
    </div>
    <div class="card" style="margin-bottom:12px">
      ${rows || `<div class="empty-state" style="padding:20px"><div>No hidden apps configured</div></div>`}
    </div>
    <button class="btn btn-ghost btn-sm" id="resetHiddenAppsBtn">Reset to defaults</button>`;
}

// ---------------------------------------------------------------------------
// General tab
// ---------------------------------------------------------------------------

function renderGeneralTab(): string {
  if (!appState) return "";

  const { pickerLayout, focusMode, mcpStatus, browsers } = appState;

  const focusModeSection = () => {
    if (focusMode) {
      const browser = browsers.find((b) => b.id === focusMode.browserId);
      const browserName = browser?.name ?? "Unknown";
      const expText =
        focusMode.expiresAt === null
          ? "Until quit"
          : `Until ${new Date(focusMode.expiresAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
      return `<div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">🎯 Focus Mode Active</div>
          <div class="list-item-subtitle">All URLs → ${esc(browserName)} · ${esc(expText)}</div>
        </div>
        <button class="btn btn-ghost" id="clearFocusModeBtn">Clear</button>
      </div>`;
    }

    if (browsers.length === 0) {
      return `<div class="list-item"><div class="list-item-body"><div class="list-item-subtitle">Add a browser first to use Focus Mode</div></div></div>`;
    }

    const browserOptions = browsers
      .map(
        (b) =>
          `<option value="${esc(b.id)}">${esc(b.name)}${b.profile ? ` (${esc(b.profile)})` : ""}</option>`
      )
      .join("");

    return `<div class="list-item" style="flex-wrap:wrap;gap:8px">
      <div class="list-item-body">
        <div class="list-item-title">Focus Mode</div>
        <div class="list-item-subtitle">Route all URLs to one browser temporarily</div>
      </div>
      <div style="display:flex;gap:6px;align-items:center;flex-shrink:0">
        <select id="focusBrowserSelect">${browserOptions}</select>
        <select id="focusDurationSelect">
          <option value="60">1 hour</option>
          <option value="120">2 hours</option>
          <option value="480">8 hours (work day)</option>
          <option value="">Until quit</option>
        </select>
        <button class="btn btn-primary" id="setFocusModeBtn">Start</button>
      </div>
    </div>`;
  };

  return `
    <h2>General</h2>

    <h3 style="margin-top:0">Default Browser</h3>
    <div class="card">
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">Set Chowser as Default Browser</div>
          <div class="list-item-subtitle">Opens macOS System Settings → Desktop &amp; Dock</div>
        </div>
        <button class="btn btn-primary" id="setDefaultBrowserBtn">Open Settings</button>
      </div>
    </div>

    <h3>Picker Appearance</h3>
    <div class="card">
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">Layout</div>
          <div class="list-item-subtitle">Icons (horizontal) or List (vertical)</div>
        </div>
        <div style="display:flex;gap:6px">
          <button class="btn${pickerLayout === "icons" ? " btn-primary" : " btn-ghost"}" id="layoutIconsBtn">Icons</button>
          <button class="btn${pickerLayout === "list" ? " btn-primary" : " btn-ghost"}" id="layoutListBtn">List</button>
        </div>
      </div>
    </div>

    <h3>Focus Mode</h3>
    <div class="card">
      ${focusModeSection()}
    </div>

    <h3>API Server (MCP)</h3>
    <div class="card">
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">
            Local REST API on port ${esc(String(mcpStatus.port))}
            ${mcpStatus.running ? `<span class="tag enabled" style="margin-left:6px">running</span>` : `<span class="tag disabled" style="margin-left:6px">stopped</span>`}
          </div>
          <div class="list-item-subtitle">
            ${mcpStatus.running && mcpStatus.token ? `Token: <code>${esc(mcpStatus.token)}</code>` : "Start the server to get an auth token"}
          </div>
        </div>
        <button class="btn btn-ghost" id="toggleMcpBtn">${mcpStatus.running ? "Stop" : "Start"} Server</button>
      </div>
    </div>

    <h3>Import / Export</h3>
    <div class="card">
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">Export Configuration</div>
          <div class="list-item-subtitle">JSON backup of your browsers and rules</div>
        </div>
        <button class="btn btn-ghost" id="exportBtn">Export</button>
      </div>
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">Import Configuration</div>
          <div class="list-item-subtitle">Merge browsers and rules from JSON</div>
        </div>
        <button class="btn btn-ghost" id="importBtn">Import</button>
      </div>
    </div>

    <h3>About</h3>
    <div class="card">
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">Chowser</div>
          <div class="list-item-subtitle">Built with Electrobun · v0.1.0</div>
        </div>
      </div>
    </div>

    <h3>Danger Zone</h3>
    <div class="card">
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title" style="color:var(--destructive)">Reset to Defaults</div>
          <div class="list-item-subtitle">Removes all browsers, rules, and recent URLs</div>
        </div>
        <button class="btn btn-danger" id="resetDefaultsBtn">Reset</button>
      </div>
    </div>`;
}

// ---------------------------------------------------------------------------
// Event listeners
// ---------------------------------------------------------------------------

function setupEventListeners() {
  // Tab switching
  document.querySelectorAll(".sidebar-item[data-tab]").forEach((el) => {
    el.addEventListener("click", () => {
      activeTab = (el as HTMLElement).dataset["tab"] as typeof activeTab;
      ruleTestResult = undefined;
      render();
    });
  });

  // Onboarding
  document
    .getElementById("openDefaultBrowserSettings")
    ?.addEventListener("click", openSystemPreferences);
  document
    .getElementById("dismissOnboarding")
    ?.addEventListener("click", () => {
      settingsRpc.request.completeOnboarding().then(() => {
        if (appState) appState.hasCompletedOnboarding = true;
        render();
      });
    });

  // Browsers tab
  document
    .getElementById("addBrowserBtn")
    ?.addEventListener("click", showAddBrowserModal);
  document
    .getElementById("detectBrowsersBtn")
    ?.addEventListener("click", detectBrowsers);
  document.querySelectorAll(".edit-browser-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["browserId"]!;
      showEditBrowserModal(id);
    });
  });
  document.querySelectorAll(".remove-browser-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["browserId"]!;
      removeBrowser(id);
    });
  });

  // Rules tab
  document
    .getElementById("addRuleBtn")
    ?.addEventListener("click", showAddRuleModal);
  document.querySelectorAll(".edit-rule-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["ruleId"]!;
      showEditRuleModal(id);
    });
  });
  document.querySelectorAll(".duplicate-rule-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["ruleId"]!;
      duplicateRule(id);
    });
  });
  document.querySelectorAll(".remove-rule-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["ruleId"]!;
      removeRule(id);
    });
  });
  document.querySelectorAll(".toggle-rule-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["ruleId"]!;
      const enabled = (btn as HTMLElement).dataset["enabled"] === "true";
      toggleRule(id, !enabled);
    });
  });
  document.getElementById("ruleTestBtn")?.addEventListener("click", testRule);
  document
    .getElementById("ruleTestInput")
    ?.addEventListener("keydown", (e: Event) => {
      if ((e as KeyboardEvent).key === "Enter") testRule();
    });

  // Hidden Apps tab
  document
    .getElementById("addHiddenAppBtn")
    ?.addEventListener("click", addHiddenApp);
  document
    .getElementById("newHiddenAppInput")
    ?.addEventListener("keydown", (e: Event) => {
      if ((e as KeyboardEvent).key === "Enter") addHiddenApp();
    });
  document.querySelectorAll(".remove-hidden-app-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["appId"]!;
      removeHiddenApp(id);
    });
  });
  document
    .getElementById("resetHiddenAppsBtn")
    ?.addEventListener("click", resetHiddenApps);

  // General tab
  document
    .getElementById("setDefaultBrowserBtn")
    ?.addEventListener("click", openSystemPreferences);
  document
    .getElementById("exportBtn")
    ?.addEventListener("click", exportConfig);
  document
    .getElementById("importBtn")
    ?.addEventListener("click", showImportModal);
  document
    .getElementById("layoutIconsBtn")
    ?.addEventListener("click", () => setPickerLayout("icons"));
  document
    .getElementById("layoutListBtn")
    ?.addEventListener("click", () => setPickerLayout("list"));
  document
    .getElementById("setFocusModeBtn")
    ?.addEventListener("click", setFocusMode);
  document
    .getElementById("clearFocusModeBtn")
    ?.addEventListener("click", clearFocusMode);
  document
    .getElementById("toggleMcpBtn")
    ?.addEventListener("click", toggleMcpServer);
  document
    .getElementById("resetDefaultsBtn")
    ?.addEventListener("click", resetToDefaults);
}

// ---------------------------------------------------------------------------
// Browser actions
// ---------------------------------------------------------------------------

async function removeBrowser(id: string) {
  if (!confirm("Remove this browser? Rules using it will no longer match."))
    return;
  await settingsRpc.request.removeBrowser({ id });
  await refreshState();
}

async function detectBrowsers() {
  const installed = await settingsRpc.request.detectBrowsers();
  if (appState) appState.installedBrowsers = installed;
  showDetectedBrowsersModal(installed);
}

function showAddBrowserModal() {
  const installed = appState?.installedBrowsers ?? [];
  const installedOptions = installed
    .flatMap((b) => {
      const base = `<option value="${esc(b.appId)}" data-name="${esc(b.name)}">${esc(b.name)} (${esc(b.appId)})</option>`;
      const profileOptions = b.profiles.map(
        (p) =>
          `<option value="${esc(b.appId)}" data-name="${esc(b.name)} — ${esc(p.name)}" data-profile="${esc(p.directory)}">
              ${esc(b.name)} — ${esc(p.name)}
            </option>`
      );
      return [base, ...profileOptions];
    })
    .join("");

  showModal(`
    <h3>Add Browser</h3>
    <div class="form-group">
      <label class="form-label">Detected Browsers</label>
      <select id="detectedBrowserSelect">
        <option value="">— Select a detected browser —</option>
        ${installedOptions}
      </select>
    </div>
    <div class="form-group">
      <label class="form-label">Name</label>
      <input type="text" id="browserName" placeholder="e.g. Chrome Work" />
    </div>
    <div class="form-group">
      <label class="form-label">Bundle ID / App ID</label>
      <input type="text" id="browserAppId" placeholder="e.g. com.google.Chrome" />
    </div>
    <div class="form-group">
      <label class="form-label">Profile (optional)</label>
      <input type="text" id="browserProfile" placeholder="e.g. Default or Profile 1" />
    </div>
    <div class="form-group">
      <label class="form-label">Shortcut Key (1–9)</label>
      <input type="text" id="browserShortcut" maxlength="1" placeholder="auto" />
    </div>
    <div class="form-group">
      <label class="form-label">Custom Arguments (optional)</label>
      <input type="text" id="browserArgs" placeholder="e.g. --disable-extensions" />
    </div>
    <div class="modal-actions">
      <button class="btn btn-ghost" id="cancelModal">Cancel</button>
      <button class="btn btn-primary" id="confirmAddBrowser">Add</button>
    </div>
  `);

  document
    .getElementById("detectedBrowserSelect")!
    .addEventListener("change", (e) => {
      const select = e.target as HTMLSelectElement;
      const opt = select.selectedOptions[0];
      if (!opt || !opt.value) return;
      (document.getElementById("browserName") as HTMLInputElement).value =
        opt.dataset["name"] ?? "";
      (document.getElementById("browserAppId") as HTMLInputElement).value =
        opt.value;
      (document.getElementById("browserProfile") as HTMLInputElement).value =
        opt.dataset["profile"] ?? "";
      const usedShortcuts = new Set(
        (appState?.browsers ?? []).map((b) => b.shortcutKey)
      );
      for (const k of ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) {
        if (!usedShortcuts.has(k)) {
          (
            document.getElementById("browserShortcut") as HTMLInputElement
          ).value = k;
          break;
        }
      }
    });

  document
    .getElementById("confirmAddBrowser")!
    .addEventListener("click", async () => {
      const name = (
        document.getElementById("browserName") as HTMLInputElement
      ).value.trim();
      const appId = (
        document.getElementById("browserAppId") as HTMLInputElement
      ).value.trim();
      const profile =
        (
          document.getElementById("browserProfile") as HTMLInputElement
        ).value.trim() || undefined;
      const shortcutKey =
        (
          document.getElementById("browserShortcut") as HTMLInputElement
        ).value.trim() || "9";
      const customArguments =
        (
          document.getElementById("browserArgs") as HTMLInputElement
        ).value.trim() || undefined;

      if (!name || !appId) {
        alert("Name and Bundle ID are required.");
        return;
      }

      await settingsRpc.request.addBrowser({
        id: crypto.randomUUID(),
        name,
        appId,
        shortcutKey,
        profile,
        customArguments,
      });
      closeModal();
      await refreshState();
    });
}

function showEditBrowserModal(id: string) {
  const browser = appState?.browsers.find((b) => b.id === id);
  if (!browser) return;

  showModal(`
    <h3>Edit Browser</h3>
    <div class="form-group">
      <label class="form-label">Name</label>
      <input type="text" id="editBrowserName" value="${esc(browser.name)}" />
    </div>
    <div class="form-group">
      <label class="form-label">Bundle ID / App ID</label>
      <input type="text" id="editBrowserAppId" value="${esc(browser.appId)}" />
    </div>
    <div class="form-group">
      <label class="form-label">Profile (optional)</label>
      <input type="text" id="editBrowserProfile" value="${esc(browser.profile ?? "")}" placeholder="e.g. Default or Profile 1" />
    </div>
    <div class="form-group">
      <label class="form-label">Shortcut Key (1–9)</label>
      <input type="text" id="editBrowserShortcut" maxlength="1" value="${esc(browser.shortcutKey)}" />
    </div>
    <div class="form-group">
      <label class="form-label">Custom Arguments (optional)</label>
      <input type="text" id="editBrowserArgs" value="${esc(browser.customArguments ?? "")}" placeholder="e.g. --disable-extensions" />
    </div>
    <div class="modal-actions">
      <button class="btn btn-ghost" id="cancelModal">Cancel</button>
      <button class="btn btn-primary" id="confirmEditBrowser">Save</button>
    </div>
  `);

  document
    .getElementById("confirmEditBrowser")!
    .addEventListener("click", async () => {
      const name = (
        document.getElementById("editBrowserName") as HTMLInputElement
      ).value.trim();
      const appId = (
        document.getElementById("editBrowserAppId") as HTMLInputElement
      ).value.trim();
      const profile =
        (
          document.getElementById("editBrowserProfile") as HTMLInputElement
        ).value.trim() || undefined;
      const shortcutKey =
        (
          document.getElementById("editBrowserShortcut") as HTMLInputElement
        ).value.trim() || browser.shortcutKey;
      const customArguments =
        (
          document.getElementById("editBrowserArgs") as HTMLInputElement
        ).value.trim() || undefined;

      if (!name || !appId) {
        alert("Name and Bundle ID are required.");
        return;
      }

      await settingsRpc.request.updateBrowser({
        ...browser,
        name,
        appId,
        shortcutKey,
        profile,
        customArguments,
      });
      closeModal();
      await refreshState();
    });
}

function showDetectedBrowsersModal(installed: InstalledBrowser[]) {
  if (installed.length === 0) {
    showModal(`
      <h3>Detected Browsers</h3>
      <p style="color:var(--text-secondary);font-size:13px">No additional browsers detected.</p>
      <div class="modal-actions">
        <button class="btn btn-primary" id="cancelModal">Close</button>
      </div>
    `);
    return;
  }

  const rows = installed
    .map(
      (b) =>
        `<div class="list-item">
           <div class="list-item-icon">${browserEmoji(b.name)}</div>
           <div class="list-item-body">
             <div class="list-item-title">${esc(b.name)}</div>
             <div class="list-item-subtitle">${esc(b.appId)}${b.profiles.length > 0 ? ` · ${b.profiles.length} profile(s)` : ""}</div>
           </div>
           <button class="btn btn-ghost btn-sm add-detected-browser-btn"
             data-app-id="${esc(b.appId)}"
             data-name="${esc(b.name)}">Add</button>
         </div>`
    )
    .join("");

  showModal(`
    <h3>Detected Browsers (${installed.length})</h3>
    <div class="card" style="max-height:300px;overflow-y:auto">${rows}</div>
    <div class="modal-actions">
      <button class="btn btn-primary" id="cancelModal">Close</button>
    </div>
  `);

  document.querySelectorAll(".add-detected-browser-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const appId = (btn as HTMLElement).dataset["appId"]!;
      const name = (btn as HTMLElement).dataset["name"]!;
      const existing = appState?.browsers ?? [];
      const usedShortcuts = new Set(existing.map((b) => b.shortcutKey));
      let shortcutKey = "9";
      for (const k of ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) {
        if (!usedShortcuts.has(k)) {
          shortcutKey = k;
          break;
        }
      }
      if (existing.some((b) => b.appId === appId && !b.profile)) {
        alert(`${name} is already in your browser list.`);
        return;
      }
      await settingsRpc.request.addBrowser({
        id: crypto.randomUUID(),
        name,
        appId,
        shortcutKey,
      });
      await refreshState();
      btn.textContent = "Added ✓";
      (btn as HTMLButtonElement).disabled = true;
    });
  });
}

// ---------------------------------------------------------------------------
// Rule actions
// ---------------------------------------------------------------------------

async function removeRule(id: string) {
  await settingsRpc.request.removeRule({ id });
  await refreshState();
}

async function duplicateRule(id: string) {
  await settingsRpc.request.duplicateRule({ id });
  await refreshState();
}

async function toggleRule(id: string, enabled: boolean) {
  if (!appState) return;
  const updated = appState.rules.map((r) =>
    r.id === id ? { ...r, isEnabled: enabled } : r
  );
  await settingsRpc.request.saveRules({ rules: updated });
  await refreshState();
}

async function testRule() {
  const input = document.getElementById("ruleTestInput") as HTMLInputElement;
  const url = input.value.trim();
  if (!url) return;
  const result = await settingsRpc.request.testUrl({ url });
  ruleTestResult = result;
  // Re-render just the rules tab content
  const panel = document.getElementById("tab-rules");
  if (panel && appState) {
    panel.innerHTML = renderRulesTab(appState.rules, appState.browsers);
    // Re-attach rule tab event listeners
    document
      .getElementById("addRuleBtn")
      ?.addEventListener("click", showAddRuleModal);
    document.querySelectorAll(".edit-rule-btn").forEach((btn) => {
      btn.addEventListener("click", () =>
        showEditRuleModal((btn as HTMLElement).dataset["ruleId"]!)
      );
    });
    document.querySelectorAll(".duplicate-rule-btn").forEach((btn) => {
      btn.addEventListener("click", () =>
        duplicateRule((btn as HTMLElement).dataset["ruleId"]!)
      );
    });
    document.querySelectorAll(".remove-rule-btn").forEach((btn) => {
      btn.addEventListener("click", () =>
        removeRule((btn as HTMLElement).dataset["ruleId"]!)
      );
    });
    document.querySelectorAll(".toggle-rule-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        const id = (btn as HTMLElement).dataset["ruleId"]!;
        const enabled = (btn as HTMLElement).dataset["enabled"] === "true";
        toggleRule(id, !enabled);
      });
    });
    document.getElementById("ruleTestBtn")?.addEventListener("click", testRule);
    document
      .getElementById("ruleTestInput")
      ?.addEventListener("keydown", (e: Event) => {
        if ((e as KeyboardEvent).key === "Enter") testRule();
      });
    const ti = document.getElementById("ruleTestInput") as HTMLInputElement;
    if (ti) ti.value = url;
  }
}

function showAddRuleModal() {
  const browsers = appState?.browsers ?? [];
  // Use browser config `id` as the option value so we can uniquely identify
  // entries that share the same appId but have different profiles.
  const browserOptions = browsers
    .map(
      (b) =>
        `<option value="${esc(b.id)}">${esc(b.name)}${b.profile ? ` (${esc(b.profile)})` : ""}</option>`
    )
    .join("");

  showModal(buildRuleForm(null, browsers, browserOptions));

  document
    .getElementById("confirmSaveRule")!
    .addEventListener("click", async () => {
      const rule = collectRuleForm(null);
      if (!rule) return;
      await settingsRpc.request.addRule(rule);
      closeModal();
      await refreshState();
    });
}

function showEditRuleModal(id: string) {
  const rule = appState?.rules.find((r) => r.id === id);
  if (!rule) return;
  const browsers = appState?.browsers ?? [];
  // Use browser config `id` as the option value; select the entry whose
  // appId AND profile both match the rule.
  const browserOptions = browsers
    .map(
      (b) =>
        `<option value="${esc(b.id)}"${
          b.appId === rule.browserAppId &&
          (b.profile ?? "") === (rule.profile ?? "")
            ? " selected"
            : ""
        }>${esc(b.name)}${b.profile ? ` (${esc(b.profile)})` : ""}</option>`
    )
    .join("");

  showModal(buildRuleForm(rule, browsers, browserOptions));

  document
    .getElementById("confirmSaveRule")!
    .addEventListener("click", async () => {
      const updated = collectRuleForm(id);
      if (!updated) return;
      await settingsRpc.request.updateRule(updated);
      closeModal();
      await refreshState();
    });
}

function buildRuleForm(
  rule: BrowserRoutingRule | null,
  _browsers: BrowserConfig[],
  browserOptions: string
): string {
  const r = rule ?? ({} as Partial<BrowserRoutingRule>);
  return `
    <h3>${rule ? "Edit" : "Add"} Routing Rule</h3>
    <div class="form-group">
      <label class="form-label">Rule Name</label>
      <input type="text" id="ruleName" value="${esc(r.name ?? "")}" placeholder="e.g. GitHub in Chrome" />
    </div>
    <div class="form-group">
      <label class="form-label">Host Pattern</label>
      <input type="text" id="ruleHostPattern" value="${esc(r.hostPattern ?? "")}" placeholder="e.g. *.github.com or github.com" />
    </div>
    <div class="form-group">
      <label class="form-label">Path Prefix (optional)</label>
      <input type="text" id="rulePathPrefix" value="${esc(r.pathPrefix ?? "")}" placeholder="e.g. /work" />
    </div>
    <div class="form-group">
      <label class="form-label">Open In Browser</label>
      <select id="ruleBrowserSelect">${browserOptions}</select>
    </div>
    <div class="form-group">
      <label class="form-label">Source App Bundle ID (optional)</label>
      <input type="text" id="ruleSourceApp" value="${esc(r.sourceAppBundleId ?? "")}" placeholder="e.g. com.tinyspeck.slackmacgap" />
    </div>
    <div class="form-group">
      <label style="display:flex;align-items:center;gap:8px;cursor:pointer">
        <input type="checkbox" id="rulePrivate" ${r.usePrivateMode ? "checked" : ""} />
        <span>Open in private/incognito mode</span>
      </label>
    </div>
    <div class="form-group">
      <label style="display:flex;align-items:center;gap:8px;cursor:pointer">
        <input type="checkbox" id="ruleRegex" ${r.useRegex ? "checked" : ""} />
        <span>Use regex for host pattern</span>
      </label>
    </div>
    <div class="modal-actions">
      <button class="btn btn-ghost" id="cancelModal">Cancel</button>
      <button class="btn btn-primary" id="confirmSaveRule">${rule ? "Save" : "Add Rule"}</button>
    </div>
  `;
}

function collectRuleForm(existingId: string | null): BrowserRoutingRule | null {
  const name = (
    document.getElementById("ruleName") as HTMLInputElement
  ).value.trim();
  const hostPattern = (
    document.getElementById("ruleHostPattern") as HTMLInputElement
  ).value.trim();
  const pathPrefix =
    (
      document.getElementById("rulePathPrefix") as HTMLInputElement
    ).value.trim() || undefined;
  // The select stores browser config IDs (UUIDs) so we can distinguish multiple
  // entries with the same bundle ID (e.g. different Chrome profiles).
  const selectedBrowserConfigId = (
    document.getElementById("ruleBrowserSelect") as HTMLSelectElement
  ).value;
  const selectedBrowser = (appState?.browsers ?? []).find(
    (b) => b.id === selectedBrowserConfigId
  );
  const browserAppId = selectedBrowser?.appId ?? selectedBrowserConfigId;
  const profile = selectedBrowser?.profile;
  const sourceAppBundleId =
    (
      document.getElementById("ruleSourceApp") as HTMLInputElement
    ).value.trim() || undefined;
  const usePrivateMode = (
    document.getElementById("rulePrivate") as HTMLInputElement
  ).checked;
  const useRegex = (
    document.getElementById("ruleRegex") as HTMLInputElement
  ).checked;

  if (!name || !hostPattern) {
    alert("Name and host pattern are required.");
    return null;
  }

  const existingRule = existingId
    ? appState?.rules.find((r) => r.id === existingId)
    : null;

  return {
    id: existingId ?? crypto.randomUUID(),
    name,
    hostPattern,
    pathPrefix,
    browserAppId,
    profile,
    sourceAppBundleId,
    isEnabled: existingRule?.isEnabled ?? true,
    usePrivateMode,
    useRegex,
  };
}

// ---------------------------------------------------------------------------
// Hidden Apps actions
// ---------------------------------------------------------------------------

async function addHiddenApp() {
  const input = document.getElementById(
    "newHiddenAppInput"
  ) as HTMLInputElement;
  const id = input.value.trim();
  if (!id) return;
  const existing = appState?.hiddenAppIds ?? [];
  if (existing.includes(id)) {
    alert("This app is already hidden.");
    return;
  }
  await settingsRpc.request.setHiddenApps({ ids: [...existing, id] });
  await refreshState();
}

async function removeHiddenApp(id: string) {
  const existing = appState?.hiddenAppIds ?? [];
  await settingsRpc.request.setHiddenApps({
    ids: existing.filter((x) => x !== id),
  });
  await refreshState();
}

async function resetHiddenApps() {
  const defaults = [
    "com.colliderli.iina",
    "org.videolan.vlc",
    "io.mpv",
    "com.apple.QuickTimePlayerX",
    "net.mxvideoplayer.mac.MX-Video-Player-Pro",
    "com.apple.TV",
    "com.apple.Music",
  ];
  await settingsRpc.request.setHiddenApps({ ids: defaults });
  await refreshState();
}

// ---------------------------------------------------------------------------
// General tab actions
// ---------------------------------------------------------------------------

async function setPickerLayout(layout: PickerLayout) {
  await settingsRpc.request.setPickerLayout({ layout });
  if (appState) appState.pickerLayout = layout;
  render();
}

async function setFocusMode() {
  const browserId = (
    document.getElementById("focusBrowserSelect") as HTMLSelectElement
  )?.value;
  const durationStr = (
    document.getElementById("focusDurationSelect") as HTMLSelectElement
  )?.value;
  if (!browserId) return;
  const durationMinutes = durationStr ? parseInt(durationStr, 10) : null;
  await settingsRpc.request.setFocusMode({ browserId, durationMinutes });
  await refreshState();
}

async function clearFocusMode() {
  await settingsRpc.request.clearFocusMode();
  await refreshState();
}

async function toggleMcpServer() {
  const status = await settingsRpc.request.toggleMcpServer();
  if (appState) appState.mcpStatus = status;
  render();
}

async function resetToDefaults() {
  if (
    !confirm(
      "This will remove all browsers, rules, and recent URLs and reset to factory defaults. Are you sure?"
    )
  )
    return;
  await settingsRpc.request.resetToDefaults();
  await refreshState();
}

async function exportConfig() {
  const json = await settingsRpc.request.exportConfig();
  showModal(`
    <h3>Export Configuration</h3>
    <p style="font-size:12px;color:var(--text-secondary);margin-bottom:8px">Copy this JSON to back up your configuration:</p>
    <textarea id="exportJson" readonly>${esc(json)}</textarea>
    <div class="modal-actions">
      <button class="btn btn-ghost" id="copyExportBtn">Copy to Clipboard</button>
      <button class="btn btn-primary" id="cancelModal">Close</button>
    </div>
  `);
  const ta = document.getElementById("exportJson") as HTMLTextAreaElement;
  ta.select();
  document.getElementById("copyExportBtn")?.addEventListener("click", () => {
    navigator.clipboard.writeText(json).catch(() => {});
    const btn = document.getElementById("copyExportBtn")!;
    btn.textContent = "Copied ✓";
  });
}

function showImportModal() {
  showModal(`
    <h3>Import Configuration</h3>
    <p style="font-size:12px;color:var(--text-secondary);margin-bottom:8px">Paste your exported JSON below (browsers and rules will be merged):</p>
    <textarea id="importJson" placeholder='{"browsers":[...],"rules":[]}'></textarea>
    <div id="importMessage" style="font-size:12px;margin-top:6px;min-height:16px"></div>
    <div class="modal-actions">
      <button class="btn btn-ghost" id="cancelModal">Cancel</button>
      <button class="btn btn-primary" id="confirmImport">Import</button>
    </div>
  `);

  document
    .getElementById("confirmImport")!
    .addEventListener("click", async () => {
      const json = (
        document.getElementById("importJson") as HTMLTextAreaElement
      ).value;
      const result = await settingsRpc.request.importConfig({ json });
      const msgEl = document.getElementById("importMessage")!;
      msgEl.style.color = result.success ? "#30d158" : "#ff453a";
      msgEl.textContent = result.message;
      if (result.success) {
        await refreshState();
        setTimeout(closeModal, 1000);
      }
    });
}

function openSystemPreferences() {
  window.location.href =
    "x-apple.systempreferences:com.apple.preferences.generalIn";
}

// ---------------------------------------------------------------------------
// Modal helpers
// ---------------------------------------------------------------------------

function showModal(html: string) {
  closeModal();
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal">${html}</div>`;
  document.body.appendChild(overlay);
  modal = overlay;
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) closeModal();
  });
  const cancelBtn = overlay.querySelector("#cancelModal");
  cancelBtn?.addEventListener("click", closeModal);
}

function closeModal() {
  modal?.remove();
  modal = null;
}

// ---------------------------------------------------------------------------
// State refresh
// ---------------------------------------------------------------------------

async function refreshState() {
  appState = await settingsRpc.request.getState();
  render();
}

// ---------------------------------------------------------------------------
// HTML escaping helper
// ---------------------------------------------------------------------------

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

init();
