<script lang="ts">
  import Button from '../../shared/components/Button.svelte';
  import '../../shared/tokens.css';

  interface WelcomeStepProps {
    onNext?: () => void;
  }

  let { onNext = () => {} } = $props<WelcomeStepProps>();
</script>

<div class="welcome-step">
  <div class="logo">🧭</div>

  <div class="content">
    <h1 class="heading">Welcome to Chowser</h1>
    <p class="description">
      The beautifully fast browser chooser for macOS. Click any link and choose which browser opens it—automatically.
    </p>
  </div>

  <div class="action">
    <Button variant="primary" size="lg" onclick={onNext}>Get Started</Button>
  </div>
</div>

<style>
  @import '../../shared/tokens.css';

  .welcome-step {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    gap: var(--spacing-8);
    padding: var(--spacing-8);
  }

  .logo {
    font-size: 72px;
    line-height: 1;
    text-align: center;
    filter: drop-shadow(0 2px 8px rgba(0, 0, 0, 0.1));
  }

  .content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-3);
    max-width: 400px;
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

  .action {
    width: 100%;
    max-width: 300px;
  }

  :global(.action > button) {
    width: 100%;
  }
</style>
