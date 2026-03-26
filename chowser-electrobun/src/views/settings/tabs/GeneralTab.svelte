<script lang="ts">
  import Toggle from '../../shared/components/Toggle.svelte';
  import Button from '../../shared/components/Button.svelte';
  import Card from '../../shared/components/Card.svelte';
  import { onMount } from 'svelte';

  interface GeneralTabProps {
    rpc: any;
  }

  let { rpc } = $props<GeneralTabProps>();

  // State
  let pickerLayout = $state<'icons' | 'list'>('icons');
  let launchAtLogin = $state(false);
  let isDefaultBrowser = $state(false);
  let appVersion = $state('1.0.0');
  let mcpStatus = $state<{
    isRunning: boolean;
    port: number;
    authToken: string;
  } | null>(null);
  let tokenCopied = $state(false);
  let isLoading = $state(true);
  let error = $state<string | null>(null);

  // Load state on mount
  onMount(async () => {
    try {
      const state = await rpc.request('getState', undefined);
      pickerLayout = state.pickerLayout || 'icons';
      launchAtLogin = state.launchAtLogin || false;
      
      // Get app version
      appVersion = state.appVersion || '1.0.0';
      
      // Get MCP status
      if (state.mcpStatus) {
        mcpStatus = {
          isRunning: state.mcpStatus.isRunning,
          port: state.mcpStatus.port,
          authToken: state.mcpStatus.authToken || '',
        };
      }
      
      isLoading = false;
    } catch (err) {
      console.error('Failed to load general settings:', err);
      error = 'Failed to load settings';
      isLoading = false;
    }
  });

  // Save picker layout
  async function handlePickerLayoutChange(newLayout: 'icons' | 'list') {
    pickerLayout = newLayout;
    try {
      await rpc.request('setPickerLayout', { layout: newLayout });
    } catch (err) {
      console.error('Failed to save picker layout:', err);
      error = 'Failed to save preference';
    }
  }

  // Save launch at login
  async function handleLaunchAtLoginChange(newValue: boolean) {
    launchAtLogin = newValue;
    try {
      await rpc.request('setLaunchAtLogin', { enabled: newValue });
    } catch (err) {
      console.error('Failed to save launch at login:', err);
      launchAtLogin = !newValue; // Revert on error
      error = 'Failed to save preference';
    }
  }

  // Set as default browser
  async function handleSetAsDefaultBrowser() {
    try {
      await rpc.request('openDefaultBrowserSettings', undefined);
    } catch (err) {
      console.error('Failed to open browser settings:', err);
      error = 'Failed to open settings';
    }
  }

  // Toggle MCP server
  async function handleToggleMcpServer() {
    try {
      const newStatus = await rpc.request('toggleMcpServer', undefined);
      mcpStatus = {
        isRunning: newStatus.isRunning,
        port: newStatus.port,
        authToken: newStatus.authToken || '',
      };
    } catch (err) {
      console.error('Failed to toggle MCP server:', err);
      error = 'Failed to toggle server';
    }
  }

  // Copy auth token
  async function handleCopyToken() {
    if (!mcpStatus?.authToken) return;
    try {
      await navigator.clipboard.writeText(mcpStatus.authToken);
      tokenCopied = true;
      setTimeout(() => {
        tokenCopied = false;
      }, 2000);
    } catch (err) {
      console.error('Failed to copy token:', err);
      error = 'Failed to copy token';
    }
  }

  // Reset to defaults
  async function handleResetToDefaults() {
    if (!confirm('Are you sure? This will reset all your settings to defaults.')) {
      return;
    }
    try {
      await rpc.request('resetToDefaults', undefined);
      // Reload page to reflect changes
      window.location.reload();
    } catch (err) {
      console.error('Failed to reset to defaults:', err);
      error = 'Failed to reset settings';
    }
  }
</script>

