<script lang="ts">
  import { useSortable } from '@dnd-kit/sortable';
  import { CSS } from '@dnd-kit/utilities';
  import BrowserConfigRow from '../components/BrowserConfigRow.svelte';

  interface BrowserConfig {
    id: string;
    name: string;
    appId: string;
    shortcutKey: string;
    profile?: string;
    customArguments?: string;
  }

  interface Props {
    browser: BrowserConfig;
    onUpdate: (updates: Partial<BrowserConfig>) => void;
    onDelete: () => void;
  }

  const { browser, onUpdate, onDelete } = $props<Props>();

  const { attributes, isDragging, listeners, setNodeRef, transform, transition } = useSortable({
    id: browser.id,
  });

  const style = CSS.transform.toString(transform);
</script>

<div
  ref={setNodeRef}
  {style}
  {transition}
  class="sortable-browser-row"
  class:dragging={isDragging}
  {...attributes}
  {...listeners}
>
  <BrowserConfigRow {browser} {onUpdate} {onDelete} />
</div>

<style>
  .sortable-browser-row {
    transition: opacity 0.2s ease;
  }

  .sortable-browser-row.dragging {
    opacity: 0.5;
  }
</style>
