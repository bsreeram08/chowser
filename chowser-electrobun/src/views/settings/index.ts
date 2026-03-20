// ---------------------------------------------------------------------------
// Settings webview — TypeScript that runs inside the settings window
// ---------------------------------------------------------------------------
// This module communicates with the Bun main process via Electrobun RPC and
// renders the full settings UI with browser management and routing rules.
// ---------------------------------------------------------------------------

import { Electroview, type ElectrobunRPCSchema } from "electrobun/view";
import type {
  BrowserConfig,
  BrowserRoutingRule,
  InstalledBrowser,
} from "../../bun/models.ts";

// ---------------------------------------------------------------------------
// RPC schema (must mirror src/bun/index.ts SettingsSchema)
// ---------------------------------------------------------------------------

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

const settingsRpc = Electroview.defineRPC<SettingsSchema>({
  handlers: {},
});

// Create the Electroview instance which wires up the WebSocket RPC transport.
// We use settingsRpc directly for typed calls rather than going through
// the optional `electroview.rpc` property.
new Electroview({ rpc: settingsRpc });

interface AppState {
  browsers: BrowserConfig[];
  rules: BrowserRoutingRule[];
  installedBrowsers: InstalledBrowser[];
  hasCompletedOnboarding: boolean;
  hiddenAppIds: string[];
}

let appState: AppState | null = null;
let activeTab: "browsers" | "rules" | "general" = "browsers";
let modal: HTMLElement | null = null;

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
                  </div>
                </div>
                <div class="list-item-actions">
                  <button class="btn btn-danger btn-sm remove-browser-btn" data-browser-id="${esc(b.id)}">Remove</button>
                </div>
              </div>`
          )
          .join("");

  return `
    <div class="section-header">
      <h2>Browsers</h2>
      <div style="display:flex;gap:8px">
        <button class="btn btn-ghost" id="detectBrowsersBtn">🔍 Detect</button>
        <button class="btn btn-primary" id="addBrowserBtn">＋ Add Browser</button>
      </div>
    </div>
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
                  </div>
                  <div class="list-item-subtitle">
                    ${esc(r.hostPattern)}${r.pathPrefix ? `/${esc(r.pathPrefix)}` : ""}
                    → ${esc(browserName(r.browserAppId))}${r.profile ? ` (${esc(r.profile)})` : ""}
                    ${r.sourceAppBundleId ? ` · from ${esc(r.sourceAppBundleId)}` : ""}
                  </div>
                </div>
                <div class="list-item-actions">
                  <button class="btn btn-ghost btn-sm toggle-rule-btn" data-rule-id="${esc(r.id)}" data-enabled="${r.isEnabled}">
                    ${r.isEnabled ? "Disable" : "Enable"}
                  </button>
                  <button class="btn btn-danger btn-sm remove-rule-btn" data-rule-id="${esc(r.id)}">Remove</button>
                </div>
              </div>`
          )
          .join("");

  return `
    <div class="section-header">
      <h2>Routing Rules</h2>
      <button class="btn btn-primary" id="addRuleBtn">＋ Add Rule</button>
    </div>
    <p style="font-size:12px;color:var(--text-secondary);margin-bottom:14px">
      Rules are checked top-to-bottom. The first match wins.
    </p>
    <div class="card">${rulesHTML}</div>`;
}

// ---------------------------------------------------------------------------
// General tab
// ---------------------------------------------------------------------------

function renderGeneralTab(): string {
  return `
    <h2>General</h2>

    <h3 style="margin-top:0">Default Browser</h3>
    <div class="card">
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">Set Chowser as Default Browser</div>
          <div class="list-item-subtitle">Opens macOS System Settings</div>
        </div>
        <button class="btn btn-primary" id="setDefaultBrowserBtn">Open Settings</button>
      </div>
    </div>

    <h3>Import / Export</h3>
    <div class="card">
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">Export Configuration</div>
          <div class="list-item-subtitle">Download a JSON backup of your browsers and rules</div>
        </div>
        <button class="btn btn-ghost" id="exportBtn">Export</button>
      </div>
      <div class="list-item">
        <div class="list-item-body">
          <div class="list-item-title">Import Configuration</div>
          <div class="list-item-subtitle">Merge browsers and rules from a JSON file</div>
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
      render();
    });
  });

  // Onboarding
  document
    .getElementById("openDefaultBrowserSettings")
    ?.addEventListener("click", () => {
      openSystemPreferences();
    });

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

  document.querySelectorAll(".remove-rule-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["ruleId"]!;
      removeRule(id);
    });
  });

  document.querySelectorAll(".toggle-rule-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["ruleId"]!;
      const currentlyEnabled =
        (btn as HTMLElement).dataset["enabled"] === "true";
      toggleRule(id, !currentlyEnabled);
    });
  });

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
}

// ---------------------------------------------------------------------------
// Browser actions
// ---------------------------------------------------------------------------

async function removeBrowser(id: string) {
  await settingsRpc.request.removeBrowser({ id });
  await refreshState();
}

