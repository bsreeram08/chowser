<script lang="ts">
  import Button from '../../shared/components/Button.svelte';
  import BrowserIcon from '../../shared/components/BrowserIcon.svelte';
  import '../../shared/tokens.css';

  interface Browser {
    id: string;
    name: string;
    appId: string;
    profiles?: string[];
  }

  interface BrowsersStepProps {
    browsers?: Browser[];
    onBrowserToggle?: (browserId: string, included: boolean) => void;
    onDetectAgain?: () => void;
    onNext?: () => void;
  }

  let {
    browsers = [],
    onBrowserToggle = () => {},
    onDetectAgain = () => {},
    onNext = () => {}
  } = $props<BrowsersStepProps>();

  // Local state for checkboxes — track which browsers are included
  let browserStates = $state<Record<string, boolean>>({});

  // Initialize browser states on prop change
  $effect(() => {
    browsers.forEach(browser => {
      if (!(browser.id in browserStates)) {
        browserStates[browser.id] = true; // Default to checked
      }
    });
  });

  const handleBrowserToggle = (browserId: string) => {
    const newState = !browserStates[browserId];
    browserStates[browserId] = newState;
    onBrowserToggle(browserId, newState);
  };

  const getProfileCount = (browser: Browser): string => {
    const count = browser.profiles?.length ?? 0;
    if (count === 0) return 'Default';
    if (count === 1) return '1 profile';
    return `${count} profiles`;
  };
</script>

<div class="browsers-step">
  <div class="content">
    <div class="header">
      <h1 class="heading">Choose Your Browsers</h1>
      <p class="description">
        We found these browsers on your system. Uncheck any you don't want to use with Chowser.
      </p>
    </div>

    {#if browsers.length > 0}
      <div class="browser-list">
        {#each browsers as browser (browser.id)}
          <div class="browser-item">
            <input
              type="checkbox"
              id="browser-{browser.id}"
              bind:checked={browserStates[browser.id]}
              onchange={() => handleBrowserToggle(browser.id)}
            />
            <label for="browser-{browser.id}" class="browser-label">
              <div class="icon-wrapper">
                <BrowserIcon bundleId={browser.appId} size="medium" />
              </div>
              <div class="browser-info">
                <div class="browser-name">{browser.name}</div>
                <div class="browser-profiles">{getProfileCount(browser)}</div>
              </div>
            </label>
          </div>
        {/each}
      </div>
    {/if}

    <div class="detect-button-wrapper">
      <Button variant="secondary" onclick={onDetectAgain}>🔍 Detect Again</Button>
    </div>
  </div>

  <div class="footer">
    <Button variant="primary" size="lg" onclick={onNext}>Continue</Button>
  </div>
</div>

<style>
  @import '../../shared/tokens.css';

  .browsers-step {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: var(--spacing-8);
  }

  .content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: var(--spacing-6);
    overflow-y: auto;
  }

  .header {
    text-align: center;
  }

  .heading {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-2xl);
    font-weight: var(--font-weight-bold);
    color: var(--color-text-primary);
    line-height: var(--line-height-tight);
  }

  .description {
    margin: var(--spacing-3) 0 0 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
    line-height: var(--line-height-normal);
    max-width: 500px;
    margin-left: auto;
    margin-right: auto;
  }

  .browser-list {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-3);
  }

  .browser-item {
    display: flex;
    align-items: flex-start;
    gap: var(--spacing-4);
    padding: var(--spacing-3) var(--spacing-4);
    border: 1px solid var(--color-control-border);
    border-radius: var(--radius-md);
    background-color: var(--color-control-background);
    transition: all 0.2s ease;
  }

  .browser-item:hover {
    background-color: var(--color-background-secondary);
    border-color: var(--color-separator);
  }

  input[type='checkbox'] {
    margin-top: var(--spacing-2);
    cursor: pointer;
    width: 18px;
    height: 18px;
    flex-shrink: 0;
  }

  .browser-label {
    display: flex;
    align-items: center;
    gap: var(--spacing-4);
    flex: 1;
    cursor: pointer;
  }

  .icon-wrapper {
    flex-shrink: 0;
  }

  .browser-info {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-1);
  }

  .browser-name {
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
  }

  .browser-profiles {
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
  }

  .detect-button-wrapper {
    display: flex;
    justify-content: center;
    margin-top: var(--spacing-4);
  }

  .detect-button-wrapper :global(button) {
    width: auto;
  }

  .footer {
    display: flex;
    justify-content: center;
    gap: var(--spacing-4);
    padding-top: var(--spacing-6);
    border-top: 1px solid var(--color-separator);
  }

  .footer :global(button) {
    width: 100%;
    max-width: 300px;
  }
</style>
