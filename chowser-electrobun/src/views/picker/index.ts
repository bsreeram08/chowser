// ---------------------------------------------------------------------------
// Picker webview — TypeScript that runs inside the browser window
// ---------------------------------------------------------------------------
// This module communicates with the Bun main process via Electrobun RPC and
// renders an interactive browser-picker UI.
// ---------------------------------------------------------------------------

import { Electroview, type ElectrobunRPCSchema } from "electrobun/view";
import type { BrowserConfig, FocusMode } from "../../bun/models.ts";

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

// Create the Electroview instance which sets up the WebSocket RPC transport.
// We keep a reference to pickerRpc for direct typed calls rather than going
// through the optional `electroview.rpc` property.
new Electroview({ rpc: pickerRpc });

type PickerData = Awaited<ReturnType<typeof pickerRpc.request.getPickerData>>;
let pickerData: PickerData | null = null;
let usePrivateMode = false;
let showRuleForm = false;
let selectedIndex = 0;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

async function init() {
  try {
    pickerData = await pickerRpc.request.getPickerData();
    selectedIndex = 0;
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

  const { url, browsers, suggestedRuleHostPattern, focusMode } = pickerData;

  const urlDisplay = url || "No URL";
  let displayUrl = urlDisplay;
  try {
    const u = new URL(urlDisplay);
    displayUrl = u.hostname + (u.pathname !== "/" ? u.pathname : "");
  } catch {}
  const truncatedUrl =
    displayUrl.length > 80 ? displayUrl.slice(0, 80) + "…" : displayUrl;

  // Focus mode banner
  const focusBanner = focusMode
    ? `<div class="focus-banner">
         🎯 Focus mode active — all URLs go to one browser
       </div>`
    : "";

  // Private mode background highlight
  const privateBg = usePrivateMode
    ? "background:rgba(191,90,242,0.07);border-radius:12px;"
    : "";

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
            class="browser-btn${usePrivateMode ? " private-mode" : ""}${selectedIndex === i ? " selected" : ""}"
            data-browser-id="${esc(b.id)}"
            data-index="${i}"
            tabindex="${i + 1}"
            title="${esc(b.name)}${b.profile ? ` — ${esc(b.profile)}` : ""}${b.shortcutKey ? ` [${esc(b.shortcutKey)}]` : ""}"
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
        ${browsers.map((b) => `<option value="${esc(b.id)}">${esc(b.name)}${b.profile ? ` (${esc(b.profile)})` : ""}</option>`).join("")}
      </select>
      <div class="rule-form-actions">
        <button class="btn btn-ghost" id="cancelRule">Cancel</button>
        <button class="btn btn-primary" id="saveRule">Create Rule</button>
      </div>
    </div>`;

  document.getElementById("root")!.innerHTML = `
    <div class="container" style="${privateBg}">
      ${focusBanner}
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
          <span><kbd>1</kbd>–<kbd>9</kbd> pick</span>
          <span><kbd>←→</kbd> navigate</span>
          <span><kbd>↵</kbd> open</span>
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
      const idx = parseInt((btn as HTMLElement).dataset["index"] ?? "0", 10);
      selectedIndex = idx;
      openInBrowser(id);
    });
    btn.addEventListener("mouseenter", () => {
      selectedIndex = parseInt(
        (btn as HTMLElement).dataset["index"] ?? "0",
        10
      );
      updateSelectedVisual();
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

function updateSelectedVisual() {
  document.querySelectorAll(".browser-btn").forEach((btn) => {
    const idx = parseInt((btn as HTMLElement).dataset["index"] ?? "-1", 10);
    btn.classList.toggle("selected", idx === selectedIndex);
  });
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

function togglePrivate() {
  usePrivateMode = !usePrivateMode;
  render();
}

function openInBrowser(browserId: string) {
  pickerRpc.request
    .openInBrowser({ browserId, usePrivateMode })
    .catch(console.error);
}

function saveRule() {
  if (!pickerData) return;
  const select = document.getElementById("ruleBrowser") as HTMLSelectElement;
  const browserAppId = select.value;
  const hostPattern = pickerData.suggestedRuleHostPattern;
  pickerRpc.request
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

let keyboardShortcutsInitialized = false;

function setupKeyboardShortcuts() {
  if (keyboardShortcutsInitialized) {
    return;
  }
  document.addEventListener("keydown", handleKeyDown);
  keyboardShortcutsInitialized = true;
}

function handleKeyDown(e: KeyboardEvent) {
  if (!pickerData) return;

  // Ignore when typing in an input/select
  const tag = (e.target as HTMLElement).tagName.toLowerCase();
  if (tag === "input" || tag === "select" || tag === "textarea") return;

  // Dismiss
  if (e.key === "Escape") {
    pickerRpc.request.dismissPicker().catch(console.error);
    return;
  }

  // Copy URL
  if ((e.metaKey || e.ctrlKey) && e.key === "c") {
    navigator.clipboard.writeText(pickerData.url).catch(() => {});
    return;
  }

  // Private mode toggle
  if (!e.metaKey && !e.ctrlKey && (e.key === "p" || e.key === "P")) {
    e.preventDefault();
    togglePrivate();
    return;
  }

  // Rule creation toggle
  if (!e.metaKey && !e.ctrlKey && (e.key === "r" || e.key === "R")) {
    e.preventDefault();
    showRuleForm = !showRuleForm;
    render();
    return;
  }

  const browsers = pickerData.browsers;
  if (browsers.length === 0) return;

  // Arrow key navigation
  if (e.key === "ArrowLeft" || e.key === "ArrowUp") {
    e.preventDefault();
    selectedIndex = (selectedIndex - 1 + browsers.length) % browsers.length;
    updateSelectedVisual();
    return;
  }
  if (e.key === "ArrowRight" || e.key === "ArrowDown") {
    e.preventDefault();
    selectedIndex = (selectedIndex + 1) % browsers.length;
    updateSelectedVisual();
    return;
  }

  // Enter — open selected
  if (e.key === "Enter" || e.key === "Return") {
    e.preventDefault();
    const browser = browsers[selectedIndex];
    if (browser) openInBrowser(browser.id);
    return;
  }

  // Number shortcuts 1–9
  if (e.key >= "1" && e.key <= "9") {
    const browser = browsers.find((b) => b.shortcutKey === e.key);
    if (browser) openInBrowser(browser.id);
    return;
  }

  // Type first letter to select browser
  if (e.key.length === 1 && !e.metaKey && !e.ctrlKey) {
    const lower = e.key.toLowerCase();
    const idx = browsers.findIndex((b) =>
      b.name.toLowerCase().startsWith(lower)
    );
    if (idx !== -1) {
      selectedIndex = idx;
      updateSelectedVisual();
    }
  }
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
