<script lang="ts">
  interface SuggestionBannerProps {
    domain: string;
    browserName: string;
    onAccept: () => void;
    onDismiss: () => void;
  }

  let { domain, browserName, onAccept, onDismiss } = $props<SuggestionBannerProps>();
</script>

<div class="suggestion-banner">
  <div class="suggestion-icon">📊</div>
  <div class="suggestion-content">
    <div class="suggestion-text">
      Always open <strong>{domain}</strong> in <strong>{browserName}</strong>?
    </div>
  </div>
  <div class="suggestion-actions">
    <button class="btn-accept" onclick={onAccept}>Create Rule</button>
    <button class="btn-dismiss" onclick={onDismiss}>Not now</button>
  </div>
</div>

<style>
  .suggestion-banner {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    padding: var(--spacing-2) var(--spacing-3);
    background: var(--color-glass-light);
    border: 1px solid var(--color-glass-border-light);
    border-radius: var(--radius-md);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
  }

  .suggestion-icon {
    font-size: 1rem;
    flex-shrink: 0;
  }

  .suggestion-content {
    flex: 1;
    min-width: 0;
  }

  .suggestion-text {
    font-size: var(--font-size-xs);
    color: var(--color-text-secondary);
    line-height: var(--line-height-tight);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .suggestion-text strong {
    color: var(--color-text-primary);
    font-weight: var(--font-weight-semibold);
  }

  .suggestion-actions {
    display: flex;
    gap: var(--spacing-1);
    flex-shrink: 0;
  }

  .btn-accept {
    font-family: var(--font-family-system);
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-medium);
    padding: var(--spacing-1) var(--spacing-2);
    border: none;
    border-radius: var(--radius-sm);
    background: var(--color-accent);
    color: #fff;
    cursor: pointer;
    transition: background 0.15s ease;
    white-space: nowrap;
  }

  .btn-accept:hover {
    background: var(--color-accent-hover);
  }

  .btn-accept:active {
    background: var(--color-accent-pressed);
  }

  .btn-dismiss {
    font-family: var(--font-family-system);
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-medium);
    padding: var(--spacing-1) var(--spacing-2);
    border: 1px solid var(--color-control-border);
    border-radius: var(--radius-sm);
    background: var(--color-control-background);
    color: var(--color-text-secondary);
    cursor: pointer;
    transition: background 0.15s ease, border-color 0.15s ease;
    white-space: nowrap;
  }

  .btn-dismiss:hover {
    border-color: var(--color-accent);
    color: var(--color-text-primary);
  }
</style>
