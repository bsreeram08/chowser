(() => {
  const resolveInvoke = () =>
    window.__TAURI__?.core?.invoke ??
    window.__TAURI__?.invoke ??
    (typeof window.__TAURI_INTERNALS__?.invoke === "function"
      ? (command, payload) => window.__TAURI_INTERNALS__.invoke(command, payload)
      : undefined);

  const state = {
    snapshot: null,
    snapshotSignature: null,
    activeTab: "picker",
    viewMode: "settings",
    privateMode: false,
    invoke: null,
    pickerTestUrl: "https://example.org",
    selectedPickerBrowserId: null,
    autostartEnabled: false,
    autostartSupported: true,
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
    // Browser form modal
    browserFormModal: document.getElementById("browserFormModal"),
    browserFormTitle: document.getElementById("browserFormTitle"),
    bf_name: document.getElementById("bf_name"),
    bf_appId: document.getElementById("bf_appId"),
    bf_executable: document.getElementById("bf_executable"),
    bf_shortcut: document.getElementById("bf_shortcut"),
    bf_profile: document.getElementById("bf_profile"),
    bf_customArgs: document.getElementById("bf_customArgs"),
    bf_editId: document.getElementById("bf_editId"),
    browserFormCancelBtn: document.getElementById("browserFormCancelBtn"),
    browserFormSaveBtn: document.getElementById("browserFormSaveBtn"),
    // Rule form modal
    ruleFormModal: document.getElementById("ruleFormModal"),
    ruleFormTitle: document.getElementById("ruleFormTitle"),
    rf_name: document.getElementById("rf_name"),
    rf_hostPattern: document.getElementById("rf_hostPattern"),
    rf_pathPrefix: document.getElementById("rf_pathPrefix"),
    rf_browserAppId: document.getElementById("rf_browserAppId"),
    rf_profile: document.getElementById("rf_profile"),
    rf_sourceAppId: document.getElementById("rf_sourceAppId"),
    rf_privateMode: document.getElementById("rf_privateMode"),
    rf_isEnabled: document.getElementById("rf_isEnabled"),
    rf_editId: document.getElementById("rf_editId"),
    ruleFormCancelBtn: document.getElementById("ruleFormCancelBtn"),
    ruleFormSaveBtn: document.getElementById("ruleFormSaveBtn"),
    // Quick rule modal
    quickRuleModal: document.getElementById("quickRuleModal"),
    quickRuleUrlDisplay: document.getElementById("quickRuleUrlDisplay"),
    qr_name: document.getElementById("qr_name"),
    qr_browserAppId: document.getElementById("qr_browserAppId"),
    qr_profile: document.getElementById("qr_profile"),
    qr_privateMode: document.getElementById("qr_privateMode"),
    quickRuleCancelBtn: document.getElementById("quickRuleCancelBtn"),
    quickRuleSaveBtn: document.getElementById("quickRuleSaveBtn"),
    // Confirm modal
    confirmModal: document.getElementById("confirmModal"),
    confirmMessage: document.getElementById("confirmMessage"),
    confirmCancelBtn: document.getElementById("confirmCancelBtn"),
    confirmOkBtn: document.getElementById("confirmOkBtn"),
  };

  // ── Utilities ───────────────────────────────────────────────────────────────

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

  function browserIsHidden(snapshot, browser) {
    const hidden = new Set(snapshot.hidden_app_ids || []);
    return hidden.has(browser.app_id);
  }

  function visiblePickerBrowsers(snapshot) {
    return (snapshot.configured_browsers || []).filter(
      (browser) => !browserIsHidden(snapshot, browser)
    );
  }

  // ── Confirm dialog ───────────────────────────────────────────────────────────

  // Track pending confirm resolver so Escape can cancel it properly
  let pendingConfirmCleanup = null;

  function showConfirm(message) {
    return new Promise((resolve) => {
      els.confirmMessage.textContent = message;
      els.confirmModal.classList.add("visible");
      const cleanup = (result) => {
        els.confirmModal.classList.remove("visible");
        els.confirmOkBtn.removeEventListener("click", onOk);
        els.confirmCancelBtn.removeEventListener("click", onCancel);
        pendingConfirmCleanup = null;
        resolve(result);
      };
      const onOk = () => cleanup(true);
      const onCancel = () => cleanup(false);
      // Replace any stale pending cleanup before registering new listeners
      if (pendingConfirmCleanup) {
        pendingConfirmCleanup(false);
      }
      pendingConfirmCleanup = cleanup;
      els.confirmOkBtn.addEventListener("click", onOk);
      els.confirmCancelBtn.addEventListener("click", onCancel);
    });
  }

  // ── Browser form modal ───────────────────────────────────────────────────────

  function openBrowserAddForm() {
    els.browserFormTitle.textContent = "Add Browser";
    els.bf_name.value = "";
    els.bf_appId.value = "";
    els.bf_executable.value = "";
    els.bf_shortcut.value = "";
    els.bf_profile.value = "";
    els.bf_customArgs.value = "";
    els.bf_editId.value = "";
    els.browserFormModal.classList.add("visible");
    els.bf_name.focus();
  }

  function openBrowserEditForm(browser) {
    els.browserFormTitle.textContent = "Edit Browser";
    els.bf_name.value = browser.name;
    els.bf_appId.value = browser.app_id;
    els.bf_executable.value = browser.executable;
    els.bf_shortcut.value = browser.shortcut_key;
    els.bf_profile.value = browser.profile || "";
    els.bf_customArgs.value = browser.custom_arguments || "";
    els.bf_editId.value = browser.id;
    els.browserFormModal.classList.add("visible");
    els.bf_name.focus();
  }

  function closeBrowserForm() {
    els.browserFormModal.classList.remove("visible");
  }

  async function saveBrowserForm() {
    const editId = els.bf_editId.value.trim();
    const payload = {
      name: els.bf_name.value,
      appId: els.bf_appId.value,
      executable: els.bf_executable.value,
      shortcutKey: els.bf_shortcut.value,
      profile: els.bf_profile.value || null,
      customArguments: els.bf_customArgs.value || null,
    };
    try {
      if (editId) {
        await call("update_browser", { id: editId, ...payload });
      } else {
        await call("add_browser", payload);
      }
      closeBrowserForm();
      await refreshSnapshot();
    } catch {
      // handled in call()
    }
  }

  // ── Rule form modal ──────────────────────────────────────────────────────────

  function openRuleAddForm(prefillHostPattern) {
    els.ruleFormTitle.textContent = "Add Rule";
    els.rf_name.value = "";
    els.rf_hostPattern.value = prefillHostPattern || "";
    els.rf_pathPrefix.value = "";
    els.rf_browserAppId.value =
      state.snapshot?.configured_browsers[0]?.app_id || "";
    els.rf_profile.value = "";
    els.rf_sourceAppId.value = "";
    els.rf_privateMode.checked = false;
    els.rf_isEnabled.checked = true;
    els.rf_editId.value = "";
    els.ruleFormModal.classList.add("visible");
    els.rf_name.focus();
  }

  function openRuleEditForm(rule) {
    els.ruleFormTitle.textContent = "Edit Rule";
    els.rf_name.value = rule.name;
    els.rf_hostPattern.value = rule.host_pattern;
    els.rf_pathPrefix.value = rule.path_prefix || "";
    els.rf_browserAppId.value = rule.browser_app_id;
    els.rf_profile.value = rule.profile || "";
    els.rf_sourceAppId.value = rule.source_app_id || "";
    els.rf_privateMode.checked = !!rule.use_private_mode;
    els.rf_isEnabled.checked = !!rule.is_enabled;
    els.rf_editId.value = rule.id;
    els.ruleFormModal.classList.add("visible");
    els.rf_name.focus();
  }

  function closeRuleForm() {
    els.ruleFormModal.classList.remove("visible");
  }

  async function saveRuleForm() {
    const editId = els.rf_editId.value.trim();
    const payload = {
      name: els.rf_name.value,
      hostPattern: els.rf_hostPattern.value,
      pathPrefix: els.rf_pathPrefix.value || null,
      browserAppId: els.rf_browserAppId.value,
      profile: els.rf_profile.value || null,
      sourceAppId: els.rf_sourceAppId.value || null,
      usePrivateMode: els.rf_privateMode.checked,
      isEnabled: els.rf_isEnabled.checked,
    };
    try {
      if (editId) {
        await call("update_rule", { id: editId, ...payload });
      } else {
        await call("add_rule", payload);
      }
      closeRuleForm();
      await refreshSnapshot();
    } catch {
      // handled in call()
    }
  }

  // ── Quick rule modal (picker mode) ───────────────────────────────────────────

  function openQuickRuleModal() {
    const snapshot = state.snapshot;
    if (!snapshot || !snapshot.pending_url) return;
    let host = "";
    try {
      host = new URL(snapshot.pending_url).hostname;
    } catch {
      host = "";
    }
    els.quickRuleUrlDisplay.textContent = `Host: ${host}`;
    els.qr_name.value = host;
    els.qr_browserAppId.value =
      visiblePickerBrowsers(snapshot)[0]?.app_id ||
      snapshot.configured_browsers[0]?.app_id ||
      "";
    els.qr_profile.value = "";
    els.qr_privateMode.checked = false;
    els.quickRuleModal.classList.add("visible");
    els.qr_name.focus();
  }

  function closeQuickRuleModal() {
    els.quickRuleModal.classList.remove("visible");
  }

  async function saveQuickRule() {
    try {
      await call("create_rule_for_pending_url", {
        name: els.qr_name.value,
        browserAppId: els.qr_browserAppId.value,
        profile: els.qr_profile.value || null,
        usePrivateMode: els.qr_privateMode.checked,
      });
      closeQuickRuleModal();
      await refreshSnapshot();
    } catch {
      // handled in call()
    }
  }

  // ── Rendering ────────────────────────────────────────────────────────────────

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
      <label style="display:flex;align-items:center;gap:8px;margin-top:10px;opacity:${state.autostartSupported ? "1" : "0.6"}">
        <input id="launchAtLoginToggle" type="checkbox" ${state.autostartEnabled ? "checked" : ""} ${state.autostartSupported ? "" : "disabled"} />
        <span>Launch at login</span>
      </label>
    `;

    document
      .getElementById("launchAtLoginToggle")
      ?.addEventListener("change", async (event) => {
        const enabled = !!event.target?.checked;
        try {
          await call(enabled ? "plugin:autostart|enable" : "plugin:autostart|disable");
          state.autostartEnabled = enabled;
          setStatus(
            enabled ? "Launch at login enabled" : "Launch at login disabled",
            false
          );
        } catch {
          await refreshAutostartStatus();
          renderDefaultSummary(snapshot);
        }
      });
  }

  async function refreshAutostartStatus() {
    try {
      const enabled = await call("plugin:autostart|is_enabled");
      state.autostartEnabled = !!enabled;
      state.autostartSupported = true;
    } catch {
      state.autostartEnabled = false;
      state.autostartSupported = false;
    }
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
    const selectedExists = browsers.some(
      (browser) => browser.id === state.selectedPickerBrowserId
    );
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
    const browsers = visiblePickerBrowsers(snapshot);

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
    const emptyPickerMessage = browsers.length
      ? ""
      : `<p class="subtle">No visible browsers are available. Unhide apps in Settings → Browsers.</p>`;

    els.panelPicker.innerHTML = `
      <h2 class="section-title">Picker</h2>
      <p class="subtle">No rule matched this URL. Use shortcut keys, initials, or click a browser.</p>
      <div class="picker-shell">
        <div class="picker-url">${escapeHtml(pendingUrl)}</div>
        <div class="picker-command-row">
          <button id="privateModeChip" class="command-chip ${state.privateMode ? "active" : ""}">
            <span class="key">P</span>
            <span>${state.privateMode ? "Private On" : "Private Off"}</span>
          </button>
          <button id="createRuleChip" class="command-chip">
            <span class="key">R</span>
            <span>Create Rule</span>
          </button>
          <span class="command-chip static"><span class="key">1-9</span><span>Quick Pick</span></span>
          <span class="command-chip static"><span class="key">A-Z</span><span>Initial Select</span></span>
          <span class="command-chip static"><span class="key">Enter</span><span>Open Selected</span></span>
          <span class="command-chip static"><span class="key">Arrows</span><span>Move</span></span>
        </div>
        <div class="picker-browser-list">${pickerRows}</div>
        ${emptyPickerMessage}
      </div>
    `;

    document.getElementById("privateModeChip")?.addEventListener("click", () => {
      state.privateMode = !state.privateMode;
      updatePickerPrivateModeChip();
    });

    document.getElementById("createRuleChip")?.addEventListener("click", () => {
      openQuickRuleModal();
    });

    Array.from(
      els.panelPicker.querySelectorAll('[data-action="pick-browser"]')
    ).forEach((button) => {
      button.addEventListener("click", async () => {
        const browserId = button.getAttribute("data-browser-id");
        if (!browserId) return;
        state.selectedPickerBrowserId = browserId;
        await openPendingUrlWithBrowser(browserId);
      });
    });
  }

  function updatePickerPrivateModeChip() {
    const chip = document.getElementById("privateModeChip");
    if (!chip) return;
    chip.classList.toggle("active", state.privateMode);
    const label = chip.querySelector("span:last-child");
    if (label) {
      label.textContent = state.privateMode ? "Private On" : "Private Off";
    }
  }

  function updatePickerSelectionHighlight() {
    const buttons = Array.from(
      els.panelPicker.querySelectorAll('[data-action="pick-browser"]')
    );
    buttons.forEach((button) => {
      const browserId = button.getAttribute("data-browser-id");
      button.classList.toggle(
        "selected",
        browserId === state.selectedPickerBrowserId
      );
    });
  }

  function renderBrowsers(snapshot) {
    const browsers = snapshot.configured_browsers;
    const hiddenApps = new Set(snapshot.hidden_app_ids || []);

    const rows = browsers
      .map(
        (browser, index) => `
          <tr>
            <td>${escapeHtml(browser.name)}</td>
            <td class="code">${escapeHtml(browser.app_id)}</td>
             <td class="code">${escapeHtml(browser.executable)}</td>
             <td>${escapeHtml(browser.shortcut_key)}</td>
             <td>${escapeHtml(browser.profile || "-")}</td>
             <td>${hiddenApps.has(browser.app_id) ? "Yes" : "No"}</td>
             <td class="actions-cell">
               <button class="btn-icon" data-action="toggle-hidden-browser" data-app-id="${escapeHtml(browser.app_id)}" title="${hiddenApps.has(browser.app_id) ? "Unhide app" : "Hide app"}">${hiddenApps.has(browser.app_id) ? "👁" : "🙈"}</button>
               <button class="btn-icon" data-action="edit-browser" data-id="${browser.id}" title="Edit">✏</button>
              <button class="btn-icon" data-action="move-browser-up" data-id="${browser.id}" title="Move up" ${index === 0 ? "disabled" : ""}>↑</button>
              <button class="btn-icon" data-action="move-browser-down" data-id="${browser.id}" title="Move down" ${index === browsers.length - 1 ? "disabled" : ""}>↓</button>
              <button class="btn-icon danger" data-action="delete-browser" data-id="${browser.id}" data-name="${escapeHtml(browser.name)}" title="Delete">✕</button>
            </td>
          </tr>
        `
      )
      .join("");

    els.panelBrowsers.innerHTML = `
      <div class="panel-header">
        <div>
          <h2 class="section-title">Browsers</h2>
          <p class="subtle">Configure which browsers appear in the picker.</p>
        </div>
        <div class="panel-header-actions">
          <button id="detectBrowsersInline" class="button secondary tiny">Detect</button>
          <button id="addBrowserBtn" class="button primary tiny">+ Add Browser</button>
        </div>
      </div>
      ${
        browsers.length > 0
          ? `<table class="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>App ID / Bundle ID</th>
                <th>Executable</th>
                <th>Shortcut</th>
                <th>Profile</th>
                <th>Hidden</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>${rows}</tbody>
          </table>`
          : `<p class="subtle">No browsers configured. Click <strong>+ Add Browser</strong> or <strong>Detect</strong> to get started.</p>`
      }
      <div class="export-row">
        <span class="subtle" style="white-space:nowrap">Export browsers:</span>
        <input id="exportBrowsersPath" type="text" placeholder="${escapeHtml(snapshot.suggested_browsers_path)}" />
        <button id="exportBrowsersBtn" class="button secondary tiny" ${browsers.length === 0 ? "disabled" : ""}>Export</button>
      </div>
      ${
        hiddenApps.size > 0
          ? `<p class="subtle" style="margin-top:8px">Hidden app IDs: ${escapeHtml(
              Array.from(hiddenApps).join(", ")
            )}</p>`
          : ""
      }
    `;

    document.getElementById("addBrowserBtn")?.addEventListener("click", () => {
      openBrowserAddForm();
    });

    document.getElementById("detectBrowsersInline")?.addEventListener("click", async () => {
      try {
        const outcome = await call("detect_browsers");
        setStatus(outcome.message, !outcome.ok);
        await refreshSnapshot();
      } catch {
        // handled
      }
    });

    document.getElementById("exportBrowsersBtn")?.addEventListener("click", async () => {
      const path = document.getElementById("exportBrowsersPath").value.trim();
      try {
        const outcome = await call("export_browsers_to_path", { path });
        setStatus(outcome.message, !outcome.ok);
      } catch {
        // handled
      }
    });

    // Row actions
    els.panelBrowsers.querySelectorAll("[data-action]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const action = btn.getAttribute("data-action");
        const id = btn.getAttribute("data-id");
        const appId = btn.getAttribute("data-app-id");
        const name = btn.getAttribute("data-name") || "";
        if (action === "edit-browser") {
          const browser = snapshot.configured_browsers.find((b) => b.id === id);
          if (browser) openBrowserEditForm(browser);
        } else if (action === "toggle-hidden-browser") {
          if (!appId) return;
          const currentlyHidden = hiddenApps.has(appId);
          try {
            await call("set_hidden_app", { appId, hidden: !currentlyHidden });
            await refreshSnapshot();
          } catch {
            // handled
          }
        } else if (action === "delete-browser") {
          const confirmed = await showConfirm(`Delete browser "${name}"?`);
          if (!confirmed) return;
          try {
            await call("delete_browser", { id });
            await refreshSnapshot();
          } catch {
            // handled
          }
        } else if (action === "move-browser-up" || action === "move-browser-down") {
          const ids = snapshot.configured_browsers.map((b) => b.id);
          const idx = ids.indexOf(id);
          if (action === "move-browser-up" && idx > 0) {
            [ids[idx - 1], ids[idx]] = [ids[idx], ids[idx - 1]];
          } else if (action === "move-browser-down" && idx < ids.length - 1) {
            [ids[idx], ids[idx + 1]] = [ids[idx + 1], ids[idx]];
          }
          try {
            await call("reorder_browsers", { orderedIds: ids });
            await refreshSnapshot();
          } catch {
            // handled
          }
        }
      });
    });
  }

  function renderRules(snapshot) {
    const rules = snapshot.routing_rules;
    const rows = rules
      .map(
        (rule, index) => `
          <tr>
            <td>
              <input type="checkbox" class="rule-toggle" data-action="toggle-rule" data-id="${rule.id}" ${rule.is_enabled ? "checked" : ""} title="${rule.is_enabled ? "Enabled" : "Disabled"}" />
            </td>
            <td>${escapeHtml(rule.name)}</td>
            <td class="code">${escapeHtml(rule.host_pattern)}</td>
            <td>${escapeHtml(rule.path_prefix || "-")}</td>
            <td class="code">${escapeHtml(rule.browser_app_id)}</td>
            <td>${escapeHtml(rule.source_app_id || "-")}</td>
            <td>${rule.use_private_mode ? "Yes" : "No"}</td>
            <td class="actions-cell">
              <button class="btn-icon" data-action="edit-rule" data-id="${rule.id}" title="Edit">✏</button>
              <button class="btn-icon" data-action="move-rule-up" data-id="${rule.id}" title="Move up" ${index === 0 ? "disabled" : ""}>↑</button>
              <button class="btn-icon" data-action="move-rule-down" data-id="${rule.id}" title="Move down" ${index === rules.length - 1 ? "disabled" : ""}>↓</button>
              <button class="btn-icon danger" data-action="delete-rule" data-id="${rule.id}" data-name="${escapeHtml(rule.name)}" title="Delete">✕</button>
            </td>
          </tr>
        `
      )
      .join("");

    els.panelRules.innerHTML = `
      <div class="panel-header">
        <div>
          <h2 class="section-title">Rules</h2>
          <p class="subtle">Rules are evaluated top-to-bottom. First enabled match wins.</p>
        </div>
        <div class="panel-header-actions">
          <button id="addRuleBtn" class="button primary tiny" ${snapshot.configured_browsers.length === 0 ? "disabled" : ""}>+ Add Rule</button>
        </div>
      </div>
      ${
        snapshot.suggestions.length > 0
          ? renderSuggestions(snapshot.suggestions, snapshot.configured_browsers)
          : ""
      }
      ${
        rules.length > 0
          ? `<table class="table">
            <thead>
              <tr>
                <th>On</th>
                <th>Name</th>
                <th>Host</th>
                <th>Path Prefix</th>
                <th>Browser</th>
                <th>Source App</th>
                <th>Private</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>${rows}</tbody>
          </table>`
          : `<p class="subtle">No rules configured. Click <strong>+ Add Rule</strong> to create your first rule.</p>`
      }
      <div class="export-row">
        <span class="subtle" style="white-space:nowrap">Export rules:</span>
        <input id="exportRulesPath" type="text" placeholder="${escapeHtml(snapshot.suggested_rules_path)}" />
        <button id="exportRulesBtn" class="button secondary tiny" ${rules.length === 0 ? "disabled" : ""}>Export</button>
      </div>
    `;

    document.getElementById("addRuleBtn")?.addEventListener("click", () => {
      openRuleAddForm();
    });

    document.getElementById("exportRulesBtn")?.addEventListener("click", async () => {
      const path = document.getElementById("exportRulesPath").value.trim();
      try {
        const outcome = await call("export_rules_to_path", { path });
        setStatus(outcome.message, !outcome.ok);
      } catch {
        // handled
      }
    });

    // Toggle checkboxes
    els.panelRules.querySelectorAll('[data-action="toggle-rule"]').forEach((checkbox) => {
      checkbox.addEventListener("change", async () => {
        const id = checkbox.getAttribute("data-id");
        try {
          await call("toggle_rule", { id, isEnabled: checkbox.checked });
          await refreshSnapshot();
        } catch {
          checkbox.checked = !checkbox.checked;
        }
      });
    });

    // Row action buttons
    els.panelRules.querySelectorAll("[data-action]").forEach((btn) => {
      if (btn.tagName === "INPUT") return; // handled above
      btn.addEventListener("click", async () => {
        const action = btn.getAttribute("data-action");
        const id = btn.getAttribute("data-id");
        const name = btn.getAttribute("data-name") || "";
        if (action === "edit-rule") {
          const rule = snapshot.routing_rules.find((r) => r.id === id);
          if (rule) openRuleEditForm(rule);
        } else if (action === "delete-rule") {
          const confirmed = await showConfirm(`Delete rule "${name}"?`);
          if (!confirmed) return;
          try {
            await call("delete_rule", { id });
            await refreshSnapshot();
          } catch {
            // handled
          }
        } else if (action === "move-rule-up" || action === "move-rule-down") {
          const ids = snapshot.routing_rules.map((r) => r.id);
          const idx = ids.indexOf(id);
          if (action === "move-rule-up" && idx > 0) {
            [ids[idx - 1], ids[idx]] = [ids[idx], ids[idx - 1]];
          } else if (action === "move-rule-down" && idx < ids.length - 1) {
            [ids[idx], ids[idx + 1]] = [ids[idx + 1], ids[idx]];
          }
          try {
            await call("reorder_rules", { orderedIds: ids });
            await refreshSnapshot();
          } catch {
            // handled
          }
        }
      });
    });

    // Suggestions buttons
    els.panelRules.querySelectorAll("[data-action='create-rule-suggestion']").forEach((btn) => {
      btn.addEventListener("click", () => {
        const domain = btn.getAttribute("data-domain");
        const appId = btn.getAttribute("data-appid");
        openRuleAddForm(domain);
        // Pre-fill browser app id if possible
        const browser = snapshot.configured_browsers.find((b) => b.app_id === appId);
        if (browser) els.rf_browserAppId.value = browser.app_id;
      });
    });

    els.panelRules.querySelectorAll("[data-action='dismiss-suggestion']").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const domain = btn.getAttribute("data-domain");
        const appId = btn.getAttribute("data-appid");
        try {
          await call("dismiss_suggestion", { domain, appId });
          await refreshSnapshot();
        } catch {
          // handled
        }
      });
    });
  }

  function renderSuggestions(suggestions, browsers) {
    const browserName = (appId) => {
      const b = browsers.find((br) => br.app_id === appId);
      return b ? b.name : appId;
    };

    const items = suggestions
      .slice(0, 5)
      .map(
        (s) => `
          <div class="suggestion-item">
            <span class="domain">${escapeHtml(s.domain)}</span>
            <span class="suggestion-count">${s.count}× via ${escapeHtml(browserName(s.app_id))}</span>
            <button class="button tiny secondary" data-action="create-rule-suggestion" data-domain="${escapeHtml(s.domain)}" data-appid="${escapeHtml(s.app_id)}">Create Rule</button>
            <button class="btn-icon" data-action="dismiss-suggestion" data-domain="${escapeHtml(s.domain)}" data-appid="${escapeHtml(s.app_id)}" title="Dismiss">✕</button>
          </div>
        `
      )
      .join("");

    return `
      <div class="suggestions-section">
        <h3>💡 Suggested Rules</h3>
        <p class="subtle">These domains are frequently opened. Consider creating rules for them.</p>
        ${items}
      </div>
    `;
  }

  function renderOnboarding(snapshot) {
    const status = snapshot.default_browser;
    const checklistItems = [
      {
        ok: status.is_default,
        text: status.is_default
          ? "Default browser is set to Chowser for http/https"
          : "Default browser is not set to Chowser yet",
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
        (item) =>
          `<div class="check-item ${item.ok ? "ok" : ""}">${item.ok ? "✓" : "•"} ${escapeHtml(item.text)}</div>`
      )
      .join("");

    if (!els.browsersPathInput.value) {
      els.browsersPathInput.value = snapshot.suggested_browsers_path;
    }
    if (!els.rulesPathInput.value) {
      els.rulesPathInput.value = snapshot.suggested_rules_path;
    }

    els.onboardingModal.classList.toggle(
      "visible",
      !snapshot.has_completed_onboarding
    );
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
      const snapshotSignature = JSON.stringify(snapshot);
      state.snapshot = snapshot;
      if (state.snapshotSignature !== snapshotSignature) {
        state.snapshotSignature = snapshotSignature;
        render(snapshot);
      }
      return snapshot;
    } catch {
      return null;
    }
  }

  function isTypingContext(target) {
    if (!target || !(target instanceof HTMLElement)) return false;
    if (target.isContentEditable) return true;
    const tag = target.tagName.toLowerCase();
    return tag === "input" || tag === "textarea" || tag === "select";
  }

  async function handlePickerKeyboardShortcuts(event) {
    if (state.activeTab !== "picker" && state.viewMode !== "picker") return;

    const snapshot = state.snapshot;
    if (!snapshot || !snapshot.pending_url) return;

    const key = event.key;
    const normalized = key.length === 1 ? key.toLowerCase() : key;
    const hasModifier = event.metaKey || event.ctrlKey || event.altKey;

    if (!hasModifier && normalized === "p") {
      event.preventDefault();
      state.privateMode = !state.privateMode;
      updatePickerPrivateModeChip();
      return;
    }

    if (isTypingContext(event.target)) return;

    const browsers = visiblePickerBrowsers(snapshot);
    if (!browsers.length) return;

    syncSelectedPickerBrowser(browsers);

    if (normalized === "r") {
      event.preventDefault();
      openQuickRuleModal();
      return;
    }

    if (/^[1-9]$/.test(normalized)) {
      const matching = browsers.find(
        (browser) => String(browser.shortcut_key) === normalized
      );
      if (!matching) return;
      event.preventDefault();
      state.selectedPickerBrowserId = matching.id;
      await openPendingUrlWithBrowser(matching.id);
      return;
    }

    if (normalized === "ArrowLeft" || normalized === "ArrowUp") {
      event.preventDefault();
      const currentIndex = browsers.findIndex(
        (browser) => browser.id === state.selectedPickerBrowserId
      );
      const nextIndex =
        currentIndex <= 0 ? browsers.length - 1 : currentIndex - 1;
      state.selectedPickerBrowserId = browsers[nextIndex].id;
      updatePickerSelectionHighlight();
      return;
    }

    if (normalized === "ArrowRight" || normalized === "ArrowDown") {
      event.preventDefault();
      const currentIndex = browsers.findIndex(
        (browser) => browser.id === state.selectedPickerBrowserId
      );
      const nextIndex =
        currentIndex === -1 || currentIndex >= browsers.length - 1
          ? 0
          : currentIndex + 1;
      state.selectedPickerBrowserId = browsers[nextIndex].id;
      updatePickerSelectionHighlight();
      return;
    }

    if (!hasModifier && /^[a-z0-9]$/i.test(normalized)) {
      const matching = browsers.filter(
        (browser) => browserMonogram(browser).toLowerCase() === normalized
      );
      if (!matching.length) return;
      event.preventDefault();
      const currentIndex = matching.findIndex(
        (browser) => browser.id === state.selectedPickerBrowserId
      );
      const next =
        currentIndex >= 0 && currentIndex < matching.length - 1
          ? matching[currentIndex + 1]
          : matching[0];
      state.selectedPickerBrowserId = next.id;
      updatePickerSelectionHighlight();
      return;
    }

    if (normalized === "Enter") {
      event.preventDefault();
      const selected =
        browsers.find(
          (browser) => browser.id === state.selectedPickerBrowserId
        ) || browsers[0];
      state.selectedPickerBrowserId = selected.id;
      await openPendingUrlWithBrowser(selected.id);
    }
  }

  function bindEvents() {
    document.addEventListener("keydown", (event) => {
      // Close modals on Escape
      if (event.key === "Escape") {
        if (els.browserFormModal.classList.contains("visible")) {
          closeBrowserForm();
          return;
        }
        if (els.ruleFormModal.classList.contains("visible")) {
          closeRuleForm();
          return;
        }
        if (els.quickRuleModal.classList.contains("visible")) {
          closeQuickRuleModal();
          return;
        }
        if (els.confirmModal.classList.contains("visible")) {
          if (pendingConfirmCleanup) {
            pendingConfirmCleanup(false);
          } else {
            els.confirmModal.classList.remove("visible");
          }
          return;
        }
      }
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
        const outcome = await call("set_onboarding_completed", {
          completed: false,
        });
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
        const outcome = await call("set_onboarding_completed", {
          completed: true,
        });
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    });

    els.finishOnboardingBtn.addEventListener("click", async () => {
      try {
        const outcome = await call("set_onboarding_completed", {
          completed: true,
        });
        setStatus(outcome.message, !outcome.ok);
      } finally {
        await refreshSnapshot();
      }
    });

    // Browser form modal buttons
    els.browserFormCancelBtn.addEventListener("click", closeBrowserForm);
    els.browserFormSaveBtn.addEventListener("click", saveBrowserForm);

    // Rule form modal buttons
    els.ruleFormCancelBtn.addEventListener("click", closeRuleForm);
    els.ruleFormSaveBtn.addEventListener("click", saveRuleForm);

    // Quick rule modal buttons
    els.quickRuleCancelBtn.addEventListener("click", closeQuickRuleModal);
    els.quickRuleSaveBtn.addEventListener("click", saveQuickRule);
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
      if (invoke) return invoke;
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
    await refreshAutostartStatus();
    await refreshSnapshot();

    const refreshIntervalMs = state.viewMode === "picker" ? 480 : 1400;
    setInterval(() => {
      refreshSnapshot();
    }, refreshIntervalMs);
  }

  bootstrap();
})();
