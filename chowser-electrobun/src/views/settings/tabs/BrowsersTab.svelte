<script lang="ts">
  import { onMount } from 'svelte';
  import {
    DndContext,
    closestCenter,
    KeyboardSensor,
    PointerSensor,
    useSensor,
    useSensors,
    type DragEndEvent,
  } from '@dnd-kit/core';
  import {
    arrayMove,
    SortableContext,
    sortableKeyboardCoordinates,
    verticalListSortingStrategy,
  } from '@dnd-kit/sortable';
  import BrowserConfigRow from '../components/BrowserConfigRow.svelte';
  import Modal from '../../shared/components/Modal.svelte';
  import Button from '../../shared/components/Button.svelte';
  import Input from '../../shared/components/Input.svelte';
  import SortableBrowserRow from './SortableBrowserRow.svelte';

  interface BrowsersTabProps {
    rpc: any;
  }

  let { rpc } = $props<BrowsersTabProps>();

  interface BrowserConfig {
    id: string;
    name: string;
    appId: string;
    shortcutKey: string;
    profile?: string;
    customArguments?: string;
  }

  // State
  let browsers = $state<BrowserConfig[]>([]);
  let isLoading = $state(false);
  let isAddModalOpen = $state(false);
  let isEditModalOpen = $state(false);
  let isDeleteConfirmOpen = $state(false);
  let editingBrowser = $state<BrowserConfig | null>(null);
  let deleteTargetId = $state<string | null>(null);

  // Toast state
  let toastMessage = $state('');
  let toastType = $state<'success' | 'error'>('success');
  let showToast = $state(false);
  let fileInput = $state<HTMLInputElement | null>(null);

  // Form state
  let formName = $state('');
  let formAppId = $state('');
  let formShortcutKey = $state('');
  let formProfile = $state('');
  let formCustomArgs = $state('');

  // Setup sensors for drag-to-reorder
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  // Load browsers on mount
  onMount(async () => {
    await loadBrowsers();
  });

  // Load browsers from RPC
  async function loadBrowsers() {
    isLoading = true;
    try {
      const state = await rpc.request('getState', undefined);
      browsers = state.browsers || [];
    } catch (error) {
      console.error('Failed to load browsers:', error);
      showNotification('Failed to load browsers', 'error');
    } finally {
      isLoading = false;
    }
  }

  // Detect installed browsers
  async function handleDetectBrowsers() {
    isLoading = true;
    try {
      const detected = await rpc.request('detectBrowsers', undefined);
      if (Array.isArray(detected)) {
        browsers = detected;
        showNotification('Browsers detected successfully', 'success');
      }
    } catch (error) {
      console.error('Failed to detect browsers:', error);
      showNotification('Failed to detect browsers', 'error');
    } finally {
      isLoading = false;
    }
  }

  // Add browser
  async function handleAddBrowser() {
    if (!formName.trim() || !formAppId.trim()) {
      showNotification('Browser name and app ID are required', 'error');
      return;
    }

    const newBrowser: BrowserConfig = {
      id: crypto.randomUUID(),
      name: formName,
      appId: formAppId,
      shortcutKey: formShortcutKey,
      profile: formProfile || undefined,
      customArguments: formCustomArgs || undefined,
    };

    try {
      await rpc.request('addBrowser', newBrowser);
      browsers = [...browsers, newBrowser];
      resetForm();
      isAddModalOpen = false;
      showNotification('Browser added successfully', 'success');
    } catch (error) {
      console.error('Failed to add browser:', error);
      showNotification('Failed to add browser', 'error');
    }
  }

  // Update browser
  async function handleUpdateBrowser() {
    if (!editingBrowser) return;

    const updated: BrowserConfig = {
      ...editingBrowser,
      name: formName,
      appId: formAppId,
      shortcutKey: formShortcutKey,
      profile: formProfile || undefined,
      customArguments: formCustomArgs || undefined,
    };

    try {
      await rpc.request('updateBrowser', updated);
      browsers = browsers.map((b) => (b.id === editingBrowser.id ? updated : b));
      resetForm();
      isEditModalOpen = false;
      editingBrowser = null;
      showNotification('Browser updated successfully', 'success');
    } catch (error) {
      console.error('Failed to update browser:', error);
      showNotification('Failed to update browser', 'error');
    }
  }

  // Delete browser
  async function handleConfirmDelete() {
    if (!deleteTargetId) return;

    try {
      await rpc.request('removeBrowser', { id: deleteTargetId });
      browsers = browsers.filter((b) => b.id !== deleteTargetId);
      isDeleteConfirmOpen = false;
      deleteTargetId = null;
      showNotification('Browser deleted successfully', 'success');
    } catch (error) {
      console.error('Failed to delete browser:', error);
      showNotification('Failed to delete browser', 'error');
    }
  }

  // Reorder browsers
  async function handleReorder(newBrowserIds: string[]) {
    try {
      await rpc.request('reorderBrowsers', { ids: newBrowserIds });
    } catch (error) {
      console.error('Failed to reorder browsers:', error);
    }
  }

  // Handle drag end
  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;

    if (!over || active.id === over.id) {
      return;
    }

    const oldIndex = browsers.findIndex((b) => b.id === active.id);
    const newIndex = browsers.findIndex((b) => b.id === over.id);

    if (oldIndex !== -1 && newIndex !== -1) {
      browsers = arrayMove(browsers, oldIndex, newIndex);
      const newBrowserIds = browsers.map((b) => b.id);
      handleReorder(newBrowserIds);
    }
  }

  // Open edit modal
  function openEditModal(browser: BrowserConfig) {
    editingBrowser = browser;
    formName = browser.name;
    formAppId = browser.appId;
    formShortcutKey = browser.shortcutKey;
    formProfile = browser.profile || '';
    formCustomArgs = browser.customArguments || '';
    isEditModalOpen = true;
  }

  // Open delete confirmation
  function openDeleteConfirm(browserId: string) {
    deleteTargetId = browserId;
    isDeleteConfirmOpen = true;
  }

  // Reset form
  function resetForm() {
    formName = '';
    formAppId = '';
    formShortcutKey = '';
    formProfile = '';
    formCustomArgs = '';
  }

  // Open add modal
  function openAddModal() {
    resetForm();
    isAddModalOpen = true;
  }

  // Handle row update
  function handleRowUpdate(browserId: string, updates: Partial<BrowserConfig>) {
    const browser = browsers.find((b) => b.id === browserId);
    if (browser) {
      const updated = { ...browser, ...updates };
      browsers = browsers.map((b) => (b.id === browserId ? updated : b));

      // Call RPC to update
      fetch(`http://localhost:24245/api/browsers/${browserId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updated),
      }).catch((error) => console.error('Failed to update browser:', error));
    }
  }

  // Handle row delete
  function handleRowDelete(browserId: string) {
    openDeleteConfirm(browserId);
  }

  // Export browsers to JSON
  async function handleExportBrowsers() {
    try {
      const configJson = await rpc.request('exportConfig', undefined);
      const jsonStr = configJson;
      const blob = new Blob([jsonStr], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `chowser-config-${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      showNotification('Configuration exported successfully', 'success');
    } catch (error) {
      console.error('Export failed:', error);
      showNotification('Failed to export configuration', 'error');
    }
  }

  // Import configuration from JSON
  function handleImportBrowsers() {
    fileInput?.click();
  }

  // Process selected file
  async function onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      const result = await rpc.request('importConfig', { json: text });
      
      if (result.success) {
        await loadBrowsers();
        showNotification('Configuration imported successfully', 'success');
      } else {
        showNotification(result.message || 'Import failed', 'error');
      }
    } catch (err) {
      console.error('Import failed:', err);
      const message = err instanceof Error ? err.message : 'Import failed';
      showNotification(message, 'error');
    } finally {
      // Reset input
      if (fileInput) {
        fileInput.value = '';
      }
    }
  }

  // Show notification helper
  function showNotification(message: string, type: 'success' | 'error' = 'success') {
    toastMessage = message;
    toastType = type;
    showToast = true;
    setTimeout(() => { showToast = false; }, 3000);
  }
