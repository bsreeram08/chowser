<script lang="ts">
  import Button from './Button.svelte';
  import Card from './Card.svelte';

  interface ModalProps {
    isOpen: boolean;
    onClose: () => void;
    title: string;
  }

  let { isOpen, onClose, title } = $props<ModalProps>();

  // Handle Escape key to close modal
  $effect(() => {
    if (!isOpen) return;

    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };

    document.addEventListener('keydown', handleEscape);
    document.body.style.overflow = 'hidden';

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  });
</script>

{#if isOpen}
  <div class="modal-overlay" on:click={onClose} role="presentation">
    <Card class="modal-content" on:click={(e) => e.stopPropagation()}>
      <div class="modal-header">
        <h2 class="modal-title">{title}</h2>
        <Button
          variant="ghost"
          size="sm"
          onclick={onClose}
          class="modal-close"
          aria-label="Close modal"
        >
          ✕
        </Button>
      </div>
      <div class="modal-body">
        <slot />
      </div>
    </Card>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    animation: fadeIn 0.2s ease;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }

  .modal-content {
    width: 90%;
    max-width: 600px;
    max-height: 90vh;
    overflow-y: auto;
    animation: slideUp 0.2s ease;
  }

  @keyframes slideUp {
    from {
      transform: translateY(20px);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-bottom: var(--spacing-3);
    border-bottom: 1px solid var(--color-separator);
    margin-bottom: var(--spacing-4);
  }

  .modal-title {
    font-size: var(--font-size-lg);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
    margin: 0;
  }

  .modal-close {
    flex-shrink: 0;
  }

  .modal-body {
    color: var(--color-text-primary);
  }
</style>
