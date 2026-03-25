<script lang="ts">
  import Button from '../../shared/components/Button.svelte';
  import Icon from '../../shared/components/Icon.svelte';

  interface UrlBubbleProps {
    url: string;
    isUnshortening?: boolean;
    onCopy?: () => void;
    onUnshorten?: () => void;
  }

  let {
    url,
    isUnshortening = false,
    onCopy,
    onUnshorten
  } = $props<UrlBubbleProps>();

  // Truncate URL: show first 30 + last 20 chars if > 60 chars
  function truncateUrl(fullUrl: string): string {
    if (fullUrl.length <= 60) return fullUrl;
    const first30 = fullUrl.slice(0, 30);
    const last20 = fullUrl.slice(-20);
    return `${first30}…${last20}`;
  }

  // Copy to clipboard
  async function handleCopy() {
    try {
      await navigator.clipboard.writeText(url);
      onCopy?.();
    } catch (error) {
      console.error('Failed to copy URL:', error);
    }
  }

  const displayUrl = truncateUrl(url);
</script>

<div class="url-bubble">
  <div class="url-content">
    <!-- Link icon -->
    <div class="icon-wrapper">
      <Icon size={16}>
        <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
        <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
      </Icon>
    </div>

    <!-- URL text -->
    <span class="url-text" title={url}>{displayUrl}</span>
  </div>

  <!-- Action buttons -->
  <div class="actions">
    {#if isUnshortening}
      <!-- Loading spinner -->
      <div class="spinner-wrapper">
        <div class="spinner"></div>
      </div>
    {:else}
      <!-- Unshorten button -->
      <Button
        variant="ghost"
        size="sm"
        onclick={onUnshorten}
        title="Unshorten URL (H)"
      >
        <Icon size={14}>
          <path d="M12 6H6m6 0l-1.5 1.5M6 6l1.5 1.5M12 18H6m6 0l-1.5-1.5M6 18l1.5-1.5" />
        </Icon>
        <span class="hint-text">(H)</span>
      </Button>
    {/if}

    <!-- Copy button -->
    <Button
      variant="ghost"
      size="sm"
      onclick={handleCopy}
      title="Copy URL"
    >
      <Icon size={14}>
        <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" />
        <rect x="8" y="2" width="8" height="4" rx="1" />
      </Icon>
    </Button>
  </div>
</div>

<style>
  .url-bubble {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--spacing-4);
    padding: var(--spacing-3);
    background-color: var(--color-background-secondary);
    border-radius: var(--radius-lg);
  }

  .url-content {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    flex: 1;
    min-width: 0;
  }

  .icon-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--color-text-secondary);
  }

  .url-text {
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .actions {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    flex-shrink: 0;
  }

  .spinner-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
  }

  .spinner {
    width: 14px;
    height: 14px;
    border: 2px solid var(--color-control-background);
    border-top-color: var(--color-accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .hint-text {
    font-size: var(--font-size-xs);
    color: var(--color-text-secondary);
    margin-left: var(--spacing-1);
  }
</style>