</script>

<div class="browsers-tab">
  <!-- Hidden file input -->
  <input
    bind:this={fileInput}
    type="file"
    accept=".json"
    style="display: none"
    onchange={onFileSelected}
  />

  <!-- Toast notification -->
  {#if showToast}
    <div class={`toast toast-${toastType}`}>
      <span class="toast-icon">
        {toastType === 'success' ? '✓' : '✕'}
      </span>
      <span class="toast-message">{toastMessage}</span>
    </div>
  {/if}
  <!-- Toolbar -->
  <div class="toolbar">
    <div class="toolbar-title">
      <h2>Browsers</h2>
      <p>Configure which browsers appear in the picker and assign keyboard shortcuts.</p>
    </div>

    <div class="toolbar-actions">
      <Button variant="secondary" size="md" onclick={handleDetectBrowsers} disabled={isLoading}>
        🔍 Detect Browsers
      </Button>
      <Button variant="primary" size="md" onclick={openAddModal}>
        + Add Browser
      </Button>
      <Button variant="secondary" size="md" onclick={handleExportBrowsers}>
        ⬇️ Export
      </Button>
      <Button variant="secondary" size="md" onclick={handleImportBrowsers}>
        ⬆️ Import
      </Button>
    </div>
  </div>

  <!-- Content -->
  <div class="content">
    {#if browsers.length === 0}
      <!-- Empty state -->
      <div class="empty-state">
        <div class="empty-icon">🖥️</div>
        <h3>No browsers configured</h3>
        <p>Click "Detect Browsers" to find installed browsers or "Add Browser" to configure one manually.</p>
        <div class="empty-actions">
          <Button variant="primary" size="md" onclick={handleDetectBrowsers}>
            Detect Browsers
          </Button>
          <Button variant="secondary" size="md" onclick={openAddModal}>
            Add Browser
          </Button>
        </div>
      </div>
    {:else}
      <!-- Browsers list with drag-to-reorder -->
      <div class="browsers-list">
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragEnd={handleDragEnd}
        >
          <SortableContext items={browsers.map((b) => b.id)} strategy={verticalListSortingStrategy}>
            {#each browsers as browser (browser.id)}
              <SortableBrowserRow
                {browser}
                onUpdate={(updates) => handleRowUpdate(browser.id, updates)}
                onDelete={() => handleRowDelete(browser.id)}
              />
            {/each}
          </SortableContext>
        </DndContext>
      </div>
    {/if}
  </div>

  <!-- Add Browser Modal -->
  <Modal isOpen={isAddModalOpen} onClose={() => isAddModalOpen = false} title="Add Browser">
    <div class="modal-form">
      <Input
        label="Browser Name"
        placeholder="e.g., Chrome Work"
        value={formName}
        oninput={(v) => (formName = v)}
      />

      <Input
        label="App ID / Bundle ID"
        placeholder="e.g., com.google.Chrome"
        value={formAppId}
        oninput={(v) => (formAppId = v)}
      />

      <Input
        label="Shortcut Key (1-9)"
        placeholder="1-9"
        value={formShortcutKey}
        oninput={(v) => {
          const sanitized = v.replace(/[^1-9]/g, '').slice(0, 1);
          formShortcutKey = sanitized;
        }}
      />

      <Input
        label="Profile (Optional)"
        placeholder="e.g., Profile 1"
        value={formProfile}
        oninput={(v) => (formProfile = v)}
      />

      <Input
        label="Custom Arguments (Optional)"
        placeholder="e.g., --new-window"
        value={formCustomArgs}
        oninput={(v) => (formCustomArgs = v)}
      />

      <div class="modal-actions">
        <Button variant="secondary" size="md" onclick={() => isAddModalOpen = false}>
          Cancel
        </Button>
        <Button
          variant="primary"
          size="md"
          onclick={handleAddBrowser}
          disabled={!formName.trim() || !formAppId.trim()}
        >
          Add
        </Button>
      </div>
    </div>
  </Modal>

  <!-- Edit Browser Modal -->
  <Modal isOpen={isEditModalOpen} onClose={() => isEditModalOpen = false} title="Edit Browser">
    <div class="modal-form">
      <Input
        label="Browser Name"
        placeholder="e.g., Chrome Work"
        value={formName}
        oninput={(v) => (formName = v)}
      />

      <Input
        label="App ID / Bundle ID"
        placeholder="e.g., com.google.Chrome"
        value={formAppId}
        oninput={(v) => (formAppId = v)}
      />

      <Input
        label="Shortcut Key (1-9)"
        placeholder="1-9"
        value={formShortcutKey}
        oninput={(v) => {
          const sanitized = v.replace(/[^1-9]/g, '').slice(0, 1);
          formShortcutKey = sanitized;
        }}
      />

      <Input
        label="Profile (Optional)"
        placeholder="e.g., Profile 1"
        value={formProfile}
        oninput={(v) => (formProfile = v)}
      />

      <Input
        label="Custom Arguments (Optional)"
        placeholder="e.g., --new-window"
        value={formCustomArgs}
        oninput={(v) => (formCustomArgs = v)}
      />

      <div class="modal-actions">
        <Button variant="secondary" size="md" onclick={() => isEditModalOpen = false}>
          Cancel
        </Button>
        <Button
          variant="primary"
          size="md"
          onclick={handleUpdateBrowser}
          disabled={!formName.trim() || !formAppId.trim()}
        >
          Update
        </Button>
      </div>
    </div>
  </Modal>

   <!-- Delete Confirmation Modal -->
  <Modal isOpen={isDeleteConfirmOpen} onClose={() => isDeleteConfirmOpen = false} title="Delete Browser?">
    <div class="delete-confirm">
      <p>Are you sure you want to delete this browser? This action cannot be undone.</p>
      <div class="modal-actions">
        <Button variant="secondary" size="md" onclick={() => isDeleteConfirmOpen = false}>
          Cancel
        </Button>
        <Button variant="primary" size="md" onclick={handleConfirmDelete}>
          Delete
        </Button>
      </div>
    </div>
  </Modal>
</div>

<style>
  .browsers-tab {
    display: flex;
    flex-direction: column;
    height: 100%;
    gap: var(--spacing-4);
  }

  .toolbar {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: var(--spacing-4);
    padding-bottom: var(--spacing-4);
    border-bottom: 1px solid var(--color-separator);
  }

  .toolbar-title h2 {
    margin: 0;
    font-size: var(--font-size-lg);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
  }

  .toolbar-title p {
    margin: var(--spacing-2) 0 0 0;
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
  }

  .toolbar-actions {
    display: flex;
    gap: var(--spacing-3);
    flex-shrink: 0;
  }

  .content {
    flex: 1;
    overflow-y: auto;
  }

  .browsers-list {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--spacing-4);
    padding: var(--spacing-8);
    text-align: center;
    color: var(--color-text-secondary);
  }

  .empty-icon {
    font-size: 48px;
    opacity: 0.6;
  }

  .empty-state h3 {
    margin: 0;
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text-primary);
  }

  .empty-state p {
    margin: 0;
    max-width: 300px;
    font-size: var(--font-size-sm);
  }

  .empty-actions {
    display: flex;
    gap: var(--spacing-3);
  }

  .modal-form {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-4);
  }

  .modal-actions {
    display: flex;
    gap: var(--spacing-3);
    justify-content: flex-end;
    margin-top: var(--spacing-4);
    padding-top: var(--spacing-4);
    border-top: 1px solid var(--color-separator);
  }

  .delete-confirm {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-4);
  }

  .delete-confirm p {
    margin: 0;
    color: var(--color-text-primary);
    font-size: var(--font-size-base);
  }

  .toast {
    position: fixed;
    bottom: 16px;
    right: 16px;
    padding: 12px 16px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    gap: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    animation: slideIn 0.3s ease-out;
    z-index: 1000;
  }

  .toast-success {
    background-color: #10b981;
    color: white;
  }

  .toast-error {
    background-color: #ef4444;
    color: white;
  }

  .toast-icon {
    font-weight: bold;
    font-size: 16px;
  }

  .toast-message {
    font-size: var(--font-size-sm);
  }

  @keyframes slideIn {
    from {
      transform: translateX(400px);
      opacity: 0;
    }
    to {
      transform: translateX(0);
      opacity: 1;
    }
  }
</style>
