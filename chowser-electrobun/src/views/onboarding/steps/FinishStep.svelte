<script lang="ts">
  import Button from '../../shared/components/Button.svelte';
  import Card from '../../shared/components/Card.svelte';
  import '../../shared/tokens.css';

  interface FinishStepProps {
    onFinish?: () => void;
    onOpenSettings?: () => void;
  }

  let { onFinish = () => {}, onOpenSettings = () => {} } = $props<FinishStepProps>();
</script>

<div class="finish-step">
  <div class="content">
    <div class="success-emoji">🎉</div>

    <div class="header">
      <h1 class="heading">You're All Set!</h1>
      <p class="description">
        Chowser is ready to route your links intelligently and beautifully.
      </p>
    </div>

    <Card padding="var(--spacing-4)">
      <div class="summary">
        <h2 class="summary-heading">What's Ready:</h2>
        <div class="checklist">
          <div class="checklist-item">
            <span class="checkmark">✅</span>
            <span class="checklist-text">Browsers detected and configured</span>
          </div>
          <div class="checklist-item">
            <span class="checkmark">✅</span>
            <span class="checklist-text">Smart routing enabled</span>
          </div>
          <div class="checklist-item">
            <span class="checkmark">✅</span>
            <span class="checklist-text">AI assistant integration ready</span>
          </div>
        </div>
      </div>
    </Card>

    <div class="next-steps">
      <p class="next-steps-text">
        Next: Set Chowser as your default browser in System Settings to start intercepting links.
      </p>
    </div>
  </div>

  <div class="footer">
    <Button variant="secondary" size="lg" onclick={onOpenSettings}>
      Open Settings
    </Button>
    <Button variant="primary" size="lg" onclick={onFinish}>
      Start Using Chowser
    </Button>
  </div>
</div>

<style>
  @import '../../shared/tokens.css';

  .finish-step {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: space-between;
    height: 100%;
    gap: var(--spacing-6);
    padding: var(--spacing-8);
  }

  .content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-6);
    max-width: 420px;
    flex: 1;
    overflow-y: auto;
    justify-content: center;
  }

  .success-emoji {
    font-size: 64px;
    line-height: 1;
    text-align: center;
    filter: drop-shadow(0 2px 8px rgba(0, 0, 0, 0.1));
    animation: bounce 0.6s ease-out;
  }

  @keyframes bounce {
    0% {
      transform: scale(0.8);
      opacity: 0;
    }
    75% {
      transform: scale(1.05);
    }
    100% {
      transform: scale(1);
      opacity: 1;
    }
  }

  .header {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-3);
  }

  .heading {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-2xl);
    font-weight: var(--font-weight-bold);
    color: var(--color-text-primary);
    text-align: center;
    line-height: var(--line-height-tight);
  }

  .description {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
    text-align: center;
    line-height: var(--line-height-normal);
  }

  .summary {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-4);
  }

  .summary-heading {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
  }

  .checklist {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .checklist-item {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    color: var(--color-text-primary);
    line-height: var(--line-height-normal);
  }

  .checkmark {
    flex-shrink: 0;
    font-size: 16px;
  }

  .checklist-text {
    flex: 1;
  }

  .next-steps {
    text-align: center;
  }

  .next-steps-text {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    line-height: var(--line-height-normal);
  }

  .footer {
    display: flex;
    gap: var(--spacing-4);
    width: 100%;
    max-width: 420px;
    justify-content: center;
  }

  :global(.footer > button) {
    flex: 1;
  }
</style>
