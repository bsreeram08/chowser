<script lang="ts">
  import BrowserListItem from '../../shared/components/BrowserListItem.svelte';

  interface Browser {
    id: string;
    name: string;
    appId: string;
    shortcutKey: string;
    profile?: string;
  }

  interface ListLayoutProps {
    browsers: Browser[];
    selectedBrowserId: string | null;
    onSelect: (browser: Browser) => void;
  }

  let {
    browsers = [],
    selectedBrowserId = null,
    onSelect
  } = $props<ListLayoutProps>();

  let containerRef = $state<HTMLDivElement | null>(null);
  let selectedIndex = $derived(
    browsers.findIndex(b => b.id === selectedBrowserId)
  );

  // Handle keyboard navigation (up/down arrows)
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      const nextIndex = selectedIndex < browsers.length - 1 ? selectedIndex + 1 : 0;
      const nextBrowser = browsers[nextIndex];
      if (nextBrowser) {
        onSelect(nextBrowser);
        scrollIntoView(nextIndex);
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      const prevIndex = selectedIndex <= 0 ? browsers.length - 1 : selectedIndex - 1;
      const prevBrowser = browsers[prevIndex];
      if (prevBrowser) {
        onSelect(prevBrowser);
        scrollIntoView(prevIndex);
      }
    }
  }

  // Scroll selected item into view
  function scrollIntoView(index: number) {
    if (!containerRef) return;
    
    const listItems = containerRef.querySelectorAll('[data-list-item]');
    const listItem = listItems[index] as HTMLElement | undefined;
    
    if (listItem && containerRef) {
      listItem.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
  }

  // Setup keyboard listener on mount
  $effect(() => {
    window.addEventListener('keydown', handleKeydown);
    return () => {
      window.removeEventListener('keydown', handleKeydown);
    };
  });

  // Handle click on list item
  function handleItemClick(browser: Browser) {
    onSelect(browser);
  }
</script>

<div class="list-layout-wrapper">
  <div class="list-container" bind:this={containerRef}>
    {#each browsers as browser, index (browser.id)}
      <div class="list-item" data-list-item>
        <BrowserListItem
          browserName={browser.name}
          profileName={browser.profile}
          shortcutKey={browser.shortcutKey}
          bundleId={browser.appId}
          isSelected={browser.id === selectedBrowserId}
          onclick={() => handleItemClick(browser)}
        />
      </div>
    {/each}
  </div>
</div>

<style>
  @import '../../shared/tokens.css';

  .list-layout-wrapper {
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: stretch;
  }

  .list-container {
    display: flex;
    flex-direction: column;
    width: 100%;
    max-height: 400px;
    overflow-y: auto;
    overflow-x: hidden;
    
    /* Scrollbar styling */
    scrollbar-width: thin;
    scrollbar-color: var(--color-control-border) transparent;
  }

  .list-container::-webkit-scrollbar {
    width: 6px;
  }

  .list-container::-webkit-scrollbar-track {
    background: transparent;
  }

  .list-container::-webkit-scrollbar-thumb {
    background: var(--color-control-border);
    border-radius: 3px;
  }

  .list-item {
    display: flex;
    width: 100%;
    min-height: 44px;
  }
</style>
