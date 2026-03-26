<script lang="ts">
  interface OnboardingShellProps {
    currentStep?: number;
    allowSkip?: boolean;
    onNext?: () => void;
    onBack?: () => void;
    onSkip?: () => void;
    onClose?: () => void;
  }

  let {
    currentStep = 1,
    allowSkip = false,
    onNext = () => {},
    onBack = () => {},
    onSkip = () => {},
    onClose = () => {},
  } = $props<OnboardingShellProps>();

  // Total steps in the onboarding flow (1-5 for Welcome, Default Browser, Browsers, Rules, Finish)
  const TOTAL_STEPS = 5;

  // Derived progress percentage (0% → 20% → 40% → 60% → 80% → 100%)
  let progressPercentage = $derived.by(() => {
    return ((currentStep - 1) / TOTAL_STEPS) * 100;
  });

  // Check if we can go back (disable on step 1)
  let canGoBack = $derived(currentStep > 1);

  // Check if we can go forward (disable on last step)
  let canGoForward = $derived(currentStep < TOTAL_STEPS);

  // Step numbers for the indicator (1-5)
  let stepNumbers = $derived.by(() => {
    return Array.from({ length: TOTAL_STEPS }, (_, i) => i + 1);
  });
</script>

<div class="onboarding-shell">
  {/* Close button in top-right corner */}
  <button
    class="close-button"
    title="Close onboarding"
    onclick={onClose}
    type="button"
    aria-label="Close onboarding wizard"
  >
    ✕
  </button>

  {/* Progress bar at the top */}
  <div class="progress-bar-container">
    <div
      class="progress-bar"
      style="width: {progressPercentage}%"
    ></div>
  </div>

  {/* Step indicator: 5 circles showing current progress */}
  <div class="step-indicator">
    {#each stepNumbers as step}
      <button
        class="step-circle"
        class:active={step === currentStep}
        type="button"
        disabled
        aria-label="Step {step} of {TOTAL_STEPS}"
      >
        {step}
      </button>
    {/each}
  </div>

  {/* Step content slot */}
  <div class="step-content">
    <slot />
  </div>

  {/* Navigation buttons at the bottom */}
  <div class="navigation-buttons">
    <button
      class="nav-button nav-button--back"
      disabled={!canGoBack}
      onclick={onBack}
      type="button"
    >
      ← Back
    </button>

    {#if allowSkip}
      <button
        class="nav-button nav-button--skip"
        onclick={onSkip}
        type="button"
      >
        Skip
      </button>
    {/if}

    <button
      class="nav-button nav-button--next"
      disabled={!canGoForward}
      onclick={onNext}
      type="button"
    >
      Next →
    </button>
  </div>
</div>

<style>
  @import '../../shared/tokens.css';

  .onboarding-shell {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
    background: var(--color-background);
    color: var(--color-text-primary);
    font-family: var(--font-family-system);
    position: relative;
    overflow: hidden;
  }

  /* Close button in top-right corner */
  .close-button {
    position: absolute;
    top: var(--spacing-3);
    right: var(--spacing-3);
    width: 32px;
    height: 32px;
    border-radius: var(--radius-md);
    background: transparent;
    border: 1px solid var(--color-control-border);
    color: var(--color-text-primary);
    cursor: pointer;
    font-size: var(--font-size-lg);
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
    z-index: 10;
  }

  .close-button:hover {
    background: var(--color-background-secondary);
    border-color: var(--color-separator);
  }

  .close-button:active {
    background: var(--color-background-tertiary);
  }

  /* Progress bar at the top */
  .progress-bar-container {
    width: 100%;
    height: 4px;
    background: var(--color-background-secondary);
    overflow: hidden;
  }

  .progress-bar {
    height: 100%;
    background: var(--color-accent);
    transition: width 0.3s ease;
  }

  /* Step indicator: 5 circles */
  .step-indicator {
    display: flex;
    justify-content: center;
    gap: var(--spacing-3);
    padding: var(--spacing-4) var(--spacing-3);
  }

  .step-circle {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    border: 2px solid var(--color-control-border);
    background: var(--color-background);
    color: var(--color-text-secondary);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-semibold);
    cursor: default;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .step-circle.active {
    background: var(--color-accent);
    color: white;
    border-color: var(--color-accent);
  }

  /* Step content area (flexible) */
  .step-content {
    flex: 1;
    padding: var(--spacing-6);
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }

  /* Navigation buttons at the bottom */
  .navigation-buttons {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: var(--spacing-3);
    padding: var(--spacing-4) var(--spacing-6);
    border-top: 1px solid var(--color-separator);
    background: var(--color-background);
  }

  .nav-button {
    font-family: var(--font-family-system);
    font-weight: var(--font-weight-medium);
    font-size: var(--font-size-base);
    padding: var(--spacing-2) var(--spacing-4);
    height: 40px;
    border: 1px solid var(--color-control-border);
    border-radius: var(--radius-md);
    background: var(--color-control-background);
    color: var(--color-text-primary);
    cursor: pointer;
    transition: all 0.2s ease;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
  }

  .nav-button:hover:not(:disabled) {
    background: var(--color-background-secondary);
    border-color: var(--color-separator);
  }

  .nav-button:active:not(:disabled) {
    background: var(--color-background-tertiary);
  }

  .nav-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* Next button styling (primary variant) */
  .nav-button--next {
    background: var(--color-accent);
    color: white;
    border-color: var(--color-accent);
  }

  .nav-button--next:hover:not(:disabled) {
    background: var(--color-accent-hover);
    border-color: var(--color-accent-hover);
  }

  .nav-button--next:active:not(:disabled) {
    background: var(--color-accent-pressed);
    border-color: var(--color-accent-pressed);
  }

  /* Back button styling */
  .nav-button--back {
    margin-right: auto;
  }

  /* Skip button styling (tertiary/ghost variant) */
  .nav-button--skip {
    background: transparent;
    color: var(--color-accent);
    border-color: var(--color-accent);
  }

  .nav-button--skip:hover:not(:disabled) {
    background: var(--color-glass-light);
    border-color: var(--color-accent-hover);
  }

  .nav-button--skip:active:not(:disabled) {
    background: var(--color-control-background);
  }
</style>
