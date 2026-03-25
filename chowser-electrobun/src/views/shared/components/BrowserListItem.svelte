<script lang="ts">
  import BrowserIcon from './BrowserIcon.svelte';

  interface BrowserListItemProps {
    browserName: string;
    profileName?: string;
    shortcutKey?: string;
    bundleId: string;
    isSelected?: boolean;
    onclick?: () => void;
  }

  let {
    browserName,
    profileName,
    shortcutKey,
    bundleId,
    isSelected = false,
    onclick
  } = $props<BrowserListItemProps>();
</script>

<button
  class="browser-list-item"
  class:selected={isSelected}
  on:click={onclick}
  type="button"
  aria-pressed={isSelected}
>
  <!-- Icon (24px small size) on the left -->
  <div class="icon-wrapper">
    <BrowserIcon {bundleId} size="small" {shortcutKey} {isSelected} />
  </div>

  <!-- Name and profile in the middle (flex-1 to take remaining space) -->
  <div class="info-section">
    <div class="browser-name">{browserName}</div>
    {#if profileName}
      <div class="profile-name">{profileName}</div>
    {/if}
  </div>

  <!-- Shortcut key on the right -->
  {#if shortcutKey}
    <div class="shortcut-display">
      {shortcutKey}
    </div>
  {/if}
</button>

<style>
  .browser-list-item {
    display: flex;
    align-items: center;
    gap: var(--spacing-3);
    height: 44px;
    padding: var(--spacing-3) var(--spacing-3);
    border: none;
    background-color: transparent;
    cursor: pointer;
    border-radius: var(--radius-md);
    transition: background-color 0.15s ease;
    text-align: left;
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    color: var(--color-text-primary);
  }

  /* Hover state: light background */
  .browser-list-item:hover:not(.selected) {
    background-color: var(--color-control-background);
  }

  /* Selected state: accent background with white text */
  .browser-list-item.selected {
    background-color: var(--color-accent);
    color: white;
  }

  .icon-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .info-section {
    display: flex;
    flex-direction: column;
    gap: 2px;
    flex: 1;
    min-width: 0;
  }

  .browser-name {
    font-weight: var(--font-weight-semibold);
    line-height: var(--line-height-tight);
  }

  .profile-name {
    font-size: var(--font-size-xs);
    color: inherit;
    opacity: 0.8;
    line-height: var(--line-height-tight);
  }

  /* When selected, profile name maintains white text with slight opacity */
  .browser-list-item.selected .profile-name {
    color: white;
  }

  .shortcut-display {
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-bold);
    padding: 4px 8px;
    background-color: rgba(0, 0, 0, 0.1);
    border-radius: var(--radius-sm);
    flex-shrink: 0;
    line-height: 1;
    min-width: 28px;
    text-align: center;
    opacity: 0.6;
  }

  /* When selected, shortcut has higher contrast */
  .browser-list-item.selected .shortcut-display {
    background-color: rgba(255, 255, 255, 0.2);
    opacity: 1;
  }
</style>
