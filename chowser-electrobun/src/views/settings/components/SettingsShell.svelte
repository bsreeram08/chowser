<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    activeTab: string;
    onTabChange: (tab: string) => void;
    children: Snippet;
  }

  let { activeTab, onTabChange, children }: Props = $props();

  const tabs = ['Browsers', 'Rules', 'General', 'Hidden Apps'];
</script>

<div class="settings-shell">
  <aside class="sidebar">
    {#each tabs as tab}
      <button
        class="tab-item"
        class:active={activeTab === tab}
        onclick={() => onTabChange(tab)}
      >
        {tab}
      </button>
    {/each}
  </aside>

  <div class="content">
    {@render children()}
  </div>
</div>

<style>
  .settings-shell {
    display: grid;
    grid-template-columns: 200px 1fr;
    width: 100%;
    height: 100%;
    background-color: var(--color-background);
  }

  .sidebar {
    background-color: var(--color-surface);
    border-right: 1px solid var(--color-border);
    display: flex;
    flex-direction: column;
    padding: var(--spacing-2);
    gap: var(--spacing-1);
  }

  .tab-item {
    height: 40px;
    padding: var(--spacing-3);
    border: none;
    border-radius: var(--radius-default);
    background-color: transparent;
    color: var(--color-text);
    font-size: 0.875rem;
    font-weight: 500;
    text-align: left;
    cursor: pointer;
    transition: all 150ms ease;
    white-space: nowrap;
  }

  .tab-item:hover:not(.active) {
    background-color: var(--color-control-background);
  }

  .tab-item.active {
    background-color: var(--color-accent);
    color: white;
  }

  .content {
    padding: var(--spacing-4);
    overflow-y: auto;
  }
</style>
