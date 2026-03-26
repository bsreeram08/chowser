<script lang="ts">
  import Button from '../../shared/components/Button.svelte';
  import Card from '../../shared/components/Card.svelte';
  import '../../shared/tokens.css';

  interface RulesStepProps {
    onNext?: () => void;
    onSkip?: () => void;
  }

  let { onNext = () => {}, onSkip = () => {} } = $props<RulesStepProps>();
</script>

<div class="rules-step">
  <div class="content">
    <div class="header">
      <h1 class="heading">Smart Routing Rules</h1>
      <p class="description">
        Never pick a browser twice. Set up rules to automatically route specific websites to specific browsers.
      </p>
    </div>

    <!-- Visual example of routing -->
    <div class="routing-diagram">
      <div class="url-box">
        <span class="url-icon">🔗</span>
        <span class="url-label">github.com</span>
      </div>
      <div class="arrow">↓</div>
      <div class="route-destinations">
        <Card padding="var(--spacing-4)">
          <div class="route-example">
            <div class="example-icon">💼</div>
            <div class="example-text">
              <div class="example-title">Work Domain</div>
              <div class="example-pattern">*.company.com</div>
              <div class="example-browser">→ Chrome Work</div>
            </div>
          </div>
        </Card>
        <Card padding="var(--spacing-4)">
          <div class="route-example">
            <div class="example-icon">🏠</div>
            <div class="example-text">
              <div class="example-title">Personal Domain</div>
              <div class="example-pattern">github.com</div>
              <div class="example-browser">→ Firefox</div>
            </div>
          </div>
        </Card>
      </div>
    </div>

    <!-- How to create rules -->
    <div class="rules-methods">
      <h2 class="section-heading">Create Rules Two Ways</h2>
      
      <div class="methods-grid">
        <Card padding="var(--spacing-4)">
          <div class="method">
            <div class="method-icon">⚡</div>
            <div class="method-content">
              <div class="method-title">Quick: From Picker</div>
              <p class="method-description">
                Press <code class="key-badge">R</code> while viewing a URL to instantly create a rule for that domain.
              </p>
            </div>
          </div>
        </Card>

        <Card padding="var(--spacing-4)">
          <div class="method">
            <div class="method-icon">⚙️</div>
            <div class="method-content">
              <div class="method-title">Advanced: Settings</div>
              <p class="method-description">
                Open Settings <code class="key-badge">Rules</code> tab for full control: match by domain, path, and source app.
              </p>
            </div>
          </div>
        </Card>
      </div>
    </div>

    <!-- Example -->
    <p class="example-text">
      E.g., open all work emails in Chrome, personal browsing in Firefox, and video sites in Safari.
    </p>
  </div>

  <div class="footer">
    <button class="skip-button" onclick={onSkip}>Skip this step</button>
    <Button variant="primary" size="lg" onclick={onNext}>Continue</Button>
  </div>
</div>

<style>
  @import '../../shared/tokens.css';

  .rules-step {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: var(--spacing-8);
    gap: var(--spacing-6);
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
    text-align: center;
    line-height: var(--line-height-normal);
    max-width: 500px;
    margin-left: auto;
    margin-right: auto;
  }

  /* Routing diagram */
  .routing-diagram {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-3);
  }

  .url-box {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    padding: var(--spacing-3) var(--spacing-4);
    background: var(--color-glass-light);
    border: 1px solid var(--color-glass-border-light);
    border-radius: var(--radius-md);
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
  }

  .url-icon {
    font-size: 18px;
  }

  .url-label {
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: var(--font-size-sm);
  }

  .arrow {
    font-size: 20px;
    color: var(--color-text-secondary);
  }

  .route-destinations {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-3);
    width: 100%;
    max-width: 400px;
  }

  .route-example {
    display: flex;
    align-items: flex-start;
    gap: var(--spacing-3);
  }

  .example-icon {
    font-size: 24px;
    flex-shrink: 0;
  }

  .example-text {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-1);
  }

  .example-title {
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-bold);
    color: var(--color-text-primary);
  }

  .example-pattern {
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
  }

  .example-browser {
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-accent);
  }

  /* Rules creation methods */
  .rules-methods {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-3);
  }

  .section-heading {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-lg);
    font-weight: var(--font-weight-bold);
    color: var(--color-text-primary);
    text-align: center;
  }

  .methods-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--spacing-3);
  }

  @media (max-width: 500px) {
    .methods-grid {
      grid-template-columns: 1fr;
    }
  }

  .method {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-3);
    text-align: center;
  }

  .method-icon {
    font-size: 28px;
  }

  .method-content {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .method-title {
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-bold);
    color: var(--color-text-primary);
  }

  .method-description {
    margin: 0;
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
    line-height: var(--line-height-normal);
  }

  .key-badge {
    display: inline-block;
    padding: 2px 6px;
    background: var(--color-control-background);
    border: 1px solid var(--color-control-border);
    border-radius: var(--radius-sm);
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: 11px;
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
  }

  /* Example text */
  .example-text {
    font-family: var(--font-family-system);
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-regular);
    color: var(--color-text-secondary);
    text-align: center;
    line-height: var(--line-height-normal);
  }

  /* Footer */
  .footer {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-4);
    padding-top: var(--spacing-6);
    border-top: 1px solid var(--color-separator);
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

  .footer :global(button) {
    width: 100%;
    max-width: 300px;
  }
</style>
