<script lang="ts">
  import BrowserIcon from '../../shared/components/BrowserIcon.svelte';
  import Input from '../../shared/components/Input.svelte';
  import Button from '../../shared/components/Button.svelte';

  interface BrowserConfigRowProps {
    browser: {
      id: string;
      name: string;
      appId: string;
      shortcutKey: string;
      profile?: string;
      customArguments?: string;
    };
    onUpdate: (updates: Partial<typeof browser>) => void;
    onDelete: () => void;
  }

  let {
    browser,
    onUpdate,
    onDelete
  } = $props<BrowserConfigRowProps>();

  // Local state for editable fields
  let shortcutInput = $state(browser.shortcutKey || '');
  let showCustomArgs = $state(false);
  let customArgsInput = $state(browser.customArguments || '');

  // Update shortcut key (1-9 only, 1 char max)
  function handleShortcutChange(value: string) {
    const sanitized = value.replace(/[^1-9]/g, '').slice(0, 1);
    shortcutInput = sanitized;
    if (sanitized && sanitized !== browser.shortcutKey) {
      onUpdate({ shortcutKey: sanitized });
    }
  }

  // Update custom args on blur (debounced via local state)
  function handleCustomArgsBlur() {
    if (customArgsInput !== (browser.customArguments || '')) {
      onUpdate({ customArguments: customArgsInput });
    }
  }

  // Toggle custom args visibility
  function toggleCustomArgs() {
    showCustomArgs = !showCustomArgs;
  }
</script>

<div class="browser-row">
  <!-- Drag handle -->
  <div class="drag-handle" aria-label="Drag to reorder">⋮⋮</div>

  <!-- Browser icon (32px) -->
  <div class="icon-container">
    <BrowserIcon bundleId={browser.appId} size="medium" shortcutKey={browser.shortcutKey} />
  </div>

  <!-- Name + Profile (flex-1) -->
  <div class="info-section">
    <div class="browser-name">{browser.name}</div>
    {#if browser.profile}
      <div class="profile-name">{browser.profile}</div>
    {/if}
    {#if browser.appId}
      <div class="bundle-id">{browser.appId}</div>
    {/if}
  </div>

  <!-- Shortcut key input (60px) -->
  <div class="shortcut-input">
    <Input
      placeholder="1-9"
      value={shortcutInput}
      onchange={handleShortcutChange}
      oninput={handleShortcutChange}
    />
  </div>

  <!-- Delete button (ghost variant) -->
  <div class="actions">
    <Button variant="ghost" size="sm" onclick={onDelete}>
      🗑️
    </Button>
  </div>
</div>

<!-- Custom args section (expandable) -->
{#if browser.customArguments || showCustomArgs}
  <div class="custom-args-section">
    <button class="toggle-button" onclick={toggleCustomArgs}>
      {showCustomArgs ? '▼' : '▶'} Custom Arguments
    </button>
    {#if showCustomArgs}
      <div class="custom-args-input">
        <textarea
          placeholder="e.g., --new-window --disable-sync"
          value={customArgsInput}
          onblur={handleCustomArgsBlur}
        />
      </div>
    {/if}
  </div>
{/if}

<style>
  .browser-row {
    display: grid;
    grid-template-columns: 24px 32px 1fr 60px auto;
    gap: var(--spacing-3);
    align-items: center;
    height: 60px;
    padding: var(--spacing-3);
    border-bottom: 1px solid var(--color-separator);
    background-color: var(--color-control-background);
    border-radius: var(--radius-md);
    transition: background-color 0.15s ease;
  }

  .browser-row:hover {
    background-color: var(--color-background-secondary);
  }

  /* Drag handle */
  .drag-handle {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--color-text-tertiary);
    font-size: 12px;
    pointer-events: none;
    user-select: none;
  }

  /* Icon container */
  .icon-container {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  /* Info section (name + profile + bundle ID) */
  .info-section {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .browser-name {
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
    line-height: 1.2;
  }

  .profile-name {
    font-size: var(--font-size-xs);
    color: var(--color-text-secondary);
    line-height: 1.2;
  }

  .bundle-id {
    font-size: 10px;
    font-family: 'Courier New', monospace;
    color: var(--color-text-tertiary);
    line-height: 1.2;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* Shortcut key input */
  .shortcut-input {
    width: 60px;
  }

  /* Actions section */
  .actions {
    display: flex;
    gap: var(--spacing-2);
    flex-shrink: 0;
  }

  /* Custom args section (expandable) */
  .custom-args-section {
    padding: var(--spacing-2) var(--spacing-3);
    margin-top: var(--spacing-2);
    background-color: var(--color-background-secondary);
    border-radius: var(--radius-md);
    grid-column: 1 / -1;
  }

  .toggle-button {
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    color: var(--color-text-secondary);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    transition: color 0.15s ease;
  }

  .toggle-button:hover {
    color: var(--color-text-primary);
  }

  /* Custom args input */
  .custom-args-input {
    margin-top: var(--spacing-2);
  }

  textarea {
    width: 100%;
    min-height: 60px;
    padding: var(--spacing-3);
    font-family: 'Courier New', monospace;
    font-size: var(--font-size-sm);
    border: 1px solid var(--color-control-border);
    border-radius: var(--radius-md);
    background-color: var(--color-control-background);
    color: var(--color-text-primary);
    resize: vertical;
    transition: border-color 0.2s ease;
  }

  textarea::placeholder {
    color: var(--color-text-tertiary);
  }

  textarea:focus {
    outline: none;
    border-color: var(--color-accent);
    box-shadow: 0 0 0 2px rgba(0, 102, 255, 0.1);
  }
</style>