<div class="general-tab">
  {#if isLoading}
    <div class="loading">Loading settings...</div>
  {:else if error}
    <div class="error">{error}</div>
  {/if}

  <!-- Picker Appearance Section -->
  <section class="settings-section">
    <div class="section-header">
      <h2>Picker Appearance</h2>
      <p>Customize how the browser picker looks</p>
    </div>

    <Card>
      <div class="settings-group">
        <div class="setting-row">
          <div class="setting-label">
            <label for="layout-select">Layout</label>
            <span class="help-text">Choose between icon grid or list view</span>
          </div>
          <div class="setting-control">
            <select
              id="layout-select"
              value={pickerLayout}
              onchange={(e) => handlePickerLayoutChange(e.currentTarget.value as 'icons' | 'list')}
            >
              <option value="icons">Icons</option>
              <option value="list">List</option>
            </select>
          </div>
        </div>
      </div>
    </Card>
  </section>

  <!-- System Integration Section -->
  <section class="settings-section">
    <div class="section-header">
      <h2>System Integration</h2>
      <p>Control how Chowser integrates with your Mac</p>
    </div>

    <Card>
      <div class="settings-group">
        <div class="setting-row">
          <div class="setting-label">
            <label for="launch-login-toggle">Launch at Login</label>
            <span class="help-text">Automatically start Chowser when you log in</span>
          </div>
          <div class="setting-control">
            <Toggle
              checked={launchAtLogin}
              onchange={handleLaunchAtLoginChange}
            />
          </div>
        </div>

        <div class="setting-row">
          <div class="setting-label">
            <label>Default Browser</label>
            <span class="help-text">
              <span class="status-badge">
                Manage in System Settings
              </span>
            </span>
          </div>
          <div class="setting-control">
            <Button
              variant="secondary"
              size="sm"
              onclick={handleSetAsDefaultBrowser}
            >
              Open Settings
            </Button>
          </div>
        </div>
      </div>
    </Card>
  </section>

  <!-- MCP Server Section -->
  <section class="settings-section">
    <div class="section-header">
      <h2>MCP Server</h2>
      <p>Local API for AI-driven management of browsers and rules</p>
    </div>

    <Card>
      <div class="settings-group">
        {#if mcpStatus}
          <div class="mcp-status">
            <div class="status-indicator" class:running={mcpStatus.isRunning} />
            <div class="status-info">
              <div class="status-text">
                {#if mcpStatus.isRunning}
                  <span class="status-label">Running</span>
                  <span class="port-info">on port {mcpStatus.port}</span>
                {:else}
                  <span class="status-label">Stopped</span>
                {/if}
              </div>
            </div>
            <Button
              variant="secondary"
              size="sm"
              onclick={handleToggleMcpServer}
            >
              {mcpStatus.isRunning ? 'Stop' : 'Start'}
            </Button>
          </div>

          {#if mcpStatus.isRunning && mcpStatus.authToken}
            <div class="mcp-token-section">
              <div class="token-label">Auth Token</div>
              <div class="token-display">
                <code>{mcpStatus.authToken}</code>
                <Button
                  variant="ghost"
                  size="sm"
                  onclick={handleCopyToken}
                >
                  {tokenCopied ? '✓ Copied' : 'Copy'}
                </Button>
              </div>
              <span class="help-text">Use this token to authenticate POST/DELETE requests to the API</span>
            </div>
          {/if}

          <p class="mcp-help-text">
            The local API server lets AI assistants (Claude, personal agents, etc.) configure your browsers and rules.
          </p>
        {/if}
      </div>
    </Card>
  </section>

  <!-- About Section -->
  <section class="settings-section">
    <div class="section-header">
      <h2>About</h2>
      <p>Application information</p>
    </div>

    <Card>
      <div class="about-content">
        <div class="about-icon">🧭</div>
        <div class="about-info">
          <div class="about-name">Chowser</div>
          <div class="about-desc">A smart browser router for macOS</div>
          <div class="about-version">Version {appVersion}</div>
        </div>
      </div>
    </Card>
  </section>

  <!-- Maintenance Section -->
  <section class="settings-section">
    <div class="section-header">
      <h2>Maintenance</h2>
      <p>Advanced actions</p>
    </div>

    <Card>
      <div class="settings-group">
        <Button
          variant="secondary"
          size="sm"
          onclick={handleResetToDefaults}
        >
          Reset to Defaults
        </Button>
        <p class="help-text">
          This will reset all your settings, browsers, and rules to factory defaults.
        </p>
      </div>
    </Card>
  </section>
</div>

<style>
  .general-tab {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-6);
    padding: var(--spacing-4);
    max-width: 800px;
  }

  .loading,
  .error {
    padding: var(--spacing-4);
    border-radius: var(--radius-md);
    text-align: center;
  }

  .loading {
    background-color: var(--color-control-background);
    color: var(--color-text-secondary);
  }

  .error {
    background-color: rgba(255, 59, 48, 0.1);
    color: rgb(255, 59, 48);
  }

  .settings-section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-3);
  }

  .section-header {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-1);
  }

  .section-header h2 {
    font-size: var(--font-size-lg);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
    margin: 0;
  }

  .section-header p {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    margin: 0;
  }

  .settings-group {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-4);
    padding: var(--spacing-4);
  }

  .setting-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: var(--spacing-4);
  }

  .setting-label {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-1);
    flex: 1;
  }

  .setting-label label {
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
    display: block;
  }

  .setting-control {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
  }

  .help-text {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    display: block;
  }

  select {
    padding: var(--spacing-2) var(--spacing-3);
    border: 1px solid var(--color-control-border);
    border-radius: var(--radius-md);
    background-color: var(--color-control-background);
    color: var(--color-text-primary);
    font-size: var(--font-size-base);
    font-family: var(--font-family-system);
    cursor: pointer;
    transition: border-color 0.2s ease;
  }

  select:hover {
    border-color: var(--color-separator);
  }

  select:focus {
    outline: none;
    border-color: var(--color-accent);
    box-shadow: 0 0 0 2px rgba(0, 102, 255, 0.1);
  }

  .status-badge {
    font-size: var(--font-size-sm);
    padding: var(--spacing-1) var(--spacing-2);
    border-radius: var(--radius-md);
    background-color: var(--color-control-background);
    color: var(--color-text-secondary);
    display: inline-block;
  }

  /* MCP Server Styles */
  .mcp-status {
    display: flex;
    align-items: center;
    gap: var(--spacing-3);
    padding: var(--spacing-3);
    background-color: var(--color-background-secondary);
    border-radius: var(--radius-md);
  }

  .status-indicator {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background-color: var(--color-text-tertiary);
    flex-shrink: 0;
  }

  .status-indicator.running {
    background-color: rgb(34, 197, 94);
  }

  .status-info {
    flex: 1;
  }

  .status-text {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
  }

  .status-label {
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
  }

  .port-info {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
  }

  .mcp-token-section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
    padding: var(--spacing-3);
    background-color: var(--color-background-secondary);
    border-radius: var(--radius-md);
    margin-top: var(--spacing-2);
  }

  .token-label {
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-secondary);
  }

  .token-display {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    padding: var(--spacing-2) var(--spacing-3);
    background-color: var(--color-control-background);
    border-radius: var(--radius-md);
    border: 1px solid var(--color-control-border);
  }

  .token-display code {
    flex: 1;
    font-family: 'Courier New', monospace;
    font-size: 11px;
    color: var(--color-text-primary);
    word-break: break-all;
  }

  .mcp-help-text {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    margin: 0;
    margin-top: var(--spacing-2);
  }

  /* About Styles */
  .about-content {
    display: flex;
    align-items: center;
    gap: var(--spacing-4);
    padding: var(--spacing-4);
  }

  .about-icon {
    font-size: 48px;
    flex-shrink: 0;
  }

  .about-info {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-1);
  }

  .about-name {
    font-size: var(--font-size-lg);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
  }

  .about-desc {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
  }

  .about-version {
    font-size: 11px;
    font-family: 'Courier New', monospace;
    color: var(--color-text-tertiary);
  }
</style>
