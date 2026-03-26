<script lang="ts">
  import Button from '../../shared/components/Button.svelte';
  import Card from '../../shared/components/Card.svelte';
  import '../../shared/tokens.css';

  interface AISetupStepProps {
    serverStatus?: 'running' | 'stopped';
    authToken?: string;
    onStartServer?: () => void;
    onCopyToken?: () => void;
    onCopySetupPrompt?: () => void;
    onSkip?: () => void;
  }

  let {
    serverStatus = 'stopped',
    authToken = '',
    onStartServer = () => {},
    onCopyToken = () => {},
    onCopySetupPrompt = () => {},
    onSkip = () => {}
  } = $props<AISetupStepProps>();

  let copiedToken = $state(false);
  let copiedPrompt = $state(false);
  let showPrompt = $state(false);

  const copyToClipboard = async (text: string, setCopied: (v: boolean) => void) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  const handleCopyToken = async () => {
    await copyToClipboard(authToken, (v) => (copiedToken = v));
    onCopyToken();
  };

  const handleCopyPrompt = async () => {
    const setupPrompt = `Chowser MCP server is running at http://localhost:24245
Auth token: ${authToken}

You can now use AI to manage browsers and routing rules.`;
    await copyToClipboard(setupPrompt, (v) => (copiedPrompt = v));
    onCopySetupPrompt();
  };
</script>

<div class="ai-setup-step">
  <div class="content">
    <h1 class="heading">AI-Powered Configuration</h1>
    <p class="subtitle">(Optional)</p>
    <p class="description">
      Let AI assistants like Claude configure your browsers and routing rules via a local API. Start the MCP server to enable this feature.
    </p>

    {#if serverStatus === 'stopped'}
      <Card padding="var(--spacing-4)">
        <div class="stopped-content">
          <div class="stopped-icon">🤖</div>
          <h2 class="section-heading">Start MCP Server</h2>
          <p class="section-description">
            When enabled, AI assistants can programmatically manage your browsers and rules through a secure local API.
          </p>
          <div class="button-group">
            <Button variant="primary" size="lg" onclick={onStartServer}>
              Start Server
            </Button>
          </div>
        </div>
      </Card>
    {/if}

    {#if serverStatus === 'running' && authToken}
      <Card padding="var(--spacing-4)">
        <div class="running-content">
          <div class="status-badge">
            <span class="status-dot"></span>
            Running
          </div>

          <h2 class="section-heading">Server Active</h2>

          <!-- Token Section -->
          <div class="token-section">
            <div class="label">Auth Token</div>
            <div class="token-display">
              <code class="token-code">{authToken.substring(0, 8)}...{authToken.substring(authToken.length - 8)}</code>
              <Button
                variant="secondary"
                size="sm"
                onclick={handleCopyToken}
              >
                {copiedToken ? '✓ Copied' : 'Copy'}
              </Button>
            </div>
          </div>

          <!-- Setup Prompt Section -->
          <div class="prompt-section">
            <button
              class="prompt-toggle"
              onclick={() => (showPrompt = !showPrompt)}
            >
              <span class="toggle-arrow">{showPrompt ? '▼' : '▶'}</span>
              <span>Setup Instructions for AI</span>
            </button>

            {#if showPrompt}
              <div class="prompt-content">
                <pre class="prompt-text">Chowser MCP server is running at http://localhost:24245
Auth token: {authToken}

You can now use AI to manage browsers and routing rules.</pre>
                <Button
                  variant="secondary"
                  size="sm"
                  onclick={handleCopyPrompt}
                  style="width: 100%;"
                >
                  {copiedPrompt ? '✓ Setup Prompt Copied' : 'Copy Setup Prompt'}
                </Button>
              </div>
            {/if}
          </div>

          <p class="help-text">
            Share the setup instructions with your AI assistant (e.g., Claude) to let it configure Chowser.
          </p>
        </div>
      </Card>
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

  .ai-setup-step {
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
    gap: var(--spacing-4);
    overflow-y: auto;
  }

  .heading {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-2xl);
    font-weight: var(--font-weight-bold);
    color: var(--color-text-primary);
    text-align: center;
  }

  .subtitle {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-secondary);
    text-align: center;
  }

  .description {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
    text-align: center;
    max-width: 450px;
    align-self: center;
    line-height: var(--line-height-normal);
  }

  .stopped-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-4);
    text-align: center;
  }

  .stopped-icon {
    font-size: 48px;
    line-height: 1;
  }

  .section-heading {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-lg);
    font-weight: var(--font-weight-bold);
    color: var(--color-text-primary);
  }

  .section-description {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
    max-width: 380px;
    line-height: var(--line-height-normal);
  }

  .button-group {
    width: 100%;
    max-width: 300px;
  }

  :global(.button-group > button) {
    width: 100%;
  }

  .running-content {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-4);
  }

  .status-badge {
    display: inline-flex;
    align-items: center;
    gap: var(--spacing-2);
    padding: var(--spacing-2) var(--spacing-3);
    background: var(--color-background-tertiary);
    border-radius: var(--radius-md);
    width: fit-content;
    align-self: center;
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-secondary);
  }

  .status-dot {
    width: 8px;
    height: 8px;
    background: #34c759;
    border-radius: 50%;
    display: inline-block;
  }

  .token-section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .label {
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-secondary);
  }

  .token-display {
    display: flex;
    gap: var(--spacing-2);
    align-items: center;
  }

  .token-code {
    flex: 1;
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: var(--font-size-sm);
    background: var(--color-control-background);
    padding: var(--spacing-2) var(--spacing-3);
    border-radius: var(--radius-sm);
    border: 1px solid var(--color-control-border);
    word-break: break-all;
    color: var(--color-text-primary);
  }

  .prompt-section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .prompt-toggle {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-medium);
    color: var(--color-accent);
    transition: color 0.2s ease;
  }

  .prompt-toggle:hover {
    color: var(--color-accent-hover);
  }

  .toggle-arrow {
    display: inline-flex;
    width: 16px;
    height: 16px;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    transition: transform 0.2s ease;
  }

  .prompt-content {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
    padding: var(--spacing-3);
    background: var(--color-background-tertiary);
    border-radius: var(--radius-sm);
    border: 1px solid var(--color-separator);
  }

  .prompt-text {
    margin: 0;
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: var(--font-size-sm);
    background: transparent;
    color: var(--color-text-primary);
    white-space: pre-wrap;
    word-wrap: break-word;
    line-height: var(--line-height-normal);
  }

  .help-text {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
    text-align: center;
  }

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
    transition: color 0.2s ease;
    text-decoration: underline;
    text-decoration-color: transparent;
    transition: text-decoration-color 0.2s ease;
  }

  .skip-button:hover {
    color: var(--color-accent);
    text-decoration-color: var(--color-accent);
  }
</style>
