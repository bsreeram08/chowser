<script lang="ts">
  import { Electroview } from 'electrobun/view';
  import type { ElectrobunRPCSchema } from 'electrobun/view';
  import IconsLayout from './layouts/IconsLayout.svelte';
  import ListLayout from './layouts/ListLayout.svelte';
  import UrlBubble from './components/UrlBubble.svelte';
  import PickerShell from './components/PickerShell.svelte';
  import QuickRuleSheet from './components/QuickRuleSheet.svelte';
  import FocusStatusBanner from './components/FocusStatusBanner.svelte';
  import SuggestionBanner from './components/SuggestionBanner.svelte';

  // ---------------------------------------------------------------------------
  // RPC schema (mirrors PickerSchema in src/bun/index.ts)
  // ---------------------------------------------------------------------------

  interface BrowserConfig {
    id: string;
    name: string;
    appId: string;
    shortcutKey: string;
    profile?: string;
    customArguments?: string;
  }

  interface FocusMode {
    browserAppId: string;
    expiresAt: number | null;
  }

  type PickerSchema = ElectrobunRPCSchema & {
    bun: {
      requests: {
        getPickerData: {
          params: undefined;
          response: {
            url: string;
            browsers: BrowserConfig[];
            suggestedRuleHostPattern: string;
            focusMode: FocusMode | null;
          };
        };
        openInBrowser: {
          params: { browserId: string; usePrivateMode: boolean };
          response: void;
        };
        dismissPicker: { params: undefined; response: void };
        createRule: {
          params: {
            name: string;
            hostPattern: string;
            browserAppId: string;
         usePrivateMode: boolean;
           };
           response: void;
         };
         unshortenUrl: {
           params: { url: string };
           response: { url: string; error?: string };
         };
         getSuggestion: {
           params: undefined;
           response: { domain: string; browserId: string; browserName: string } | null;
         };
         dismissSuggestion: {
           params: { domain: string };
           response: void;
         };
       };
       messages: Record<string, never>;
    };
    webview: {
      requests: Record<string, never>;
      messages: {
        refreshPicker: undefined;
      };
    };
  };

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  let url = $state('');
  let browsers = $state<BrowserConfig[]>([]);
  let isPrivateMode = $state(false);
  let showQuickRuleSheet = $state(false);
  let selectedBrowserId = $state<string | null>(null);
  let isUnshortening = $state(false);
  let unshortenError = $state<string | null>(null);
  let isLoaded = $state(false);
  let focusMode = $state<FocusMode | null>(null);
  let focusCountdown = $state<string | null>(null);
  let suggestion = $state<{ domain: string; browserId: string; browserName: string } | null>(null);
  let prefillBrowserId = $state<string | null>(null);

  // Layout mode — defaults to 'icons'; can be extended later from settings
  let layoutMode = $state<'icons' | 'list'>('icons');

  // ---------------------------------------------------------------------------
  // Electrobun RPC setup
  // ---------------------------------------------------------------------------

  const rpc = Electroview.defineRPC<PickerSchema>({
    handlers: {
      messages: {
        refreshPicker: () => {
          loadPickerData();
        },
      },
    },
  });

  const electroview = new Electroview({ rpc });

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  async function loadPickerData() {
    try {
      const data = await rpc.request('getPickerData', undefined);
      url = data.url;
      browsers = data.browsers;
      focusMode = data.focusMode;

      // Select the first browser by default if none selected
      if (!selectedBrowserId && browsers.length > 0) {
        selectedBrowserId = browsers[0].id;
      }

      isLoaded = true;
      updateFocusCountdown();

      try {
        suggestion = await rpc.request('getSuggestion', undefined);
      } catch {
        suggestion = null;
      }
    } catch (err) {
      console.error('[picker] Failed to load picker data:', err);
    }
  }

  // Load on mount
  $effect(() => {
    loadPickerData();
  });

  // ---------------------------------------------------------------------------
  // Focus mode countdown timer
  // ---------------------------------------------------------------------------

  function updateFocusCountdown() {
    if (!focusMode || focusMode.expiresAt === null) {
      focusCountdown = null;
      return;
    }

    const remaining = focusMode.expiresAt - Date.now();
    if (remaining <= 0) {
      focusCountdown = null;
      focusMode = null;
      return;
    }

    const mins = Math.ceil(remaining / 60000);
    if (mins <= 1) {
      focusCountdown = '< 1 min';
    } else if (mins < 60) {
      focusCountdown = `${mins}m`;
    } else {
      const hours = (remaining / 3600000).toFixed(1);
      focusCountdown = `${hours}h`;
    }
  }

  // Update countdown every minute (or more frequently if < 5 min remaining)
  $effect(() => {
    if (!focusMode || focusMode.expiresAt === null) return;

    const remaining = focusMode.expiresAt - Date.now();
    const interval = remaining < 300000 ? 1000 : 60000; // 1s if < 5 min, else 1 min

    const timer = setInterval(() => {
      updateFocusCountdown();
    }, interval);

    return () => clearInterval(timer);
  });

  // ---------------------------------------------------------------------------
  // Browser launching
  // ---------------------------------------------------------------------------

  async function launchBrowser(browserId: string, usePrivate: boolean) {
    try {
      await rpc.request('openInBrowser', { browserId, usePrivateMode: usePrivate });
    } catch (err) {
      console.error('[picker] Failed to open browser:', err);
    }
  }

  // ---------------------------------------------------------------------------
  // Keyboard handling (top-level — does NOT duplicate arrow key logic)
  // Arrow keys are handled by IconsLayout (left/right) and ListLayout (up/down)
  // ---------------------------------------------------------------------------

  function handleKeydown(e: KeyboardEvent) {
    // Skip if QuickRuleSheet is open — let the modal handle its own keys
    if (showQuickRuleSheet) return;

    // Option+Enter: open selected browser in private mode (check before plain Enter)
    if (e.key === 'Enter' && e.altKey) {
      if (selectedBrowserId) {
        e.preventDefault();
        launchBrowser(selectedBrowserId, true);
      }
      return;
    }

    // Number keys 1-9: directly open browser with matching shortcut
    if (e.key >= '1' && e.key <= '9') {
      const browser = browsers.find(b => b.shortcutKey === e.key);
      if (browser) {
        e.preventDefault();
        launchBrowser(browser.id, isPrivateMode);
      }
      return;
    }

    // Enter or Space: open selected browser
    if (e.key === 'Enter' || e.key === ' ') {
      if (selectedBrowserId) {
        e.preventDefault();
        launchBrowser(selectedBrowserId, isPrivateMode);
      }
      return;
    }

    // Escape: dismiss picker
    if (e.key === 'Escape') {
      e.preventDefault();
      rpc.request('dismissPicker', undefined).catch(() => {});
      return;
    }

    // P: toggle private mode
    if (e.key === 'p' || e.key === 'P') {
      e.preventDefault();
      isPrivateMode = !isPrivateMode;
      return;
    }

    // H or S: trigger URL unshorten
    if (e.key === 'h' || e.key === 'H' || e.key === 's' || e.key === 'S') {
      if (url && !isUnshortening) {
        e.preventDefault();
        handleUnshorten();
      }
      return;
    }

    // R: open quick rule creation modal
    if (e.key === 'r' || e.key === 'R') {
      if (url) {
        e.preventDefault();
        showQuickRuleSheet = true;
      }
      return;
    }

    // Tab / Shift-Tab: cycle selection through browsers
    if (e.key === 'Tab') {
      e.preventDefault();
      if (browsers.length === 0) return;
      const currentIndex = browsers.findIndex(b => b.id === selectedBrowserId);
      const nextIndex = e.shiftKey
        ? (currentIndex <= 0 ? browsers.length - 1 : currentIndex - 1)
        : (currentIndex + 1) % browsers.length;
      selectedBrowserId = browsers[nextIndex]?.id ?? null;
      return;
    }

    // Letter keys: select first browser whose name starts with that letter
    if (e.key.length === 1 && /[a-zA-Z]/.test(e.key)) {
      const letter = e.key.toLowerCase();
      const browser = browsers.find(b => b.name.toLowerCase().startsWith(letter));
      if (browser) {
        e.preventDefault();
        selectedBrowserId = browser.id;
      }
      return;
    }
  }

  // ---------------------------------------------------------------------------
  // URL unshorten handler
  // ---------------------------------------------------------------------------

  async function handleUnshorten() {
    if (isUnshortening || !url) return;
    isUnshortening = true;
    unshortenError = null;
    try {
      const response = await rpc.request('unshortenUrl', { url });
      if (response.error) {
        unshortenError = response.error;
      } else if (response.url && response.url !== url) {
        url = response.url;
        unshortenError = null;
      }
    } catch (err) {
      unshortenError = (err as Error).message || 'Failed to unshorten URL';
      console.error('[picker] Unshorten failed:', err);
    } finally {
      isUnshortening = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Selection handler (passed to layouts)
  // ---------------------------------------------------------------------------

  function handleSelect(browser: BrowserConfig) {
    selectedBrowserId = browser.id;
  }

  // ---------------------------------------------------------------------------
  // Quick rule sheet handlers
  // ---------------------------------------------------------------------------

  async function handleRuleSave(rule: {
    host: string;
    browserId: string;
    profile?: string;
    isPrivate: boolean;
  }) {
    const browser = browsers.find(b => b.id === rule.browserId);
    if (!browser) return;

    try {
      await rpc.request('createRule', {
        name: `${rule.host} → ${browser.name}`,
        hostPattern: rule.host,
        browserAppId: browser.appId,
        usePrivateMode: rule.isPrivate,
      });
    } catch (err) {
      console.error('[picker] Failed to create rule:', err);
    }

    showQuickRuleSheet = false;
    prefillBrowserId = null;
  }

  function handleRuleCancel() {
    showQuickRuleSheet = false;
    prefillBrowserId = null;
  }

  function handleSuggestionAccept() {
    if (!suggestion) return;
    prefillBrowserId = suggestion.browserId;
    showQuickRuleSheet = true;
    suggestion = null;
  }

  async function handleSuggestionDismiss() {
    if (!suggestion) return;
    try {
      await rpc.request('dismissSuggestion', { domain: suggestion.domain });
    } catch {}
    suggestion = null;
  }

  // ---------------------------------------------------------------------------
  // Register keyboard listener
  // ---------------------------------------------------------------------------

  $effect(() => {
    window.addEventListener('keydown', handleKeydown);
    return () => {
      window.removeEventListener('keydown', handleKeydown);
    };
  });
</script>

{#if isLoaded}
  <PickerShell>
    {#snippet url()}
      {#if suggestion}
        <SuggestionBanner
          domain={suggestion.domain}
          browserName={suggestion.browserName}
          onAccept={handleSuggestionAccept}
          onDismiss={handleSuggestionDismiss}
        />
      {/if}
      {#if focusMode}
        {#if focusMode.expiresAt === null || focusMode.expiresAt > Date.now()}
          {@const focusBrowser = browsers.find(b => b.id === focusMode.browserId)}
          <FocusStatusBanner
            browserName={focusBrowser?.name ?? 'Unknown'}
            countdown={focusCountdown}
          />
        {/if}
      {/if}
      <UrlBubble
        {url}
        {isUnshortening}
        {unshortenError}
        onUnshorten={handleUnshorten}
      />
    {/snippet}

    {#if layoutMode === 'icons'}
      <IconsLayout
        {browsers}
        {selectedBrowserId}
        onSelect={handleSelect}
      />
    {:else}
      <ListLayout
        {browsers}
        {selectedBrowserId}
        onSelect={handleSelect}
      />
    {/if}
  </PickerShell>

  {#if showQuickRuleSheet}
    <QuickRuleSheet
      isOpen={showQuickRuleSheet}
      {url}
      browsers={browsers.map(b => ({ id: b.id, name: b.name, appId: b.appId }))}
      {prefillBrowserId}
      onSave={handleRuleSave}
      onCancel={handleRuleCancel}
    />
  {/if}
{:else}
  <div class="loading-state" aria-label="Loading browser picker..."></div>
{/if}

<style>
  @import '../shared/tokens.css';

  :global(body) {
    margin: 0;
    padding: 0;
    background: transparent;
    font-family: var(--font-family-system);
    color: var(--color-text-primary);
    overflow: hidden;
    user-select: none;
  }

  :global(*, *::before, *::after) {
    box-sizing: border-box;
  }

  .loading-state {
    width: 400px;
    height: 120px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: transparent;
  }
</style>
