<script lang="ts">
  import Card from '../../shared/components/Card.svelte';

  interface PickerShellProps {
    width?: number;
  }

  let { width = 400 } = $props<PickerShellProps>();
</script>

<Card padding="var(--spacing-4)">
  <div class="picker-shell" style:width="{width}px">
    {#if $$slots.url}
      <div class="picker-section url-section">
        <slot name="url" />
      </div>
      <div class="divider"></div>
    {/if}

    <div class="picker-section content-section">
      <slot />
    </div>

    {#if $$slots.actions}
      <div class="divider"></div>
      <div class="picker-section action-section">
        <slot name="actions" />
      </div>
    {/if}
  </div>
</Card>

<style>
  .picker-shell {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    width: 400px;
  }

  .picker-section {
    padding: var(--spacing-3) 0;
  }

  .url-section {
    padding-top: var(--spacing-3);
    padding-bottom: var(--spacing-3);
  }

  .content-section {
    min-height: 60px;
    flex: 1;
  }

  .action-section {
    padding-top: var(--spacing-3);
    padding-bottom: 0;
  }

  .divider {
    height: 1px;
    background-color: var(--color-separator);
    opacity: 0.5;
    margin: 0;
  }
</style>
