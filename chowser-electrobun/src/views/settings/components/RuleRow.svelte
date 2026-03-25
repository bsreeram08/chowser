<script lang="ts">
  import Toggle from '../../shared/components/Toggle.svelte';
  import Button from '../../shared/components/Button.svelte';

  interface RuleRowProps {
    rule: {
      id: string;
      name: string;
      hostPattern: string;
      browserName: string;
      isEnabled: boolean;
    };
    onToggle: (ruleId: string, enabled: boolean) => void;
    onEdit: (ruleId: string) => void;
    onDuplicate: (ruleId: string) => void;
    onDelete: (ruleId: string) => void;
  }

  let { rule, onToggle, onEdit, onDuplicate, onDelete } = $props<RuleRowProps>();

  const truncatePattern = (pattern: string, maxLen: number = 40) => {
    if (pattern.length > maxLen) {
      return pattern.substring(0, maxLen) + '…';
    }
    return pattern;
  };
</script>

<div class="rule-row">
  <!-- Toggle -->
  <div class="toggle-col">
    <Toggle
      checked={rule.isEnabled}
      onchange={(enabled) => onToggle(rule.id, enabled)}
    />
  </div>

  <!-- Name and Pattern -->
  <div class="info-col">
    <div class="rule-name">{rule.name}</div>
    <div class="rule-pattern" title={rule.hostPattern}>
      {truncatePattern(rule.hostPattern)}
    </div>
  </div>

  <!-- Browser Name -->
  <div class="browser-col">
    <span class="browser-name">{rule.browserName}</span>
  </div>

  <!-- Action Buttons -->
  <div class="actions-col">
    <Button
      variant="ghost"
      size="sm"
      onclick={() => onEdit(rule.id)}
      title="Edit rule"
    >
      ✏️
    </Button>
    <Button
      variant="ghost"
      size="sm"
      onclick={() => onDuplicate(rule.id)}
      title="Duplicate rule"
    >
      📋
    </Button>
    <Button
      variant="ghost"
      size="sm"
      onclick={() => onDelete(rule.id)}
      title="Delete rule"
    >
      🗑️
    </Button>
  </div>
</div>

<style>
  .rule-row {
    display: grid;
    grid-template-columns: 44px 1fr auto auto;
    align-items: center;
    gap: var(--spacing-3);
    height: 60px;
    padding: var(--spacing-3);
    border-bottom: 1px solid var(--color-separator);
    background-color: var(--color-background);
    transition: background-color 0.2s ease;
  }

  .rule-row:hover {
    background-color: var(--color-background-secondary);
  }

  .toggle-col {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .info-col {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-1);
    min-width: 0;
  }

  .rule-name {
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-medium);
    color: var(--color-text-primary);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .rule-pattern {
    font-size: var(--font-size-xs);
    font-family: var(--font-family-mono);
    color: var(--color-text-secondary);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .browser-col {
    min-width: 120px;
  }

  .browser-name {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
  }

  .actions-col {
    display: flex;
    gap: var(--spacing-2);
    align-items: center;
  }
</style>
