<script lang="ts">
  interface FocusBannerProps {
    browserName: string;
    countdown: string | null;
  }

  let { browserName, countdown } = $props<FocusBannerProps>();
</script>

<div class="focus-banner">
  <div class="focus-icon">🎯</div>
  <div class="focus-content">
    <div class="focus-label">Focus Mode</div>
    <div class="focus-browser">{browserName}</div>
  </div>
  {#if countdown}
    <div class="focus-countdown">{countdown}</div>
  {/if}
</div>

<style>
  .focus-banner {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    padding: var(--spacing-3);
    background: linear-gradient(135deg, rgba(59, 130, 246, 0.1), rgba(99, 102, 241, 0.1));
    border-radius: var(--radius-md);
    border: 1px solid rgba(59, 130, 246, 0.2);
  }

  .focus-icon {
    font-size: 1.25rem;
    flex-shrink: 0;
  }

  .focus-content {
    flex: 1;
    min-width: 0;
  }

  .focus-label {
    font-size: 0.75rem;
    color: var(--color-text-secondary);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .focus-browser {
    font-size: 0.9rem;
    font-weight: 500;
    color: var(--color-text-primary);
    margin-top: 2px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .focus-countdown {
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--color-text-secondary);
    padding: var(--spacing-2) var(--spacing-2);
    background: rgba(59, 130, 246, 0.15);
    border-radius: var(--radius-sm);
    white-space: nowrap;
    flex-shrink: 0;
  }
</style>
