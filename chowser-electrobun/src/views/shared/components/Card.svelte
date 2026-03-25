<script lang="ts">
  interface CardProps {
    padding?: string;
  }

  let { padding = 'var(--spacing-4)' } = $props<CardProps>();
</script>

<div class="card" style:padding>
  <slot />
</div>

<style>
  .card {
    background: var(--color-glass-light);
    backdrop-filter: blur(20px);
    border: 1px solid var(--color-glass-border-light);
    border-radius: var(--radius-xl);
    box-shadow: var(--shadow-sm);
  }
</style>
