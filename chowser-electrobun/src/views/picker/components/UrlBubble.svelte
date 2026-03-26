<script lang="ts">
  import Button from '../../shared/components/Button.svelte';
  import Icon from '../../shared/components/Icon.svelte';

  interface UrlBubbleProps {
    url: string;
    isUnshortening?: boolean;
    unshortenError?: string | null;
    onCopy?: () => void;
    onUnshorten?: () => void;
  }

  let {
    url,
    isUnshortening = false,
    unshortenError = null,
    onCopy,
    onUnshorten
  } = $props<UrlBubbleProps>();

  // Clean URL by removing tracking params
  function cleanTrackingParams(fullUrl: string): string {
    try {
      const u = new URL(fullUrl);
      const trackingParams = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content', 'fbclid', 'gclid'];
      let removed = false;
      for (const param of trackingParams) {
        if (u.searchParams.has(param)) {
          u.searchParams.delete(param);
          removed = true;
        }
      }
      if (!removed) return fullUrl;
      const result = u.toString();
      return result.endsWith('?') ? result.slice(0, -1) : result;
    } catch {
      return fullUrl;
    }
  }

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

  // Display cleaned URL (tracking params removed)
  const cleanedUrl = $derived(cleanTrackingParams(url));
  const displayUrl = $derived(truncateUrl(cleanedUrl));
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

    <!-- URL text or error state -->
    {#if unshortenError}
      <div class="url-error">
        <span class="error-label">Error:</span>
        <span class="error-text" title={unshortenError}>{unshortenError}</span>
      </div>
    {:else}
      <span class="url-text" title={cleanedUrl}>{displayUrl}</span>
    {/if}
  </div>

  <!-- Action buttons -->
  <div class="actions">
    {#if isUnshortening}
      <!-- Loading spinner -->
      <div class="spinner-wrapper">
        <div class="spinner"></div>
        <span class="loading-text">Resolving...</span>
      </div>
    {:else if unshortenError}
      <!-- Error state: show retry button -->
      <Button
        variant="ghost"
        size="sm"
        onclick={onUnshorten}
        title="Retry unshorten (H)"
      >
        <Icon size={14}>
          <path d="M1 4v6h6m22-6v6h-6m-2-2l1.5-1.5M4 7l-1.5 1.5" />
        </Icon>
      </Button>
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

  .url-error {
    display: flex;
    align-items: center;
    gap: var(--spacing-1);
    font-size: var(--font-size-sm);
    color: var(--color-error);
    overflow: hidden;
  }

  .error-label {
    font-weight: var(--font-weight-medium);
    flex-shrink: 0;
  }

  .error-text {
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
    gap: var(--spacing-2);
  }

  .spinner {
    width: 14px;
    height: 14px;
    border: 2px solid var(--color-control-background);
    border-top-color: var(--color-accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  .loading-text {
    font-size: var(--font-size-xs);
    color: var(--color-text-secondary);
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
