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
  maxRequestTime: 30000,
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
// Additional module state
// ---------------------------------------------------------------------------

let pickerLayout: "icons" | "list" = "icons";
let urlCopied = false;
let unshortenState: "idle" | "loading" | "error" = "idle";
let ruleName = "";
let ruleBrowserId = "";
let ruleUsePrivate = false;
let lastLetterKey = "";
let lastLetterMatches: number[] = [];
let lastLetterMatchIdx = 0;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const GLOBE_SVG_DATA =
  "data:image/svg+xml," +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"' +
      ' stroke="rgba(255,255,255,0.45)" stroke-width="1.5" stroke-linecap="round"' +
      ' stroke-linejoin="round"><circle cx="12" cy="12" r="10"/>' +
      '<path d="M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20"/>' +
      '<line x1="2" y1="12" x2="22" y2="12"/></svg>'
  );

// ---------------------------------------------------------------------------
// HTML helpers
// ---------------------------------------------------------------------------

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function truncateMiddle(s: string, maxLen: number): string {
  if (s.length <= maxLen) return s;
  const front = Math.ceil(maxLen * 0.55);
  const back = maxLen - front - 1;
  return s.slice(0, front) + "\u2026" + s.slice(-back);
}

function appIdToDomain(appId: string): string {
  const parts = appId.split(".");
  if (parts.length >= 2) return `${parts[1]}.${parts[0]}`;
  return appId;
}

function browserIconUrl(appId: string): string {
  const domain = appIdToDomain(appId);
  return `https://www.google.com/s2/favicons?domain=${encodeURIComponent(domain)}&sz=64`;
}

function imgTag(appId: string, name: string, size: number, cls: string): string {
  const src = esc(browserIconUrl(appId));
  const fallback = esc(GLOBE_SVG_DATA);
  return (
    `<img src="${src}" alt="${esc(name)}" width="${size}" height="${size}"` +
    ` class="${cls}" data-fallback="${fallback}"` +
    ` onerror="this.onerror=null;this.src=this.dataset.fallback">`
  );
}

function keyHintChip(
  key: string,
  label: string,
  isAccent = false,
  isActive = false,
  disabled = false
): string {
  const chipCls = isAccent ? " kc-accent" : isActive ? " kc-active" : "";
  const lblCls = isAccent ? " kl-accent" : isActive ? " kl-active" : "";
  return (
    `<span class="key-hint${disabled ? " disabled" : ""}">` +
    `<span class="key-chip${chipCls}">${esc(key)}</span>` +
    `<span class="key-label${lblCls}">${esc(label)}</span>` +
    `</span>`
  );
}

// ---------------------------------------------------------------------------
// Section renderers
// ---------------------------------------------------------------------------

function renderFocusBanner(focusMode: FocusMode | null): string {
  if (!focusMode) return "";
  return (
    `<div class="focus-banner">` +
    `<span>🎯</span>` +
    `<span class="focus-banner-text">Focus mode active — all URLs go to one browser</span>` +
    `</div>`
  );
}

