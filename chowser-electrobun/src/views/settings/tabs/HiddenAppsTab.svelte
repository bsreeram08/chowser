<script lang="ts">
  import Input from '../../shared/components/Input.svelte';
  import Button from '../../shared/components/Button.svelte';

  interface HiddenAppsTabProps {
    rpcCall: (method: string, params?: unknown[]) => Promise<unknown>;
  }

  let { rpcCall }: HiddenAppsTabProps = $props();

  let hiddenApps = $state<string[]>([]);
  let newBundleId = $state('');
  let error = $state('');
  let isLoading = $state(true);
  let showClearConfirmation = $state(false);

  // Lifecycle: Load hidden apps on mount
  $effect.pre(async () => {
    await loadHiddenApps();
  });

  // Load hidden apps from RPC
  async function loadHiddenApps() {
    try {
      isLoading = true;
      error = '';
      const result = await rpcCall('getHiddenApps');
      hiddenApps = Array.isArray(result) ? (result as string[]).sort() : [];
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load hidden apps';
      hiddenApps = [];
    } finally {
      isLoading = false;
    }
  }

  // Validate bundle ID format (reverse domain notation)
  function isValidBundleId(bundleId: string): boolean {
    const trimmed = bundleId.trim();
    // Basic validation: must contain at least one dot and alphanumeric/dots only
    return /^[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)+$/.test(trimmed);
  }

  // Add a hidden app
  async function addHiddenApp() {
    const trimmed = newBundleId.trim();

    if (!trimmed) {
      error = 'Bundle ID cannot be empty';
      return;
    }

    if (!isValidBundleId(trimmed)) {
      error = 'Invalid bundle ID format. Use reverse domain notation (e.g., com.example.app)';
      return;
    }

    if (hiddenApps.includes(trimmed)) {
      error = 'This app is already hidden';
      return;
    }

    try {
      error = '';
      await rpcCall('addHiddenApp', [trimmed]);
      newBundleId = '';
      await loadHiddenApps();
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to add hidden app';
    }
  }

  // Remove a hidden app
  async function removeHiddenApp(bundleId: string) {
    try {
      error = '';
      await rpcCall('removeHiddenApp', [bundleId]);
      await loadHiddenApps();
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to remove hidden app';
    }
  }

  // Clear all hidden apps
  async function clearAllHiddenApps() {
    try {
      error = '';
      await rpcCall('clearAllHiddenApps');
      showClearConfirmation = false;
      newBundleId = '';
      await loadHiddenApps();
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to clear hidden apps';
    }
  }

  // Handle Enter key in input
  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      addHiddenApp();
    }
  }
</script>

