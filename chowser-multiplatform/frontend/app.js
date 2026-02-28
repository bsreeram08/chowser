(() => {
  const resolveInvoke = () =>
    window.__TAURI__?.core?.invoke ??
    window.__TAURI__?.invoke ??
    (typeof window.__TAURI_INTERNALS__?.invoke === "function"
      ? (command, payload) => window.__TAURI_INTERNALS__.invoke(command, payload)
      : undefined);

  const state = {
    snapshot: null,
    activeTab: "picker",
    viewMode: "settings",
    privateMode: false,
    invoke: null,
    pickerTestUrl: "https://example.org",
    selectedPickerBrowserId: null,
  };

  const els = {
    tabs: Array.from(document.querySelectorAll(".tab")),
    statusline: document.getElementById("statusline"),
    configPathLine: document.getElementById("configPathLine"),
    defaultStatusSummary: document.getElementById("defaultStatusSummary"),
    recheckDefaultBtn: document.getElementById("recheckDefaultBtn"),
    setupDefaultBtn: document.getElementById("setupDefaultBtn"),
    reopenOnboardingBtn: document.getElementById("reopenOnboardingBtn"),
    panelPicker: document.getElementById("panel-picker"),
    panelBrowsers: document.getElementById("panel-browsers"),
    panelRules: document.getElementById("panel-rules"),
    onboardingModal: document.getElementById("onboardingModal"),
    defaultChecklist: document.getElementById("defaultChecklist"),
    browsersPathInput: document.getElementById("browsersPathInput"),
    rulesPathInput: document.getElementById("rulesPathInput"),
    importBrowsersBtn: document.getElementById("importBrowsersBtn"),
    importRulesBtn: document.getElementById("importRulesBtn"),
    detectBrowsersBtn: document.getElementById("detectBrowsersBtn"),
    openSetupBtn: document.getElementById("openSetupBtn"),
    skipOnboardingBtn: document.getElementById("skipOnboardingBtn"),
    finishOnboardingBtn: document.getElementById("finishOnboardingBtn"),
  };

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function setStatus(message, isError = false) {
    if (!message) {
      els.statusline.textContent = "";
      els.statusline.classList.remove("error");
      return;
    }
    els.statusline.textContent = message;
    els.statusline.classList.toggle("error", isError);
  }

  async function call(command, payload) {
    if (!state.invoke) {
      throw new Error("Tauri bridge is not ready yet.");
    }

    try {
      return await state.invoke(command, payload ?? {});
    } catch (error) {
      const message = String(error);
      setStatus(message, true);
      throw error;
    }
  }

  function renderDefaultSummary(snapshot) {
    const { default_browser: status } = snapshot;
    const badge = status.is_default ? "OK" : "Action Needed";
    const color = status.is_default ? "#147d58" : "#b06700";

    els.defaultStatusSummary.innerHTML = `
      <div><strong style="color:${color}">${badge}</strong></div>
      <div style="margin-top:6px">${escapeHtml(status.note)}</div>
      <div style="margin-top:6px" class="code">bundle: ${escapeHtml(status.app_bundle_id)}</div>
      <div class="code">http: ${escapeHtml(status.http_handler || "-")}</div>
      <div class="code">https: ${escapeHtml(status.https_handler || "-")}</div>
    `;
  }

  function browserMonogram(browser) {
    const source = (browser.name || browser.app_id || "?").trim();
    const match = source.match(/[A-Za-z0-9]/);
    return (match ? match[0] : "?").toUpperCase();
  }

  function syncSelectedPickerBrowser(browsers) {
    if (!browsers.length) {
      state.selectedPickerBrowserId = null;
      return;
    }

    const selectedExists = browsers.some((browser) => browser.id === state.selectedPickerBrowserId);
    if (!selectedExists) {
      state.selectedPickerBrowserId = browsers[0].id;
    }
  }

  async function openPendingUrlWithBrowser(browserId) {
    try {
      const outcome = await call("choose_browser_for_pending_url", {
        browserId,
        privateMode: state.privateMode,
      });
      setStatus(outcome.message, !outcome.ok);
      await refreshSnapshot();
    } catch {
      // handled in call()
    }
  }

  function renderPicker(snapshot) {
    const pendingUrl = snapshot.pending_url;
    const browsers = snapshot.configured_browsers;

    if (!pendingUrl) {
      els.panelPicker.innerHTML = `
        <h2 class="section-title">Picker</h2>
        <p class="subtle">No pending URL. URLs matching your rules auto-route and will not show picker.</p>
        <div class="row-actions">
          <input id="pickerTestUrlInput" type="text" value="${escapeHtml(state.pickerTestUrl)}" style="flex:1;min-width:320px" />
          <button id="queuePickerTestBtn" class="button secondary">Test Picker</button>
        </div>
        <p class="subtle">Use this to test picker UI without relying on default-browser handoff.</p>
      `;

      const testInput = document.getElementById("pickerTestUrlInput");
      const testButton = document.getElementById("queuePickerTestBtn");
      if (testInput && testButton) {
        testButton.addEventListener("click", async () => {
          const url = testInput.value.trim();
          state.pickerTestUrl = url;
          try {
            const outcome = await call("queue_test_url_for_picker", { url });
            setStatus(outcome.message, !outcome.ok);
            await refreshSnapshot();
          } catch {
            // handled in call()
          }
        });
      }
      return;
    }

    syncSelectedPickerBrowser(browsers);

    const pickerRows = browsers
      .map(
        (browser) => `
          <button
            class="picker-browser-pill ${state.selectedPickerBrowserId === browser.id ? "selected" : ""}"
            data-action="pick-browser"
            data-browser-id="${browser.id}"
            title="${escapeHtml(browser.name)}"
          >
            <span class="picker-browser-icon">${escapeHtml(browserMonogram(browser))}</span>
            <span class="picker-browser-text">
              <span class="picker-browser-name">${escapeHtml(browser.name)}</span>
              <span class="picker-browser-meta">${escapeHtml(browser.profile || browser.app_id)}</span>
            </span>
            <span class="picker-shortcut-badge">${escapeHtml(browser.shortcut_key)}</span>
          </button>
        `
      )
      .join("");

    els.panelPicker.innerHTML = `
      <h2 class="section-title">Picker</h2>
      <p class="subtle">No rule matched this URL. Use shortcut keys or click a browser.</p>
      <div class="picker-shell">
        <div class="picker-url">${escapeHtml(pendingUrl)}</div>
        <div class="picker-command-row">
          <button id="privateModeChip" class="command-chip ${state.privateMode ? "active" : ""}">
            <span class="key">P</span>
            <span>${state.privateMode ? "Private On" : "Private Off"}</span>
          </button>
          <span class="command-chip static"><span class="key">1-9</span><span>Quick Pick</span></span>
          <span class="command-chip static"><span class="key">Enter</span><span>Open Selected</span></span>
          <span class="command-chip static"><span class="key">Arrows</span><span>Move</span></span>
        </div>
        <div class="picker-browser-list">${pickerRows}</div>
      </div>
    `;

    const privateModeChip = document.getElementById("privateModeChip");
    if (privateModeChip) {
      privateModeChip.addEventListener("click", () => {
        state.privateMode = !state.privateMode;
        renderPicker(snapshot);
      });
    }

    Array.from(els.panelPicker.querySelectorAll('[data-action="pick-browser"]')).forEach((button) => {
      button.addEventListener("click", async () => {
        const browserId = button.getAttribute("data-browser-id");
        if (!browserId) {
          return;
        }
        state.selectedPickerBrowserId = browserId;
        await openPendingUrlWithBrowser(browserId);
      });
    });
  }

  function renderBrowsers(snapshot) {
    const rows = snapshot.configured_browsers
      .map(
        (browser) => `
          <tr>
            <td>${escapeHtml(browser.name)}</td>
            <td class="code">${escapeHtml(browser.app_id)}</td>
            <td class="code">${escapeHtml(browser.executable)}</td>
            <td>${escapeHtml(browser.shortcut_key)}</td>
            <td>${escapeHtml(browser.profile || "-")}</td>
          </tr>
        `
      )
      .join("");

    els.panelBrowsers.innerHTML = `
      <h2 class="section-title">Browsers</h2>
      <p class="subtle">Configured browsers used by picker and rules.</p>
      <div class="row-actions">
        <button id="detectBrowsersInline" class="button secondary">Detect Browsers</button>
      </div>
      <table class="table">
        <thead>
          <tr>
            <th>Name</th>
            <th>App ID / Bundle ID</th>
            <th>Executable</th>
            <th>Shortcut</th>
            <th>Profile</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    `;

    const inlineDetect = document.getElementById("detectBrowsersInline");
    if (inlineDetect) {
      inlineDetect.addEventListener("click", async () => {
        try {
          const outcome = await call("detect_browsers");
          setStatus(outcome.message, !outcome.ok);
          await refreshSnapshot();
        } catch {
          // handled in call()
        }
      });
    }
  }

  function renderRules(snapshot) {
    const rows = snapshot.routing_rules
      .map(
        (rule) => `
          <tr>
            <td>${rule.is_enabled ? "Yes" : "No"}</td>
            <td>${escapeHtml(rule.name)}</td>
            <td class="code">${escapeHtml(rule.host_pattern)}</td>
            <td>${escapeHtml(rule.path_prefix || "-")}</td>
            <td class="code">${escapeHtml(rule.browser_app_id)}</td>
            <td>${escapeHtml(rule.source_app_id || "-")}</td>
            <td>${rule.use_private_mode ? "Yes" : "No"}</td>
          </tr>
        `
      )
      .join("");

    els.panelRules.innerHTML = `
      <h2 class="section-title">Rules</h2>
      <p class="subtle">Rules are evaluated top-to-bottom. First enabled match wins.</p>
      <table class="table">
        <thead>
          <tr>
            <th>Enabled</th>
            <th>Name</th>
            <th>Host</th>
            <th>Path Prefix</th>
            <th>Browser</th>
            <th>Source App</th>
            <th>Private</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    `;
  }

  function renderOnboarding(snapshot) {
    const status = snapshot.default_browser;
    const checklistItems = [
      {
        ok: status.is_default,
        text: status.is_default
          ? "Default browser is set to Chowser Rust for http/https"
          : "Default browser is not set to Chowser Rust yet",
      },
      {
        ok: snapshot.configured_browsers.length > 0,
        text:
          snapshot.configured_browsers.length > 0
            ? `${snapshot.configured_browsers.length} browsers configured`
            : "No browsers configured",
      },
      {
        ok: snapshot.routing_rules.length > 0,
        text:
          snapshot.routing_rules.length > 0
            ? `${snapshot.routing_rules.length} rules loaded`
            : "No routing rules loaded yet",
      },
    ];

    els.defaultChecklist.innerHTML = checklistItems
      .map(
        (item) => `<div class="check-item ${item.ok ? "ok" : ""}">${item.ok ? "✓" : "•"} ${escapeHtml(item.text)}</div>`
      )
      .join("");

    if (!els.browsersPathInput.value) {
      els.browsersPathInput.value = snapshot.suggested_browsers_path;
    }
    if (!els.rulesPathInput.value) {
      els.rulesPathInput.value = snapshot.suggested_rules_path;
    }

    els.onboardingModal.classList.toggle("visible", !snapshot.has_completed_onboarding);
  }

  function render(snapshot) {
    els.configPathLine.textContent = `Config: ${snapshot.config_path}`;

    renderPicker(snapshot);

    if (state.viewMode === "picker") {
      els.panelPicker.classList.add("visible");
      els.panelBrowsers.classList.remove("visible");
      els.panelRules.classList.remove("visible");
      els.onboardingModal.classList.remove("visible");
      if (snapshot.status_line) {
        setStatus(snapshot.status_line, false);
      }
      return;
    }

    renderDefaultSummary(snapshot);
    renderBrowsers(snapshot);
    renderRules(snapshot);
    renderOnboarding(snapshot);

    if (snapshot.status_line) {
      setStatus(snapshot.status_line, false);
    }

    updateTabs();
  }

  function updateTabs() {
    const tabs = {
      picker: els.panelPicker,
      browsers: els.panelBrowsers,
      rules: els.panelRules,
    };

    Object.entries(tabs).forEach(([key, panel]) => {
      panel.classList.toggle("visible", key === state.activeTab);
    });

    els.tabs.forEach((tab) => {
      tab.classList.toggle("active", tab.dataset.tab === state.activeTab);
    });
  }

  async function refreshSnapshot() {
    try {
      const snapshot = await call("refresh_snapshot");
      state.snapshot = snapshot;
      render(snapshot);
      return snapshot;
    } catch {
      return null;
    }
  }

  function isTypingContext(target) {
    if (!target || !(target instanceof HTMLElement)) {
      return false;
    }
    if (target.isContentEditable) {
      return true;
    }

    const tag = target.tagName.toLowerCase();
    return tag === "input" || tag === "textarea" || tag === "select";
  }

  async function handlePickerKeyboardShortcuts(event) {
    if (isTypingContext(event.target)) {
      return;
    }

    if (state.activeTab !== "picker") {
      return;
    }

    const snapshot = state.snapshot;
    if (!snapshot || !snapshot.pending_url) {
      return;
    }

    const browsers = snapshot.configured_browsers ?? [];
    if (!browsers.length) {
      return;
    }

    syncSelectedPickerBrowser(browsers);
    const key = event.key;
    const normalized = key.length === 1 ? key.toLowerCase() : key;

    if (normalized === "p") {
      event.preventDefault();
      state.privateMode = !state.privateMode;
      renderPicker(snapshot);
      return;
    }

    if (/^[1-9]$/.test(normalized)) {
      const matching = browsers.find((browser) => String(browser.shortcut_key) === normalized);
      if (!matching) {
        return;
      }
      event.preventDefault();
      state.selectedPickerBrowserId = matching.id;
      await openPendingUrlWithBrowser(matching.id);
      return;
    }

    if (normalized === "ArrowLeft" || normalized === "ArrowUp") {
      event.preventDefault();
      const currentIndex = browsers.findIndex((browser) => browser.id === state.selectedPickerBrowserId);
      const nextIndex = currentIndex <= 0 ? browsers.length - 1 : currentIndex - 1;
      state.selectedPickerBrowserId = browsers[nextIndex].id;
      renderPicker(snapshot);
      return;
    }

    if (normalized === "ArrowRight" || normalized === "ArrowDown") {
      event.preventDefault();
      const currentIndex = browsers.findIndex((browser) => browser.id === state.selectedPickerBrowserId);
      const nextIndex = currentIndex === -1 || currentIndex >= browsers.length - 1 ? 0 : currentIndex + 1;
      state.selectedPickerBrowserId = browsers[nextIndex].id;
      renderPicker(snapshot);
      return;
    }

    if (normalized === "Enter") {
      event.preventDefault();
      const selected = browsers.find((browser) => browser.id === state.selectedPickerBrowserId) || browsers[0];
      state.selectedPickerBrowserId = selected.id;
      await openPendingUrlWithBrowser(selected.id);
    }
  }

  function bindEvents() {
    document.addEventListener("keydown", (event) => {
      handlePickerKeyboardShortcuts(event);
    });

    if (state.viewMode !== "picker") {
      els.tabs.forEach((tab) => {
        tab.addEventListener("click", () => {
          state.activeTab = tab.dataset.tab;
          updateTabs();
        });
      });
    }

    els.recheckDefaultBtn.addEventListener("click", async () => {
      await refreshSnapshot();
    });

    els.setupDefaultBtn.addEventListener("click", async () => {
      try {
        const outcome = await call("setup_default_browser");
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    });

    els.reopenOnboardingBtn.addEventListener("click", async () => {
      try {
        const outcome = await call("set_onboarding_completed", { completed: false });
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    });

    els.importBrowsersBtn.addEventListener("click", async () => {
      try {
        const outcome = await call("import_browsers_from_path", {
          path: els.browsersPathInput.value,
        });
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    });

    els.importRulesBtn.addEventListener("click", async () => {
      try {
        const outcome = await call("import_rules_from_path", {
          path: els.rulesPathInput.value,
        });
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    });

    const handleDetect = async () => {
      try {
        const outcome = await call("detect_browsers");
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    };

    els.detectBrowsersBtn.addEventListener("click", handleDetect);

    els.openSetupBtn.addEventListener("click", async () => {
      try {
        const outcome = await call("setup_default_browser");
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    });

    els.skipOnboardingBtn.addEventListener("click", async () => {
      try {
        const outcome = await call("set_onboarding_completed", { completed: true });
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    });

    els.finishOnboardingBtn.addEventListener("click", async () => {
      try {
        const outcome = await call("set_onboarding_completed", { completed: true });
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    });
  }

  function applyViewModeFromQuery() {
    const params = new URLSearchParams(window.location.search);
    const requestedMode = (params.get("view") || "settings").trim().toLowerCase();
    state.viewMode = requestedMode === "picker" ? "picker" : "settings";

    if (state.viewMode === "picker") {
      state.activeTab = "picker";
      document.body.classList.add("mode-picker");
    } else {
      document.body.classList.remove("mode-picker");
    }
  }

  function showBridgeUnavailableError() {
    const diagnostics = [
      `__TAURI__: ${typeof window.__TAURI__ !== "undefined"}`,
      `__TAURI__.core.invoke: ${typeof window.__TAURI__?.core?.invoke === "function"}`,
      `__TAURI__.invoke: ${typeof window.__TAURI__?.invoke === "function"}`,
      `__TAURI_INTERNALS__.invoke: ${typeof window.__TAURI_INTERNALS__?.invoke === "function"}`,
    ].join("<br/>");

    document.body.innerHTML = `<div style="padding:24px;font-family:-apple-system">
      Tauri bridge not available.<br/><br/>${diagnostics}
    </div>`;
  }

  async function waitForInvokeBridge(maxAttempts = 20, delayMs = 80) {
    for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
      const invoke = resolveInvoke();
      if (invoke) {
        return invoke;
      }
      // eslint-disable-next-line no-await-in-loop
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
    return undefined;
  }

  async function bootstrap() {
    const invoke = await waitForInvokeBridge();
    if (!invoke) {
      showBridgeUnavailableError();
      return;
    }

    state.invoke = invoke;
    applyViewModeFromQuery();
    bindEvents();
    await refreshSnapshot();

    const refreshIntervalMs = state.viewMode === "picker" ? 480 : 1400;
    setInterval(() => {
      refreshSnapshot();
    }, refreshIntervalMs);
  }

  bootstrap();
})();