function renderUrlSection(url: string): string {
  if (!url) return "";

  let displayHost = url;
  try {
    const u = new URL(url);
    displayHost = u.hostname + (u.pathname !== "/" ? u.pathname : "");
  } catch {
    /* leave as-is */
  }
  const truncated = truncateMiddle(displayHost, 52);

  // Unshorten button icon by state
  let unshortenIcon: string;
  if (unshortenState === "loading") {
    unshortenIcon =
      `<span class="url-action-btn spin" id="unshortenBtn" title="Resolving…">` +
      `<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">` +
      `<path d="M21 12a9 9 0 1 1-9-9c2.39 0 4.68.94 6.36 2.64L21 8"/><path d="M21 3v5h-5"/></svg>` +
      `</span>`;
  } else if (unshortenState === "error") {
    unshortenIcon =
      `<button class="url-action-btn error-state" id="unshortenBtn" title="Could not resolve — click to retry">` +
      `⚠</button>`;
  } else {
    unshortenIcon =
      `<button class="url-action-btn" id="unshortenBtn" title="Resolve/Unshorten URL (H)">` +
      `<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">` +
      `<path d="M7 17L17 7M7 7h10v10"/></svg>` +
      `</button>`;
  }

  const copyIcon = urlCopied
    ? `<button class="url-action-btn copied" id="copyBtn" title="Copied!">✓</button>`
    : `<button class="url-action-btn" id="copyBtn" title="Copy URL (⌘C)">` +
      `<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">` +
      `<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>` +
      `</button>`;

  return (
    `<div class="url-section">` +
    `<span class="url-icon">` +
    `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">` +
    `<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/>` +
    `<path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>` +
    `</span>` +
    `<span class="url-hostname" title="${esc(url)}">${esc(truncated)}</span>` +
    `<div class="url-actions">` +
    `<button class="url-action-btn" id="addRuleBtn" title="Create routing rule (+)">+</button>` +
    unshortenIcon +
    copyIcon +
    `</div>` +
    `</div>`
  );
}

function isSuggestedBrowser(b: BrowserConfig, pattern: string): boolean {
  if (!pattern) return false;
  const domain = pattern.replace(/^\*\./, "");
  return appIdToDomain(b.appId).includes(domain) || b.name.toLowerCase().includes(domain.toLowerCase());
}

function renderIconsBrowsers(browsers: BrowserConfig[], suggestedPattern: string): string {
  if (browsers.length === 0) {
    return (
      `<div class="empty-state">` +
      `<span class="empty-icon">🌐</span>` +
      `<div class="empty-texts">` +
      `<div class="empty-title">No browsers configured</div>` +
      `<div class="empty-sub">Open Settings from the menu bar to add a browser.</div>` +
      `</div></div>`
    );
  }
  const items = browsers
    .map((b, i) => {
      const sel = selectedIndex === i ? " selected" : "";
      const suggested = isSuggestedBrowser(b, suggestedPattern);
      const sugBadge = suggested
        ? `<span class="suggested-badge">✦</span>`
        : "";
      const scBadge = b.shortcutKey
        ? `<span class="shortcut-badge">${esc(b.shortcutKey)}</span>`
        : "";
      const title = b.profile ? `${b.name} — ${b.profile}` : b.name;
      return (
        `<button class="browser-icon-btn${sel}" data-browser-id="${esc(b.id)}"` +
        ` data-index="${i}" style="animation-delay:${i * 30}ms"` +
        ` title="${esc(title)}">` +
        `<span class="browser-icon-wrap">` +
        imgTag(b.appId, b.name, 34, "browser-icon-img") +
        sugBadge + scBadge +
        `</span>` +
        `<span class="browser-icon-label">${esc(b.name)}</span>` +
        `</button>`
      );
    })
    .join("");
  return `<div class="browsers-icons">${items}</div>`;
}

function renderListBrowsers(browsers: BrowserConfig[], suggestedPattern: string): string {
  if (browsers.length === 0) {
    return (
      `<div class="empty-state">` +
      `<span class="empty-icon">🌐</span>` +
      `<div class="empty-texts">` +
      `<div class="empty-title">No browsers configured</div>` +
      `<div class="empty-sub">Open Settings from the menu bar to add a browser.</div>` +
      `</div></div>`
    );
  }
  const rows = browsers
    .map((b, i) => {
      const sel = selectedIndex === i ? " selected" : "";
      const suggested = isSuggestedBrowser(b, suggestedPattern);
      const sugBadge = suggested ? `<span class="list-suggested">✦</span>` : "";
      const scBadge = b.shortcutKey
        ? `<span class="list-shortcut">${esc(b.shortcutKey)}</span>`
        : "";
      const profileRow = b.profile
        ? `<span class="browser-list-profile">${esc(b.profile)}</span>`
        : "";
      return (
        `<button class="browser-list-row${sel}" data-browser-id="${esc(b.id)}" data-index="${i}">` +
        imgTag(b.appId, b.name, 28, "browser-list-img") +
        `<div class="browser-list-info">` +
        `<span class="browser-list-name">${esc(b.name)}</span>` +
        profileRow +
        `</div>` +
        `<div class="browser-list-badges">${sugBadge}${scBadge}</div>` +
        `</button>`
      );
    })
    .join("");
  return `<div class="browsers-list">${rows}</div>`;
}