<div class="hidden-apps-tab">
  <div class="section-header">
    <h2>Hidden Apps</h2>
    <p>Prevent apps from appearing in the browser list by hiding their bundle IDs.</p>
  </div>

  {#if error}
    <div class="error-message">{error}</div>
  {/if}

  {#if isLoading}
    <div class="loading">Loading hidden apps...</div>
  {:else}
    <!-- List of hidden apps -->
    <div class="hidden-apps-list">
      {#if hiddenApps.length === 0}
        <div class="empty-state">
          <p>No hidden apps yet.</p>
          <p>Add a bundle ID below to hide an app.</p>
        </div>
      {:else}
        <div class="list-container">
          {#each hiddenApps as bundleId (bundleId)}
            <div class="hidden-app-item">
              <div class="bundle-id-display">{bundleId}</div>
              <Button variant="ghost" size="sm" onclick={() => removeHiddenApp(bundleId)}>
                👁️ Show
              </Button>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Add new hidden app -->
    <div class="add-section">
      <h3>Hide an App</h3>
      <div class="input-row">
        <Input
          placeholder="com.example.app"
          value={newBundleId}
          onchange={(val) => {
            newBundleId = val;
            error = '';
          }}
          oninput={(val) => (newBundleId = val)}
          on:keydown={handleKeyDown}
        />
        <Button onclick={addHiddenApp} disabled={!newBundleId.trim()}>
          Hide App
        </Button>
      </div>
      <p class="helper-text">
        Enter the bundle ID in reverse domain notation format (e.g., com.example.app).
      </p>
    </div>

    <!-- Clear all section -->
    {#if hiddenApps.length > 0}
      <div class="clear-section">
        {#if showClearConfirmation}
          <div class="confirmation-dialog">
            <p>Are you sure you want to unhide all apps?</p>
            <div class="confirmation-buttons">
              <Button variant="secondary" size="sm" onclick={() => (showClearConfirmation = false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onclick={clearAllHiddenApps}>
                Yes, Unhide All
              </Button>
            </div>
          </div>
        {:else}
          <Button variant="secondary" size="sm" onclick={() => (showClearConfirmation = true)}>
            Unhide All Apps
          </Button>
        {/if}
      </div>
    {/if}
  {/if}
</div>

<style>
  .hidden-apps-tab {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-6);
    max-width: 600px;
  }

  /* Section header */
  .section-header {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .section-header h2 {
    font-size: var(--font-size-xl);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
    margin: 0;
  }

  .section-header p {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    margin: 0;
  }

  /* Error message */
  .error-message {
    padding: var(--spacing-3);
    background-color: rgba(255, 59, 48, 0.1);
    border: 1px solid rgba(255, 59, 48, 0.3);
    border-radius: var(--radius-md);
    color: #ff3b30;
    font-size: var(--font-size-sm);
  }

  /* Loading state */
  .loading {
    text-align: center;
    color: var(--color-text-secondary);
    font-size: var(--font-size-sm);
    padding: var(--spacing-4);
  }

  /* Hidden apps list */
  .hidden-apps-list {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  /* Empty state */
  .empty-state {
    text-align: center;
    padding: var(--spacing-6);
    background-color: var(--color-background-secondary);
    border-radius: var(--radius-md);
    border: 1px dashed var(--color-separator);
  }

  .empty-state p {
    margin: 0;
    color: var(--color-text-secondary);
    font-size: var(--font-size-sm);
  }

  .empty-state p:first-child {
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
    margin-bottom: var(--spacing-2);
  }

  /* List container */
  .list-container {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
    border: 1px solid var(--color-separator);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  /* Hidden app item */
  .hidden-app-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--spacing-3);
    background-color: var(--color-control-background);
    border-bottom: 1px solid var(--color-separator);
    transition: background-color 0.15s ease;
  }

  .hidden-app-item:last-child {
    border-bottom: none;
  }

  .hidden-app-item:hover {
    background-color: var(--color-background-secondary);
  }

  .bundle-id-display {
    font-family: 'Courier New', monospace;
    font-size: var(--font-size-sm);
    color: var(--color-text-primary);
    flex: 1;
    min-width: 0;
    word-break: break-all;
  }

  /* Add section */
  .add-section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-3);
    padding: var(--spacing-4);
    background-color: var(--color-background-secondary);
    border: 1px solid var(--color-separator);
    border-radius: var(--radius-md);
  }

  .add-section h3 {
    margin: 0;
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
  }

  /* Input row */
  .input-row {
    display: flex;
    gap: var(--spacing-2);
    align-items: flex-start;
  }

  .input-row :global(div) {
    flex: 1;
  }

  .input-row :global(.button) {
    flex-shrink: 0;
    height: 40px;
  }

  /* Helper text */
  .helper-text {
    margin: 0;
    font-size: var(--font-size-xs);
    color: var(--color-text-tertiary);
  }

  /* Clear section */
  .clear-section {
    display: flex;
    justify-content: center;
    padding: var(--spacing-4);
    background-color: rgba(255, 59, 48, 0.05);
    border: 1px solid rgba(255, 59, 48, 0.2);
    border-radius: var(--radius-md);
  }

  /* Confirmation dialog */
  .confirmation-dialog {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-3);
    align-items: center;
  }

  .confirmation-dialog p {
    margin: 0;
    color: var(--color-text-primary);
    font-size: var(--font-size-sm);
  }

  .confirmation-buttons {
    display: flex;
    gap: var(--spacing-2);
  }
</style>