async function detectBrowsers() {
  const installed = await settingsRpc.request.detectBrowsers();
  if (appState) {
    appState.installedBrowsers = installed;
  }
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
      <input type="text" id="browserShortcut" maxlength="1" placeholder="1" />
    </div>
    <div class="modal-actions">
      <button class="btn btn-ghost" id="cancelModal">Cancel</button>
      <button class="btn btn-primary" id="confirmAddBrowser">Add</button>
    </div>
  `);

  // Auto-fill when selecting detected browser
  document
    .getElementById("detectedBrowserSelect")!
    .addEventListener("change", (e) => {
      const select = e.target as HTMLSelectElement;
      const selectedOption = select.selectedOptions[0];
      if (!selectedOption || !selectedOption.value) return;

      const name = selectedOption.dataset["name"] ?? "";
      const profile = selectedOption.dataset["profile"] ?? "";
      const appId = selectedOption.value;

      (document.getElementById("browserName") as HTMLInputElement).value =
        name;
      (document.getElementById("browserAppId") as HTMLInputElement).value =
        appId;
      (document.getElementById("browserProfile") as HTMLInputElement).value =
        profile;

      // Auto-assign shortcut
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

      if (!name || !appId) {
        alert("Name and Bundle ID are required.");
        return;
      }

      const newBrowser: BrowserConfig = {
        id: crypto.randomUUID(),
        name,
        appId,
        shortcutKey,
        profile,
      };

      await settingsRpc.request.addBrowser(newBrowser);
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
             <div class="list-item-subtitle">${esc(b.appId)}</div>
           </div>
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
}

// ---------------------------------------------------------------------------
// Rule actions
// ---------------------------------------------------------------------------

async function removeRule(id: string) {
  await settingsRpc.request.removeRule({ id });
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

function showAddRuleModal() {
  const browsers = appState?.browsers ?? [];
  const browserOptions = browsers
    .map(
      (b) =>
        `<option value="${esc(b.appId)}">${esc(b.name)}${b.profile ? ` (${esc(b.profile)})` : ""}</option>`
    )
    .join("");

  showModal(`
    <h3>Add Routing Rule</h3>
    <div class="form-group">
      <label class="form-label">Rule Name</label>
      <input type="text" id="ruleName" placeholder="e.g. GitHub in Chrome" />
    </div>
    <div class="form-group">
      <label class="form-label">Host Pattern</label>
      <input type="text" id="ruleHostPattern" placeholder="e.g. *.github.com or github.com" />
    </div>
    <div class="form-group">
      <label class="form-label">Path Prefix (optional)</label>
      <input type="text" id="rulePathPrefix" placeholder="e.g. /work" />
    </div>
    <div class="form-group">
      <label class="form-label">Open In Browser</label>
      <select id="ruleBrowserSelect">
        ${browserOptions}
      </select>
    </div>
    <div class="form-group">
      <label class="form-label">Source App Bundle ID (optional)</label>
      <input type="text" id="ruleSourceApp" placeholder="e.g. com.tinyspeck.slackmacgap" />
    </div>
    <div class="form-group">
      <label style="display:flex;align-items:center;gap:8px;cursor:pointer">
        <input type="checkbox" id="rulePrivate" />
        <span>Open in private/incognito mode</span>
      </label>
    </div>
    <div class="form-group">
      <label style="display:flex;align-items:center;gap:8px;cursor:pointer">
        <input type="checkbox" id="ruleRegex" />
        <span>Use regex for host pattern</span>
      </label>
    </div>
    <div class="modal-actions">
      <button class="btn btn-ghost" id="cancelModal">Cancel</button>
      <button class="btn btn-primary" id="confirmAddRule">Add Rule</button>
    </div>
  `);

  document
    .getElementById("confirmAddRule")!
    .addEventListener("click", async () => {
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
      const browserAppId = (
        document.getElementById("ruleBrowserSelect") as HTMLSelectElement
      ).value;
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
        return;
      }

      const newRule: BrowserRoutingRule = {
        id: crypto.randomUUID(),
        name,
        hostPattern,
        pathPrefix,
        browserAppId,
        sourceAppBundleId,
        isEnabled: true,
        usePrivateMode,
        useRegex,
      };

      await settingsRpc.request.addRule(newRule);
      closeModal();
      await refreshState();
    });
}

// ---------------------------------------------------------------------------
// Import / Export
// ---------------------------------------------------------------------------

async function exportConfig() {
  const json = await settingsRpc.request.exportConfig();

  // Show it in a modal for copying
  showModal(`
    <h3>Export Configuration</h3>
    <p style="font-size:12px;color:var(--text-secondary);margin-bottom:8px">Copy this JSON to back up your configuration:</p>
    <textarea id="exportJson" readonly>${esc(json)}</textarea>
    <div class="modal-actions">
      <button class="btn btn-primary" id="cancelModal">Close</button>
    </div>
  `);

  const ta = document.getElementById("exportJson") as HTMLTextAreaElement;
  ta.select();
}

function showImportModal() {
  showModal(`
    <h3>Import Configuration</h3>
    <p style="font-size:12px;color:var(--text-secondary);margin-bottom:8px">Paste your exported JSON below (browsers and rules will be merged):</p>
    <textarea id="importJson" placeholder='{"browsers":[...],"rules":[...]}'></textarea>
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

// ---------------------------------------------------------------------------
// System Preferences
// ---------------------------------------------------------------------------

function openSystemPreferences() {
  // This will be handled by the OS via the open-url event or can be done
  // via Electrobun Utils.openExternal on the bun side.
  // From the webview we trigger it via an rpc call or direct system call.
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