function renderSuggestionBanner(pattern: string, browsers: BrowserConfig[]): string {
  if (!pattern) return "";
  const selected = browsers[selectedIndex];
  const browserName = selected ? selected.name : "your browser";
  const domain = pattern.replace(/^\*\./, "");
  return (
    `<button class="suggestion-banner" id="suggestionBanner">` +
    `<span class="suggestion-icon">✦</span>` +
    `<span class="suggestion-text">Always open ${esc(domain)} in ${esc(browserName)}?</span>` +
    `<span class="suggestion-chevron">›</span>` +
    `</button>`
  );
}

function renderHintsRow(browsers: BrowserConfig[]): string {
  const hasUrl = !!(pickerData?.url);
  return (
    `<div class="sep"></div>` +
    `<div class="hints-row">` +
    keyHintChip("P", "Private", false, usePrivateMode) +
    keyHintChip("H", "Resolve", false, false, !hasUrl) +
    keyHintChip("R", "Rules") +
    keyHintChip("Esc", "Close") +
    `<span class="hint-spacer"></span>` +
    keyHintChip("↵", "Launch", true, false, browsers.length === 0) +
    `</div>`
  );
}

function renderRuleView(host: string, browsers: BrowserConfig[]): string {
  const canSave = ruleName.trim().length > 0 && ruleBrowserId !== "";
  const browserOptions = browsers
    .map(
      (b) =>
        `<option value="${esc(b.id)}"${ruleBrowserId === b.id ? " selected" : ""}>` +
        `${esc(b.name)}${b.profile ? ` (${esc(b.profile)})` : ""}` +
        `</option>`
    )
    .join("");
  return (
    `<div class="rule-view">` +
    // Header
    `<div class="rule-header">` +
    `<div class="rule-header-texts">` +
    `<div class="rule-header-title">New Routing Rule</div>` +
    `<div class="rule-header-sub">Automatic routing for ${esc(host)}</div>` +
    `</div>` +
    `<button class="rule-close-btn" id="ruleClose">✕</button>` +
    `</div>` +
    `<div class="sep"></div>` +
    // Body
    `<div class="rule-body">` +
    `<div>` +
    `<div class="rule-field-label">Rule Name</div>` +
    `<input class="rule-name-input" id="ruleNameInput" type="text"` +
    ` placeholder="Enter name…" value="${esc(ruleName)}" autocomplete="off">` +
    `</div>` +
    `<div class="rule-card">` +
    `<div class="rule-detail-row">` +
    `<span class="rule-detail-key">Host</span>` +
    `<span class="rule-detail-val">${esc(host)}</span>` +
    `</div>` +
    `<div class="rule-card-sep"></div>` +
    `<div class="rule-detail-row">` +
    `<span class="rule-detail-key">Open In</span>` +
    `<select id="ruleBrowserSelect">${browserOptions}</select>` +
    `</div>` +
    `<div class="rule-card-sep"></div>` +
    `<div class="rule-toggle-row">` +
    `<span class="rule-toggle-label">Use Private Mode</span>` +
    `<input class="rule-toggle-cb" id="rulePrivateCb" type="checkbox"${ruleUsePrivate ? " checked" : ""}>` +
    `</div>` +
    `</div>` +
    `</div>` +
    `<div class="sep"></div>` +
    // Footer
    `<div class="rule-footer">` +
    `<button class="rule-cancel-btn" id="ruleCancelBtn">Cancel</button>` +
    `<span class="rule-spacer"></span>` +
    `<button class="rule-save-btn" id="ruleSaveBtn"${canSave ? "" : " disabled"}>Save Rule</button>` +
    `</div>` +
    `</div>`
  );
}

