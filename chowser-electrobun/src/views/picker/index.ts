// ---------------------------------------------------------------------------
// Picker webview — TypeScript that runs inside the browser window
// ---------------------------------------------------------------------------
// This module communicates with the Bun main process via Electrobun RPC and
// renders an interactive browser-picker UI.
// ---------------------------------------------------------------------------

import { Electroview, type ElectrobunRPCSchema } from "electrobun/view";
import type { BrowserConfig } from "../../bun/models.ts";

// ---------------------------------------------------------------------------
// RPC schema (must mirror src/bun/index.ts PickerSchema)
// ---------------------------------------------------------------------------

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

const pickerRpc = Electroview.defineRPC<PickerSchema>({
  handlers: {
    messages: {
      // Bun tells us to refresh when a new URL comes in while picker is open
      refreshPicker: () => {
        init();
      },
    },
  },
});

const electroview = new Electroview({ rpc: pickerRpc });
let pickerData: Awaited<
  ReturnType<(typeof electroview.rpc.request)["getPickerData"]>
> | null = null;
let usePrivateMode = false;
let showRuleForm = false;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

async function init() {
  try {
    pickerData = await electroview.rpc.request.getPickerData();
    render();
    setupKeyboardShortcuts();
  } catch (err) {
    document.getElementById("root")!.innerHTML = `
      <div class="container">
        <div class="empty-state">
          <div class="empty-state-icon">⚠️</div>
          <div>Failed to load picker data</div>
          <div style="font-size:11px;opacity:0.6">${String(err)}</div>
        </div>
      </div>`;
  }
}

// ---------------------------------------------------------------------------
// Rendering
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

function render() {
  if (!pickerData) return;

  const { url, browsers, suggestedRuleHostPattern } = pickerData;

  const urlDisplay = url || "No URL";
  const truncatedUrl =
    urlDisplay.length > 80 ? urlDisplay.slice(0, 80) + "…" : urlDisplay;

  const browsersHTML =
    browsers.length === 0
      ? `<div class="empty-state">
           <div class="empty-state-icon">🌐</div>
           <div>No browsers configured</div>
           <div style="font-size:11px;opacity:0.6">Open Settings to add browsers</div>
         </div>`
      : browsers
          .map(
            (b, i) => `
          <button
            class="browser-btn${usePrivateMode ? " private-mode" : ""}"
            data-browser-id="${esc(b.id)}"
            tabindex="${i + 1}"
            title="${esc(b.name)}${b.profile ? ` — ${esc(b.profile)}` : ""}"
          >
            <span class="shortcut-badge">${esc(b.shortcutKey)}</span>
            <span class="browser-icon">${browserEmoji(b.name)}</span>
            <span class="browser-name">${esc(b.name)}</span>
            ${b.profile ? `<span class="browser-profile">${esc(b.profile)}</span>` : ""}
          </button>`
          )
          .join("");

  const ruleFormHTML = `
    <div class="rule-form${showRuleForm ? " visible" : ""}" id="ruleForm">
      <div style="font-size:12.5px;font-weight:600;color:var(--text)">Always open <em>${esc(suggestedRuleHostPattern)}</em> in…</div>
      <select id="ruleBrowser">
        ${browsers.map((b) => `<option value="${esc(b.appId)}">${esc(b.name)}${b.profile ? ` (${esc(b.profile)})` : ""}</option>`).join("")}
      </select>
      <div class="rule-form-actions">
        <button class="btn btn-ghost" id="cancelRule">Cancel</button>
        <button class="btn btn-primary" id="saveRule">Create Rule</button>
      </div>
    </div>`;

  document.getElementById("root")!.innerHTML = `
    <div class="container">
      <div class="url-bar">
        <span class="url-icon">🔗</span>
        <span class="url-text" title="${esc(urlDisplay)}">${esc(truncatedUrl)}</span>
        <div class="private-toggle${usePrivateMode ? " active" : ""}" id="privateToggle" title="Toggle private/incognito mode (P)">
          🕵️ Private
        </div>
      </div>

      <div class="browsers-grid" id="browsersGrid">
        ${browsersHTML}
      </div>

      ${ruleFormHTML}

      <div class="footer">
        <div class="footer-hint">
          <span><kbd>1</kbd>–<kbd>9</kbd> pick browser</span>
          <span><kbd>P</kbd> private</span>
          <span><kbd>Esc</kbd> dismiss</span>
        </div>
        <button class="add-rule-btn" id="addRuleBtn">＋ Rule</button>
      </div>
    </div>`;

  // Event listeners
  document
    .getElementById("privateToggle")!
    .addEventListener("click", togglePrivate);

  document.getElementById("addRuleBtn")!.addEventListener("click", () => {
    showRuleForm = !showRuleForm;
    render();
  });

  document.querySelectorAll(".browser-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = (btn as HTMLElement).dataset["browserId"]!;
      openInBrowser(id);
    });
  });

  if (showRuleForm) {
    document.getElementById("cancelRule")!.addEventListener("click", () => {
      showRuleForm = false;
      render();
    });
    document.getElementById("saveRule")!.addEventListener("click", saveRule);
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

function togglePrivate() {
  usePrivateMode = !usePrivateMode;
  render();
}

function openInBrowser(browserId: string) {
  electroview.rpc.request
    .openInBrowser({ browserId, usePrivateMode })
    .catch(console.error);
}

function saveRule() {
  if (!pickerData) return;
  const select = document.getElementById("ruleBrowser") as HTMLSelectElement;
  const browserAppId = select.value;
  const hostPattern = pickerData.suggestedRuleHostPattern;
  electroview.rpc.request
    .createRule({
      name: `Open ${hostPattern} in configured browser`,
      hostPattern,
      browserAppId,
      usePrivateMode,
    })
    .then(() => {
      showRuleForm = false;
      render();
    })
    .catch(console.error);
}

// ---------------------------------------------------------------------------
// Keyboard shortcuts
// ---------------------------------------------------------------------------

function setupKeyboardShortcuts() {
  document.addEventListener("keydown", (e: KeyboardEvent) => {
    if (!pickerData) return;

    // Dismiss
    if (e.key === "Escape") {
      electroview.rpc.request.dismissPicker().catch(console.error);
      return;
    }

    // Private mode toggle
    if (e.key === "p" || e.key === "P") {
      togglePrivate();
      return;
    }

    // Rule creation
    if (e.key === "r" || e.key === "R") {
      showRuleForm = !showRuleForm;
      render();
      return;
    }

    // Number shortcuts 1–9
    if (e.key >= "1" && e.key <= "9") {
      const browser = pickerData.browsers.find(
        (b) => b.shortcutKey === e.key
      );
      if (browser) openInBrowser(browser.id);
    }
  });
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
