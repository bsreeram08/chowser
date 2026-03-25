<script lang="ts">
  import Modal from '../../shared/components/Modal.svelte';
  import Input from '../../shared/components/Input.svelte';
  import Button from '../../shared/components/Button.svelte';
  import Toggle from '../../shared/components/Toggle.svelte';

  interface Browser {
    id: string;
    name: string;
    appId: string;
    profiles?: Array<{ name: string; path: string }>;
  }

  interface QuickRuleSheetProps {
    isOpen: boolean;
    url: string;
    browsers: Browser[];
    onSave: (rule: {
      host: string;
      browserId: string;
      profile?: string;
      isPrivate: boolean;
    }) => void;
    onCancel: () => void;
  }

  let {
    isOpen,
    url,
    browsers,
    onSave,
    onCancel
  } = $props<QuickRuleSheetProps>();

  // Local state
  let host = $state('');
  let selectedBrowserId = $state('');
  let selectedProfile = $state('');
  let isPrivate = $state(false);

  // Derived state
  const selectedBrowser = $derived(browsers.find(b => b.id === selectedBrowserId));
  const hasProfiles = $derived(selectedBrowser?.profiles && selectedBrowser.profiles.length > 0);
  const canSave = $derived(host.trim().length > 0 && selectedBrowserId.length > 0);

  // Initialize form when modal opens
  $effect(() => {
    if (isOpen) {
      // Parse hostname from URL
      try {
        const parsedUrl = new URL(url);
        host = parsedUrl.hostname;
      } catch {
        host = '';
      }

      // Set first browser as default
      if (browsers.length > 0 && !selectedBrowserId) {
        selectedBrowserId = browsers[0].id;
        selectedProfile = '';
      }

      // Reset private mode
      isPrivate = false;
    }
  });

  // Reset form when browser selection changes
  $effect(() => {
    if (selectedBrowserId) {
      selectedProfile = '';
    }
  });

  function handleSave() {
    if (!canSave) return;

    onSave({
      host: host.trim(),
      browserId: selectedBrowserId,
      profile: selectedProfile || undefined,
      isPrivate
    });

    // Reset form after save
    host = '';
    selectedBrowserId = '';
    selectedProfile = '';
    isPrivate = false;
  }

  function handleCancel() {
    // Reset form state
    host = '';
    selectedBrowserId = '';
    selectedProfile = '';
    isPrivate = false;
    onCancel();
  }
</script>

<Modal {isOpen} onClose={handleCancel} title="Create Routing Rule">
  <div class="quick-rule-form">
    <div class="form-section">
      <Input
        label="Host Pattern"
        placeholder="e.g., github.com"
        value={host}
        onchange={(value) => {
          host = value;
        }}
      />
    </div>

    <div class="form-section">
      <label class="form-label">Open In</label>
      <select
        class="browser-select"
        value={selectedBrowserId}
        onchange={(e) => {
          selectedBrowserId = (e.currentTarget as HTMLSelectElement).value;
        }}
      >
        <option value="">Select a browser...</option>
        {#each browsers as browser (browser.id)}
          <option value={browser.id}>{browser.name}</option>
        {/each}
      </select>
    </div>

    {#if hasProfiles}
      <div class="form-section">
        <label class="form-label">Profile</label>
        <select
          class="profile-select"
          value={selectedProfile}
          onchange={(e) => {
            selectedProfile = (e.currentTarget as HTMLSelectElement).value;
          }}
        >
          <option value="">Default Profile</option>
          {#each selectedBrowser?.profiles ?? [] as profile (profile.path)}
            <option value={profile.path}>{profile.name}</option>
          {/each}
        </select>
      </div>
    {/if}

    <div class="form-section toggle-section">
      <div class="toggle-label-wrapper">
        <span class="form-label">Private Mode</span>
      </div>
      <Toggle
        checked={isPrivate}
        onchange={(checked) => {
          isPrivate = checked;
        }}
      />
    </div>

    <div class="button-group">
      <Button
        variant="secondary"
        size="md"
        onclick={handleCancel}
      >
        Cancel
      </Button>
      <Button
        variant="primary"
        size="md"
        disabled={!canSave}
        onclick={handleSave}
      >
        Save Rule
      </Button>
    </div>
  </div>
</Modal>

<style>
  .quick-rule-form {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-4);
  }

  .form-section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .form-label {
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
  }

  .browser-select,
  .profile-select {
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
    appearance: none;
    padding-right: var(--spacing-6);
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'%3E%3Cpath fill='%230066ff' d='M1 1l5 5 5-5'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right var(--spacing-3) center;
  }

  .browser-select:focus,
  .profile-select:focus {
    outline: none;
    border-color: var(--color-accent);
    box-shadow: 0 0 0 2px rgba(0, 102, 255, 0.1);
  }

  .browser-select:disabled,
  .profile-select:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .toggle-section {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: var(--spacing-3);
  }

  .toggle-label-wrapper {
    flex: 1;
  }

  .button-group {
    display: flex;
    gap: var(--spacing-3);
    justify-content: flex-end;
    margin-top: var(--spacing-2);
  }

  @media (prefers-color-scheme: dark) {
    .browser-select,
    .profile-select {
      background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'%3E%3Cpath fill='%230a84ff' d='M1 1l5 5 5-5'/%3E%3C/svg%3E");
    }
  }
</style>