// ---------------------------------------------------------------------------
// Main render
// ---------------------------------------------------------------------------

function render() {
  if (!pickerData) return;
  const { url, browsers, suggestedRuleHostPattern, focusMode } = pickerData;
  const root = document.getElementById("root")!;
  const priv = usePrivateMode ? " private-mode" : "";

  if (showRuleForm) {
    const host = suggestedRuleHostPattern || (url ? (() => { try { return new URL(url).hostname; } catch { return url; } })() : "");
    root.innerHTML =
      `<div class="panel panel-rule${priv}">` +
      renderRuleView(host, browsers) +
      `</div>`;
    attachRuleFormListeners();
    return;
  }

  const browsersSection =
    pickerLayout === "list"
      ? renderListBrowsers(browsers, suggestedRuleHostPattern)
      : renderIconsBrowsers(browsers, suggestedRuleHostPattern);

  const suggestionBanner =
    suggestedRuleHostPattern
      ? renderSuggestionBanner(suggestedRuleHostPattern, browsers)
      : "";

  const panelLayoutClass = pickerLayout === "list" ? " panel-list" : " panel-icons";
  root.innerHTML =
    `<div class="panel${panelLayoutClass}${priv}">` +
    renderFocusBanner(focusMode) +
    (url ? renderUrlSection(url) + `<div class="sep"></div>` : "") +
    browsersSection +
    suggestionBanner +
    (browsers.length > 0 ? renderHintsRow(browsers) : "") +
    `</div>`;

  attachMainListeners();
}

// ---------------------------------------------------------------------------
// Event listener attachment
// ---------------------------------------------------------------------------

function attachMainListeners() {
  // URL action buttons
  document.getElementById("addRuleBtn")?.addEventListener("click", openRuleForm);
  document.getElementById("copyBtn")?.addEventListener("click", copyUrl);
  document.getElementById("unshortenBtn")?.addEventListener("click", () => {
    if (unshortenState === "loading") return;
    unshortenState = "idle";
    unshortenUrl();
  });
  document.getElementById("suggestionBanner")?.addEventListener("click", openRuleForm);

  // Browser buttons (icons or list)
  document.querySelectorAll<HTMLElement>(".browser-icon-btn, .browser-list-row").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = btn.dataset["browserId"]!;
      const idx = parseInt(btn.dataset["index"] ?? "0", 10);
      selectedIndex = idx;
      openInBrowser(id);
    });
    btn.addEventListener("mouseenter", () => {
      const idx = parseInt(btn.dataset["index"] ?? "0", 10);
      if (selectedIndex !== idx) {
        selectedIndex = idx;
        updateSelectedVisual();
      }
    });
  });
}

function attachRuleFormListeners() {
  document.getElementById("ruleClose")?.addEventListener("click", closeRuleForm);
  document.getElementById("ruleCancelBtn")?.addEventListener("click", closeRuleForm);

  const nameInput = document.getElementById("ruleNameInput") as HTMLInputElement | null;
  nameInput?.addEventListener("input", () => {
    ruleName = nameInput.value;
    // Update save button enabled state without full re-render
    const saveBtn = document.getElementById("ruleSaveBtn") as HTMLButtonElement | null;
    if (saveBtn) saveBtn.disabled = ruleName.trim().length === 0 || ruleBrowserId === "";
  });

  const browserSelect = document.getElementById("ruleBrowserSelect") as HTMLSelectElement | null;
  if (browserSelect) {
    browserSelect.addEventListener("change", () => {
      ruleBrowserId = browserSelect.value;
      const saveBtn = document.getElementById("ruleSaveBtn") as HTMLButtonElement | null;
      if (saveBtn) saveBtn.disabled = ruleName.trim().length === 0 || ruleBrowserId === "";
    });
  }

  const privateCb = document.getElementById("rulePrivateCb") as HTMLInputElement | null;
  privateCb?.addEventListener("change", () => {
    ruleUsePrivate = privateCb.checked;
  });

  document.getElementById("ruleSaveBtn")?.addEventListener("click", saveRule);
}

