<script>
  /**
   * Toast notification component
   * Displays success/error/info messages with auto-dismiss
   */

  export let message = '';
  export let type = 'success'; // 'success' | 'error' | 'info'
  export let duration = 3000; // ms, 0 = no auto-dismiss
  export let isVisible = false;

  let timeoutId;

  function show() {
    isVisible = true;
    if (duration > 0) {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => {
        isVisible = false;
      }, duration);
    }
  }

  function hide() {
    isVisible = false;
    clearTimeout(timeoutId);
  }

  function getIcon() {
    if (type === 'success') return '✓';
    if (type === 'error') return '✕';
    return 'ℹ';
  }

  export function notify(msg, toastType = 'success', dur = 3000) {
    message = msg;
    type = toastType;
    duration = dur;
    show();
  }
</script>

{#if isVisible}
  <div class="toast toast-{type}" role="status" aria-live="polite">
    <span class="toast-icon">{getIcon()}</span>
    <span class="toast-message">{message}</span>
    <button class="toast-close" on:click={hide} aria-label="Close notification">
      ✕
    </button>
  </div>
{/if}

<style>
  .toast {
    position: fixed;
    bottom: 20px;
    right: 20px;
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    z-index: 9999;
    animation: slideIn 0.2s ease-out;
  }

  @keyframes slideIn {
    from {
      transform: translateX(400px);
      opacity: 0;
    }
    to {
      transform: translateX(0);
      opacity: 1;
    }
  }

  .toast-success {
    background: #34c759;
    color: #fff;
  }

  .toast-error {
    background: #ff3b30;
    color: #fff;
  }

  .toast-info {
    background: #007aff;
    color: #fff;
  }

  .toast-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    font-weight: 700;
    flex-shrink: 0;
  }

  .toast-message {
    flex: 1;
  }

  .toast-close {
    background: none;
    border: none;
    color: inherit;
    cursor: pointer;
    font-size: 14px;
    padding: 0;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 0.7;
    transition: opacity 0.2s;
    flex-shrink: 0;
  }

  .toast-close:hover {
    opacity: 1;
  }
</style>
