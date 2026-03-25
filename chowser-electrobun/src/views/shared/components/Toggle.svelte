<script lang="ts">
  interface ToggleProps {
    checked?: boolean;
    disabled?: boolean;
    onchange?: (checked: boolean) => void;
  }

  let { checked = false, disabled = false, onchange } = $props<ToggleProps>();
</script>

<button
  role="switch"
  aria-checked={checked}
  {disabled}
  class="toggle"
  class:toggle--checked={checked}
  on:click={() => {
    checked = !checked;
    onchange?.(checked);
  }}
>
  <span class="toggle-track" />
  <span class="toggle-thumb" />
</button>

<style>
  .toggle {
    position: relative;
    width: 44px;
    height: 24px;
    padding: 0;
    border: none;
    background: transparent;
    cursor: pointer;
    border-radius: var(--radius-full);
    transition: none;
    display: inline-flex;
    align-items: center;
    justify-content: flex-start;
  }

  .toggle:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .toggle-track {
    position: absolute;
    width: 100%;
    height: 100%;
    background-color: var(--color-control-background);
    border-radius: var(--radius-full);
    transition: background-color 0.3s ease;
  }

  .toggle--checked .toggle-track {
    background-color: var(--color-accent);
  }

  .toggle-thumb {
    position: relative;
    width: 20px;
    height: 20px;
    background-color: white;
    border-radius: var(--radius-full);
    transition: transform 0.3s ease;
    box-shadow: var(--shadow-sm);
    z-index: 1;
    margin-left: var(--spacing-1);
  }

  .toggle--checked .toggle-thumb {
    transform: translateX(20px);
  }
</style>