// ---------------------------------------------------------------------------
// Visual update (without full re-render)
// ---------------------------------------------------------------------------

function updateSelectedVisual() {
  document.querySelectorAll<HTMLElement>(".browser-icon-btn, .browser-list-row").forEach((btn) => {
    const idx = parseInt(btn.dataset["index"] ?? "-1", 10);
    btn.classList.toggle("selected", idx === selectedIndex);
  });
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

function openRuleForm() {
  if (!pickerData) return;
  // Default to currently-selected browser
  const sel = pickerData.browsers[selectedIndex];
  ruleBrowserId = sel ? sel.id : (pickerData.browsers[0]?.id ?? "");
  if (!ruleName && pickerData.suggestedRuleHostPattern) {
    const host = pickerData.suggestedRuleHostPattern.replace(/^\*\./, "");
    const browserName = sel ? sel.name : "";
    ruleName = browserName ? `Open ${host} in ${browserName}` : `Open ${host}`;
  }
  ruleUsePrivate = usePrivateMode;
  showRuleForm = true;
  render();
  // Focus the name input after render
  setTimeout(() => {
    const input = document.getElementById("ruleNameInput") as HTMLInputElement | null;
    input?.focus();
    input?.select();
  }, 50);
}

function closeRuleForm() {
  showRuleForm = false;
  ruleName = "";
  ruleUsePrivate = false;
  render();
}

function togglePrivate() {
  usePrivateMode = !usePrivateMode;
  render();
}

function openInBrowser(browserId: string) {
  pickerRpc.request
    .openInBrowser({ browserId, usePrivateMode })
    .catch(console.error);
}

function copyUrl() {
  if (!pickerData?.url) return;
  navigator.clipboard.writeText(pickerData.url).then(() => {
    urlCopied = true;
    render();
    setTimeout(() => {
      urlCopied = false;
      render();
    }, 1500);
  }).catch(() => {});
}

async function unshortenUrl() {
  if (!pickerData?.url || unshortenState === "loading") return;
  unshortenState = "loading";
  render();
  try {
    const resp = await fetch(pickerData.url, { method: "HEAD", redirect: "follow" });
    if (resp.url && resp.url !== pickerData.url) {
      pickerData = { ...pickerData, url: resp.url };
    }
    unshortenState = "idle";
  } catch {
    unshortenState = "error";
  }
  render();
}

function saveRule() {
  if (!pickerData) return;
  const trimmed = ruleName.trim();
  if (!trimmed || !ruleBrowserId) return;
  const browser = pickerData.browsers.find((b) => b.id === ruleBrowserId);
  if (!browser) return;
  const hostPattern =
    pickerData.suggestedRuleHostPattern ||
    (() => {
      try { return new URL(pickerData!.url).hostname; } catch { return pickerData!.url; }
    })();
  pickerRpc.request
    .createRule({
      name: trimmed,
      hostPattern,
      browserAppId: browser.appId,
      usePrivateMode: ruleUsePrivate,
    })
    .then(() => {
      closeRuleForm();
    })
    .catch(console.error);
}

// ---------------------------------------------------------------------------
// Keyboard shortcuts
// ---------------------------------------------------------------------------

let keyboardShortcutsInitialized = false;

function setupKeyboardShortcuts() {
  if (keyboardShortcutsInitialized) return;
  document.addEventListener("keydown", handleKeyDown);
  keyboardShortcutsInitialized = true;
}

function handleKeyDown(e: KeyboardEvent) {
  if (!pickerData) return;

  // Let keystrokes through when typing in form fields
  const tag = (e.target as HTMLElement).tagName.toLowerCase();
  const inField = tag === "input" || tag === "select" || tag === "textarea";

  if (e.key === "Escape") {
    if (showRuleForm) { closeRuleForm(); return; }
    pickerRpc.request.dismissPicker().catch(console.error);
    return;
  }

  if (inField) return;

  // Copy URL
  if ((e.metaKey || e.ctrlKey) && e.key === "c") {
    e.preventDefault();
    copyUrl();
    return;
  }

  // Private mode toggle
  if (!e.metaKey && !e.ctrlKey && (e.key === "p" || e.key === "P")) {
    e.preventDefault();
    togglePrivate();
    return;
  }

  // Resolve/Unshorten URL
  if (!e.metaKey && !e.ctrlKey && (e.key === "h" || e.key === "H")) {
    e.preventDefault();
    unshortenUrl();
    return;
  }

  // Rule creation toggle
  if (!e.metaKey && !e.ctrlKey && (e.key === "r" || e.key === "R")) {
    e.preventDefault();
    if (showRuleForm) { closeRuleForm(); } else { openRuleForm(); }
    return;
  }

  if (showRuleForm) return;

  const browsers = pickerData.browsers;
  if (browsers.length === 0) return;

  // Arrow navigation
  if (e.key === "ArrowLeft" || e.key === "ArrowUp") {
    e.preventDefault();
    selectedIndex = (selectedIndex - 1 + browsers.length) % browsers.length;
    lastLetterKey = "";
    updateSelectedVisual();
    return;
  }
  if (e.key === "ArrowRight" || e.key === "ArrowDown") {
    e.preventDefault();
    selectedIndex = (selectedIndex + 1) % browsers.length;
    lastLetterKey = "";
    updateSelectedVisual();
    return;
  }

  // Tab cycles forward
  if (e.key === "Tab") {
    e.preventDefault();
    selectedIndex = (selectedIndex + (e.shiftKey ? -1 : 1) + browsers.length) % browsers.length;
    lastLetterKey = "";
    updateSelectedVisual();
    return;
  }

  // Enter / Space — open selected
  if (e.key === "Enter" || e.key === " ") {
    e.preventDefault();
    const browser = browsers[selectedIndex];
    if (browser) openInBrowser(browser.id);
    return;
  }

  // Number shortcuts 1–9
  if (e.key >= "1" && e.key <= "9") {
    const browser = browsers.find((b) => b.shortcutKey === e.key);
    if (browser) { openInBrowser(browser.id); return; }
  }

  // Letter key — cycle through matching browsers
  if (e.key.length === 1 && !e.metaKey && !e.ctrlKey) {
    const lower = e.key.toLowerCase();
    if (lower === lastLetterKey && lastLetterMatches.length > 1) {
      lastLetterMatchIdx = (lastLetterMatchIdx + 1) % lastLetterMatches.length;
      const idx = lastLetterMatches[lastLetterMatchIdx];
      if (idx !== undefined) { selectedIndex = idx; updateSelectedVisual(); }
    } else {
      lastLetterKey = lower;
      lastLetterMatches = browsers
        .map((b, i) => (b.name.toLowerCase().startsWith(lower) ? i : -1))
        .filter((i): i is number => i !== -1);
      lastLetterMatchIdx = 0;
      const idx = lastLetterMatches[0];
      if (idx !== undefined) { selectedIndex = idx; updateSelectedVisual(); }
    }
  }
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

async function init() {
  try {
    pickerData = await pickerRpc.request.getPickerData();
    selectedIndex = 0;
    urlCopied = false;
    unshortenState = "idle";
    lastLetterKey = "";
    lastLetterMatches = [];
    render();
    setupKeyboardShortcuts();
  } catch (err) {
    document.getElementById("root")!.innerHTML =
      `<div class="panel">` +
      `<div class="empty-state">` +
      `<span class="empty-icon">⚠️</span>` +
      `<div class="empty-texts">` +
      `<div class="empty-title">Failed to load picker data</div>` +
      `<div class="empty-sub">${esc(String(err))}</div>` +
      `</div></div></div>`;
  }
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

init();
