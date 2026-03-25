<script lang="ts">
  interface InputProps {
    label?: string;
    placeholder?: string;
    value?: string;
    error?: boolean;
    errorMessage?: string;
    disabled?: boolean;
    type?: string;
    onchange?: (value: string) => void;
    oninput?: (value: string) => void;
  }

  let {
    label,
    placeholder = '',
    value = '',
    error = false,
    errorMessage = '',
    disabled = false,
    type = 'text',
    onchange,
    oninput
  } = $props<InputProps>();
</script>

<div class="input-wrapper">
  {#if label}
    <label class="input-label">{label}</label>
  {/if}
  <input
    {type}
    {placeholder}
    {value}
    {disabled}
    class="input"
    class:input--error={error}
    on:change={(e) => {
      value = e.currentTarget.value;
      onchange?.(value);
    }}
    on:input={(e) => {
      value = e.currentTarget.value;
      oninput?.(value);
    }}
  />
  {#if error && errorMessage}
    <div class="input-error">{errorMessage}</div>
  {/if}
</div>

<style>
  .input-wrapper {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .input-label {
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
  }

  .input {
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    padding: var(--spacing-3) var(--spacing-3);
    height: 40px;
    border: 1px solid var(--color-control-border);
    border-radius: var(--radius-md);
    background-color: var(--color-control-background);
    color: var(--color-text-primary);
    transition: border-color 0.2s ease;
  }

  .input::placeholder {
    color: var(--color-text-tertiary);
  }

  .input:focus {
    outline: none;
    border-color: var(--color-accent);
    box-shadow: 0 0 0 2px rgba(0, 102, 255, 0.1);
  }

  .input:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .input--error {
    border-color: var(--color-error);
  }

  .input--error:focus {
    border-color: var(--color-error);
    box-shadow: 0 0 0 2px rgba(255, 59, 48, 0.1);
  }

  .input-error {
    font-size: var(--font-size-xs);
    color: var(--color-error);
    margin-top: var(--spacing-1);
  }
</style>
