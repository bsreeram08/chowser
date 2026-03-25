<script lang="ts">
  interface ButtonProps {
    variant?: 'primary' | 'secondary' | 'ghost';
    size?: 'sm' | 'md' | 'lg';
    disabled?: boolean;
    type?: 'button' | 'submit' | 'reset';
    onclick?: () => void;
  }

  let {
    variant = 'primary',
    size = 'md',
    disabled = false,
    type = 'button',
    onclick
  } = $props<ButtonProps>();
</script>

<button
  {type}
  {disabled}
  on:click={onclick}
  class="button button--{variant} button--{size}"
>
  <slot />
</button>

<style>
  .button {
    font-family: var(--font-family-system);
    font-weight: var(--font-weight-medium);
    border: none;
    cursor: pointer;
    border-radius: var(--radius-md);
    transition: all 0.2s ease;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
  }

  /* Sizes */
  .button--sm {
    font-size: var(--font-size-sm);
    padding: var(--spacing-2) var(--spacing-3);
    height: 32px;
  }

  .button--md {
    font-size: var(--font-size-base);
    padding: var(--spacing-3) var(--spacing-4);
    height: 40px;
  }

  .button--lg {
    font-size: var(--font-size-lg);
    padding: var(--spacing-4) var(--spacing-6);
    height: 48px;
  }

  /* Variants */
  .button--primary {
    background-color: var(--color-accent);
    color: white;
  }

  .button--primary:hover:not(:disabled) {
    background-color: var(--color-accent-hover);
  }

  .button--primary:active:not(:disabled) {
    background-color: var(--color-accent-pressed);
  }

  .button--secondary {
    background-color: var(--color-control-background);
    color: var(--color-text-primary);
    border: 1px solid var(--color-control-border);
  }

  .button--secondary:hover:not(:disabled) {
    background-color: var(--color-background-secondary);
    border-color: var(--color-separator);
  }

  .button--secondary:active:not(:disabled) {
    background-color: var(--color-background-tertiary);
  }

  .button--ghost {
    background-color: transparent;
    color: var(--color-accent);
  }

  .button--ghost:hover:not(:disabled) {
    background-color: var(--color-glass-light);
  }

  .button--ghost:active:not(:disabled) {
    background-color: var(--color-control-background);
  }

  /* Disabled state */
  .button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
