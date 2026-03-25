<script lang="ts">
  interface BrowserIconProps {
    bundleId: string;
    size?: 'small' | 'medium' | 'large';
    shortcutKey?: string;
    isSelected?: boolean;
  }

  let { bundleId, size = 'medium', shortcutKey, isSelected = false } = $props<BrowserIconProps>();

  // Size mapping (in pixels)
  const sizeMap = {
    small: 24,
    medium: 32,
    large: 48
  };

  const iconSize = sizeMap[size];

  // Placeholder browser icon — TODO: fetch real icons from bundleId
  const getBrowserInitial = (id: string) => {
    const parts = id.split('.');
    const lastPart = parts[parts.length - 1];
    return lastPart.charAt(0).toUpperCase();
  };

  const initial = getBrowserInitial(bundleId);
</script>

<div class="browser-icon-wrapper" class:selected={isSelected} data-size={size}>
  <div class="icon-container">
    {/* Placeholder icon — gradient background with initial */}
    <div class="icon-placeholder">
      {initial}
    </div>

    {/* Shortcut badge (if provided) */}
    {#if shortcutKey}
      <div class="shortcut-badge">
        {shortcutKey}
      </div>
    {/if}
  </div>
</div>

<style>
  .browser-icon-wrapper {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
  }

  /* Size variants */
  .browser-icon-wrapper[data-size='small'] .icon-container {
    width: 24px;
    height: 24px;
  }

  .browser-icon-wrapper[data-size='medium'] .icon-container {
    width: 32px;
    height: 32px;
  }

  .browser-icon-wrapper[data-size='large'] .icon-container {
    width: 48px;
    height: 48px;
  }

  /* Selected state: accent ring */
  .browser-icon-wrapper.selected .icon-container {
    border: 2px solid var(--color-accent);
    border-radius: 4px;
  }

  /* Hover effect */
  .browser-icon-wrapper:hover {
    opacity: 0.8;
  }

  .icon-container {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    background: var(--color-control-background);
    transition: all 0.2s ease;
    flex-shrink: 0;
  }

  /* Placeholder icon styling */
  .icon-placeholder {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    font-weight: var(--font-weight-bold);
    color: var(--color-text-primary);
    background: linear-gradient(135deg, var(--color-accent) 0%, var(--color-accent-pressed) 100%);
    color: white;
    border-radius: 4px;
    font-size: 0.6em;
    user-select: none;
  }

  /* Shortcut badge: 16px circle, top-right corner */
  .shortcut-badge {
    position: absolute;
    bottom: -4px;
    right: -4px;
    width: 16px;
    height: 16px;
    border-radius: var(--radius-full);
    background-color: var(--color-accent);
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    font-weight: var(--font-weight-bold);
    box-shadow: 0 1px 3px var(--color-shadow-light);
    user-select: none;
  }
</style>
