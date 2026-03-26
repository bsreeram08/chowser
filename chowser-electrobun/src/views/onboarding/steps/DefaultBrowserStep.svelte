<script lang="ts">
  import Button from '../../shared/components/Button.svelte';
  import Card from '../../shared/components/Card.svelte';
  import '../../shared/tokens.css';

  interface DefaultBrowserStepProps {
    platform?: 'darwin' | 'win32' | 'linux';
    isAlreadyDefault?: boolean;
    onSetDefault?: () => void;
    onNext?: () => void;
    onSkip?: () => void;
  }

  let {
    platform = 'darwin',
    isAlreadyDefault = false,
    onSetDefault = () => {},
    onNext = () => {},
    onSkip = () => {}
  } = $props<DefaultBrowserStepProps>();

  let settingInProgress = $state(false);
  let justSet = $state(false);

  // Derive platform-specific copy
  const platformLabel = $derived(
    platform === 'win32'
      ? 'Windows Settings'
      : platform === 'linux'
        ? 'a terminal command'
        : 'System Settings'
  );

  const handleSetDefault = async () => {
    settingInProgress = true;
    try {
      // Trigger parent callback which calls the appropriate RPC:
      //   macOS  → rpc.request('openSystemSettings', { uri: 'x-apple.systempreferences:com.apple.preference.desktopscreeneffect' })
      //   Windows → rpc.request('openSystemSettings', { uri: 'ms-settings:defaultapps' })
      //   Linux  → rpc.request('setDefaultBrowser', { method: 'xdg-settings' })
      onSetDefault();
      justSet = true;
    } catch (err) {
      console.error('Failed to trigger default browser setup:', err);
    } finally {
      settingInProgress = false;
    }
  };
</script>

<div class="default-browser-step">
  <div class="content">
    <div class="icon-wrap">🌐</div>

    <h1 class="heading">Set Chowser as Default</h1>
    <p class="description">
      To intercept every link you click, Chowser needs to be your default browser.
      You can change this back at any time from {platformLabel}.
    </p>

    {#if isAlreadyDefault || justSet}
      <Card padding="var(--spacing-4)">
        <div class="already-default">
          <span class="check-icon">✅</span>
          <div class="already-default-text">
            <p class="already-heading">Already set as default</p>
            <p class="already-sub">Chowser is your system default browser.</p>
          </div>
        </div>
      </Card>
    {:else}
      <Card padding="var(--spacing-4)">
        <div class="steps-content">
          <p class="steps-label">How it works:</p>
          <ol class="steps-list">
            {#if platform === 'win32'}
              <li>Click <strong>Set as Default</strong> below</li>
              <li>Windows Settings will open</li>
              <li>Under "Web browser", select <strong>Chowser</strong></li>
            {:else if platform === 'linux'}
              <li>Click <strong>Set as Default</strong> below</li>
              <li>Chowser will run <code>xdg-settings set default-web-browser chowser.desktop</code></li>
              <li>All <code>http://</code> / <code>https://</code> links will route through Chowser</li>
            {:else}
              <li>Click <strong>Set as Default</strong> below</li>
              <li>System Settings will open</li>
              <li>Under <strong>Desktop &amp; Dock → Default web browser</strong>, select <strong>Chowser</strong></li>
            {/if}
          </ol>
        </div>
      </Card>

      <div class="action-group">
        <Button
          variant="primary"
          size="lg"
          onclick={handleSetDefault}
          disabled={settingInProgress}
        >
          {settingInProgress ? 'Opening…' : 'Set as Default'}
        </Button>
      </div>
    {/if}

    {#if isAlreadyDefault || justSet}
      <div class="action-group">
        <Button variant="primary" size="lg" onclick={onNext}>Continue</Button>
      </div>
    {/if}
  </div>

  <div class="footer">
    <button class="skip-button" onclick={onSkip}>
      Skip this step
    </button>
  </div>
</div>

<style>
  @import '../../shared/tokens.css';

  .default-browser-step {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: var(--spacing-6);
    gap: var(--spacing-6);
  }

  .content {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-4);
    overflow-y: auto;
    max-width: 420px;
    align-self: center;
    width: 100%;
  }

  .icon-wrap {
    font-size: 64px;
    line-height: 1;
    text-align: center;
    filter: drop-shadow(0 2px 8px rgba(0, 0, 0, 0.1));
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

  /* Already-default / success state */
  .already-default {
    display: flex;
    align-items: center;
    gap: var(--spacing-4);
  }

  .check-icon {
    font-size: 32px;
    line-height: 1;
    flex-shrink: 0;
  }

  .already-default-text {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-1);
  }

  .already-heading {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
  }

  .already-sub {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
  }

  /* How-it-works card */
  .steps-content {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
    width: 100%;
  }

  .steps-label {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .steps-list {
    margin: 0;
    padding-left: var(--spacing-6);
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .steps-list li {
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-primary);
    line-height: var(--line-height-normal);
  }

  .steps-list code {
    font-family: var(--font-family-mono);
    font-size: var(--font-size-sm);
    background: var(--color-control-background);
    border: 1px solid var(--color-control-border);
    border-radius: var(--radius-sm);
    padding: 1px var(--spacing-2);
    color: var(--color-text-primary);
  }

  /* Action button group */
  .action-group {
    width: 100%;
    max-width: 300px;
  }

  :global(.action-group > button) {
    width: 100%;
  }

  /* Footer skip button */
  .footer {
    display: flex;
    justify-content: center;
  }

  .skip-button {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
    text-decoration: underline;
    text-decoration-color: transparent;
    transition: color 0.2s ease, text-decoration-color 0.2s ease;
  }

  .skip-button:hover {
    color: var(--color-accent);
    text-decoration-color: var(--color-accent);
  }
</style>
