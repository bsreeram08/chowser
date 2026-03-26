<script lang="ts">
  import { rpc } from '../../bun-rpc';
  import RuleRow from '../components/RuleRow.svelte';
  import Modal from '../../shared/components/Modal.svelte';
  import Input from '../../shared/components/Input.svelte';
  import Button from '../../shared/components/Button.svelte';
  import Toggle from '../../shared/components/Toggle.svelte';

  interface Rule {
    id: string;
    name: string;
    hostPattern: string;
    pathPrefix?: string;
    browserAppId: string;
    browserName: string;
    profile?: string;
    usePrivateMode: boolean;
    useRegex: boolean;
    sourceAppBundleId?: string;
    isEnabled: boolean;
  }

  interface Browser {
    id: string;
    name: string;
    appId: string;
  }

  // State
  let rules = $state<Rule[]>([]);
  let browsers = $state<Browser[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  // Modal state
  let showAddRuleModal = $state(false);
  let showEditRuleModal = $state(false);
  let editingRuleId = $state<string | null>(null);

  // Tester state
  let testerUrl = $state('');
  let testerResult = $state<{ browserName: string } | null>(null);
  let testerLoading = $state(false);

  // Form state for add/edit
  let formData = $state({
    name: '',
    hostPattern: '',
    pathPrefix: '',
    browserAppId: '',
    profile: '',
    usePrivateMode: false,
    useRegex: false,
    sourceAppBundleId: ''
  });

  // Load initial data
  $effect.root(() => {
    loadRules();
  });

  async function loadRules() {
    try {
      loading = true;
      error = null;
      const [rulesData, browsersData] = await Promise.all([
        rpc.call('getRules', undefined),
        rpc.call('getBrowsers', undefined)
      ]);
      rules = rulesData;
      browsers = browsersData;
    } catch (e) {
      error = `Failed to load rules: ${e instanceof Error ? e.message : String(e)}`;
    } finally {
      loading = false;
    }
  }

  function resetForm() {
    formData = {
      name: '',
      hostPattern: '',
      pathPrefix: '',
      browserAppId: '',
      profile: '',
      usePrivateMode: false,
      useRegex: false,
      sourceAppBundleId: ''
    };
  }

  function openAddRuleModal() {
    resetForm();
    editingRuleId = null;
    showAddRuleModal = true;
  }

  function openEditRuleModal(ruleId: string) {
    const rule = rules.find(r => r.id === ruleId);
    if (!rule) return;

    formData = {
      name: rule.name,
      hostPattern: rule.hostPattern,
      pathPrefix: rule.pathPrefix || '',
      browserAppId: rule.browserAppId,
      profile: rule.profile || '',
      usePrivateMode: rule.usePrivateMode,
      useRegex: rule.useRegex,
      sourceAppBundleId: rule.sourceAppBundleId || ''
    };

    editingRuleId = ruleId;
    showEditRuleModal = true;
  }

  function closeModals() {
    showAddRuleModal = false;
    showEditRuleModal = false;
    editingRuleId = null;
    resetForm();
  }

  async function handleSaveRule() {
    if (!formData.name.trim() || !formData.hostPattern.trim() || !formData.browserAppId) {
      error = 'Please fill in all required fields (Name, Host Pattern, Browser)';
      return;
    }

    try {
      error = null;

      if (editingRuleId) {
        // Update existing rule
        await rpc.call('updateRule', {
          id: editingRuleId,
          ...formData,
          pathPrefix: formData.pathPrefix || undefined
        });
      } else {
        // Create new rule
        await rpc.call('addRule', {
          id: crypto.randomUUID(),
          isEnabled: true,
          ...formData,
          pathPrefix: formData.pathPrefix || undefined
        });
      }

      closeModals();
      await loadRules();
    } catch (e) {
      error = `Failed to save rule: ${e instanceof Error ? e.message : String(e)}`;
    }
  }

  async function handleToggleRule(ruleId: string, enabled: boolean) {
    try {
      error = null;
      await rpc.call('toggleRule', { id: ruleId, enabled });
      await loadRules();
    } catch (e) {
      error = `Failed to toggle rule: ${e instanceof Error ? e.message : String(e)}`;
    }
  }

  async function handleDuplicateRule(ruleId: string) {
    const rule = rules.find(r => r.id === ruleId);
    if (!rule) return;

    try {
      error = null;
      const newId = crypto.randomUUID();
      await rpc.call('addRule', {
        id: newId,
        name: `${rule.name} (Copy)`,
        hostPattern: rule.hostPattern,
        pathPrefix: rule.pathPrefix,
        browserAppId: rule.browserAppId,
        profile: rule.profile,
        usePrivateMode: rule.usePrivateMode,
        useRegex: rule.useRegex,
        sourceAppBundleId: rule.sourceAppBundleId,
        isEnabled: rule.isEnabled
      });
      await loadRules();
    } catch (e) {
      error = `Failed to duplicate rule: ${e instanceof Error ? e.message : String(e)}`;
    }
  }

  async function handleDeleteRule(ruleId: string) {
    if (!window.confirm('Are you sure you want to delete this rule?')) return;

    try {
      error = null;
      await rpc.call('deleteRule', { id: ruleId });
      await loadRules();
    } catch (e) {
      error = `Failed to delete rule: ${e instanceof Error ? e.message : String(e)}`;
    }
  }

  async function handleTestUrl() {
    if (!testerUrl.trim()) return;

    try {
      testerLoading = true;
      const result = await rpc.call('testRule', { url: testerUrl });
      testerResult = result;
    } catch (e) {
      testerResult = null;
    } finally {
      testerLoading = false;
    }
  }
</script>

<div class="rules-tab">
  <!-- Header -->
  <div class="header">
    <div>
      <h2 class="title">Routing Rules</h2>
      <p class="subtitle">Auto-open matching URLs in specific browsers</p>
    </div>
    <Button variant="primary" onclick={openAddRuleModal}>
      + Add Rule
    </Button>
  </div>

  <!-- Error message -->
  {#if error}
    <div class="error-banner">
      {error}
      <button class="error-close" onclick={() => (error = null)}>✕</button>
    </div>
  {/if}

  <!-- Tester section -->
  <div class="tester-section">
    <div class="tester-header">
      <h3 class="tester-title">Rule Tester</h3>
      <p class="tester-subtitle">Paste a URL to see which rule would match</p>
    </div>
    <div class="tester-input-group">
      <Input
        placeholder="https://example.com/path"
        value={testerUrl}
        onchange={(val) => (testerUrl = val)}
      />
      <Button
        variant="secondary"
        onclick={handleTestUrl}
        disabled={!testerUrl.trim() || testerLoading}
      >
        {testerLoading ? 'Testing...' : 'Test'}
      </Button>
    </div>
    {#if testerUrl.trim()}
      <div class="tester-result">
        {#if testerResult}
          <div class="result-match">
            <span class="result-icon">✓</span>
            <div class="result-text">
              <div class="result-label">Match Found</div>
              <div class="result-value">Opens in {testerResult.browserName}</div>
            </div>
          </div>
        {:else}
          <div class="result-no-match">
            <span class="result-icon">–</span>
            <div class="result-text">
              <div class="result-label">No Matching Rule</div>
              <div class="result-value">Browser picker will appear</div>
            </div>
          </div>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Rules list -->
  <div class="rules-section">
    <h3 class="rules-header">Rules</h3>
    {#if loading}
      <div class="empty-state">
        <p>Loading rules...</p>
      </div>
    {:else if rules.length === 0}
      <div class="empty-state">
        <p>No rules configured yet</p>
        <p class="empty-hint">Click "Add Rule" to create your first routing rule</p>
      </div>
    {:else}
      <div class="rules-list">
        {#each rules as rule (rule.id)}
          <RuleRow
            {rule}
            onToggle={handleToggleRule}
            onEdit={openEditRuleModal}
            onDuplicate={handleDuplicateRule}
            onDelete={handleDeleteRule}
          />
        {/each}
      </div>
    {/if}
  </div>
</div>

<!-- Add/Edit Rule Modal -->
<Modal
  isOpen={showAddRuleModal || showEditRuleModal}
  onClose={closeModals}
  title={editingRuleId ? 'Edit Rule' : 'Add New Rule'}
>
  <form on:submit|preventDefault={handleSaveRule} class="rule-form">
    <!-- Name -->
    <div class="form-group">
      <Input
        label="Rule Name"
        placeholder="e.g., GitHub at Work"
        value={formData.name}
        onchange={(val) => (formData.name = val)}
      />
    </div>

    <!-- Host Pattern -->
    <div class="form-group">
      <Input
        label="Host Pattern (glob or regex)"
        placeholder="e.g., *.github.com or github.com"
        value={formData.hostPattern}
        onchange={(val) => (formData.hostPattern = val)}
      />
    </div>

    <!-- Path Prefix (optional) -->
    <div class="form-group">
      <Input
        label="Path Prefix (optional)"
        placeholder="e.g., /work"
        value={formData.pathPrefix}
        onchange={(val) => (formData.pathPrefix = val)}
      />
    </div>

    <!-- Browser selector -->
    <div class="form-group">
      <label class="form-label">Browser</label>
      <select
        class="browser-select"
        value={formData.browserAppId}
        onchange={(e) => {
          const target = e.target as HTMLSelectElement;
          formData.browserAppId = target.value;
        }}
      >
        <option value="">Select a browser...</option>
        {#each browsers as browser (browser.id)}
          <option value={browser.appId}>{browser.name}</option>
        {/each}
      </select>
    </div>

    <!-- Toggles -->
    <div class="form-toggles">
      <div class="toggle-item">
        <label class="toggle-label">
          <Toggle
            checked={formData.useRegex}
            onchange={(val) => (formData.useRegex = val)}
          />
          <span>Use Regex</span>
        </label>
      </div>
      <div class="toggle-item">
        <label class="toggle-label">
          <Toggle
            checked={formData.usePrivateMode}
            onchange={(val) => (formData.usePrivateMode = val)}
          />
          <span>Private Mode</span>
        </label>
      </div>
    </div>

    <!-- Form actions -->
    <div class="form-actions">
      <Button variant="secondary" onclick={closeModals} type="button">
        Cancel
      </Button>
      <Button variant="primary" type="submit">
        {editingRuleId ? 'Update Rule' : 'Create Rule'}
      </Button>
    </div>
  </form>
</Modal>

<style>
  .rules-tab {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-6);
    max-width: 1000px;
  }

  /* Header */
  .header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: var(--spacing-4);
  }

  .title {
    font-size: var(--font-size-2xl);
    font-weight: var(--font-weight-bold);
    color: var(--color-text-primary);
    margin: 0;
  }

  .subtitle {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    margin: var(--spacing-2) 0 0 0;
  }

  /* Error banner */
  .error-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--spacing-3);
    padding: var(--spacing-3) var(--spacing-4);
    background-color: rgba(255, 59, 48, 0.1);
    border: 1px solid rgba(255, 59, 48, 0.2);
    border-radius: var(--radius-md);
    color: var(--color-error);
    font-size: var(--font-size-sm);
  }

  .error-close {
    background: none;
    border: none;
    color: var(--color-error);
    cursor: pointer;
    padding: 0;
    font-size: var(--font-size-sm);
    opacity: 0.7;
    transition: opacity 0.2s ease;
  }

  .error-close:hover {
    opacity: 1;
  }

  /* Tester section */
  .tester-section {
    padding: var(--spacing-4);
    background-color: var(--color-background-secondary);
    border-radius: var(--radius-lg);
    border: 1px solid var(--color-separator);
  }

  .tester-header {
    margin-bottom: var(--spacing-3);
  }

  .tester-title {
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
    margin: 0;
  }

  .tester-subtitle {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    margin: var(--spacing-1) 0 0 0;
  }

  .tester-input-group {
    display: flex;
    gap: var(--spacing-3);
    margin-bottom: var(--spacing-3);
  }

  .tester-input-group > :global(*:first-child) {
    flex: 1;
  }

  .tester-result {
    margin-top: var(--spacing-3);
  }

  .result-match,
  .result-no-match {
    display: flex;
    gap: var(--spacing-3);
    padding: var(--spacing-3);
    border-radius: var(--radius-md);
    font-size: var(--font-size-sm);
  }

  .result-match {
    background-color: rgba(52, 199, 89, 0.1);
    border: 1px solid rgba(52, 199, 89, 0.2);
  }

  .result-no-match {
    background-color: rgba(100, 100, 100, 0.1);
    border: 1px solid rgba(100, 100, 100, 0.2);
  }

  .result-icon {
    font-weight: var(--font-weight-bold);
    min-width: 24px;
    display: flex;
    align-items: center;
  }

  .result-match .result-icon {
    color: var(--color-success);
  }

  .result-no-match .result-icon {
    color: var(--color-text-secondary);
  }

  .result-text {
    flex: 1;
  }

  .result-label {
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
  }

  .result-value {
    font-size: var(--font-size-xs);
    color: var(--color-text-secondary);
    margin-top: 2px;
  }

  /* Rules section */
  .rules-section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-3);
  }

  .rules-header {
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
    margin: 0;
  }

  .rules-list {
    border: 1px solid var(--color-separator);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .empty-state {
    padding: var(--spacing-8);
    text-align: center;
    background-color: var(--color-background-secondary);
    border: 1px solid var(--color-separator);
    border-radius: var(--radius-lg);
  }

  .empty-state > p {
    font-size: var(--font-size-base);
    color: var(--color-text-primary);
    margin: 0;
  }

  .empty-hint {
    font-size: var(--font-size-sm) !important;
    color: var(--color-text-secondary) !important;
    margin-top: var(--spacing-2) !important;
  }

  /* Form styles */
  .rule-form {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-4);
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .form-label {
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
  }

  .browser-select {
    font-family: var(--font-family-system);
    font-size: var(--font-size-base);
    padding: var(--spacing-3);
    height: 40px;
    border: 1px solid var(--color-control-border);
    border-radius: var(--radius-md);
    background-color: var(--color-control-background);
    color: var(--color-text-primary);
    cursor: pointer;
    transition: border-color 0.2s ease;
  }

  .browser-select:focus {
    outline: none;
    border-color: var(--color-accent);
    box-shadow: 0 0 0 2px rgba(0, 102, 255, 0.1);
  }

  /* Toggles */
  .form-toggles {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-3);
    padding: var(--spacing-3);
    background-color: var(--color-background-secondary);
    border-radius: var(--radius-md);
  }

  .toggle-item {
    display: flex;
    align-items: center;
  }

  .toggle-label {
    display: flex;
    align-items: center;
    gap: var(--spacing-3);
    cursor: pointer;
    font-size: var(--font-size-sm);
    color: var(--color-text-primary);
  }

  /* Form actions */
  .form-actions {
    display: flex;
    gap: var(--spacing-3);
    justify-content: flex-end;
    margin-top: var(--spacing-3);
    padding-top: var(--spacing-3);
    border-top: 1px solid var(--color-separator);
  }
</style>
