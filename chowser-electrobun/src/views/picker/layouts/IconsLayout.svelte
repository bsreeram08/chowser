<script lang="ts">
  import BrowserIcon from '../../shared/components/BrowserIcon.svelte';
  import '@import "../../shared/tokens.css";

  interface Browser {
    id: string;
    name: string;
    appId: string;
    shortcutKey: string;
    profile?: string;
  }

  interface IconsLayoutProps {
    browsers: Browser[];
    selectedBrowserId: string | null;
    size?: 'small' | 'medium' | 'large';
    showLabels?: boolean;
    onSelect: (browser: Browser) => void;
  }

  let {
    browsers = [],
    selectedBrowserId = null,
    size = 'medium',
    showLabels = false,
    onSelect
  } = $props<IconsLayoutProps>();

  let containerRef = $state<HTMLDivElement | null>(null);
  let selectedIndex = $derived(
    browsers.findIndex(b => b.id === selectedBrowserId)
  );

  // Handle keyboard navigation (left/right arrows)
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'ArrowRight') {
      e.preventDefault();
      const nextIndex = (selectedIndex + 1) % browsers.length;
      const nextBrowser = browsers[nextIndex];
      if (nextBrowser) {
        onSelect(nextBrowser);
        scrollIntoView(nextIndex);
      }
    } else if (e.key === 'ArrowLeft') {
      e.preventDefault();
      const prevIndex = selectedIndex <= 0 ? browsers.length - 1 : selectedIndex - 1;
      const prevBrowser = browsers[prevIndex];
      if (prevBrowser) {
        onSelect(prevBrowser);
        scrollIntoView(prevIndex);
      }
    }
  }

  // Scroll selected browser into view
  function scrollIntoView(index: number) {
    if (!containerRef) return;
    
    const iconElements = containerRef.querySelectorAll('[data-icon-item]');
    const iconElement = iconElements[index] as HTMLElement | undefined;
    
    if (iconElement && containerRef) {
      iconElement.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
    }
  }

  // Setup keyboard listener on mount
  $effect(() => {
    window.addEventListener('keydown', handleKeydown);
    return () => {
      window.removeEventListener('keydown', handleKeydown);
    };
  });

  // Handle click on icon
  function handleIconClick(browser: Browser) {
    onSelect(browser);
  }
</script>

<div class="icons-layout-wrapper">
  <div class="icons-container" bind:this={containerRef}>
    {#each browsers as browser, index (browser.id)}
      <div class="icon-item" data-icon-item>
        <button
          class="icon-button"
          class:selected={browser.id === selectedBrowserId}
          on:click={() => handleIconClick(browser)}
          title={browser.name}
          aria-label={browser.name}
          aria-pressed={browser.id === selectedBrowserId}
        >
          <BrowserIcon
            bundleId={browser.appId}
            {size}
            shortcutKey={browser.shortcutKey}
            isSelected={browser.id === selectedBrowserId}
          />
        </button>
        {#if showLabels}
          <div class="icon-label">{browser.name}</div>
        {/if}
      </div>
    {/each}
  </div>
</div>

<style>
  @import '../../shared/tokens.css';

  .icons-layout-wrapper {
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }

  .icons-container {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: flex-start;
    gap: var(--spacing-3);
    overflow-x: auto;
    overflow-y: hidden;
    width: 100%;
    padding: var(--spacing-3) 0;
    scroll-behavior: smooth;

    /* Scrollbar styling */
    scrollbar-width: thin;
    scrollbar-color: var(--color-control-border) transparent;
  }

  .icons-container::-webkit-scrollbar {
    height: 6px;
  }

  .icons-container::-webkit-scrollbar-track {
    background: transparent;
  }

  .icons-container::-webkit-scrollbar-thumb {
    background: var(--color-control-border);
    border-radius: 3px;
  }

  .icon-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-2);
    flex-shrink: 0;
  }

  .icon-button {
    display: flex;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    transition: all 0.2s ease;
    border-radius: var(--radius-md);

    /* Focus ring */
    &:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: 2px;
    }

    /* Hover effect */
    &:hover {
      opacity: 0.8;
    }

    /* Active/pressed state */
    &.selected {
      opacity: 1;
    }
  }

  .icon-label {
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
    text-align: center;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
    max-width: 100%;
    
    /* Width based on icon size */
    width: 48px;  /* Accommodates longest icon size + padding */
  }
</style>
