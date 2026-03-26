<script lang="ts">
  import { Electroview } from 'electrobun/view';
  import type { ElectrobunRPCSchema } from 'electrobun/view';
  import SettingsShell from './components/SettingsShell.svelte';
  import BrowsersTab from './tabs/BrowsersTab.svelte';
  import RulesTab from './tabs/RulesTab.svelte';
  import GeneralTab from './tabs/GeneralTab.svelte';
  import HiddenAppsTab from './tabs/HiddenAppsTab.svelte';


  // Settings RPC schema
  interface BrowserConfig {
    id: string;
    name: string;
    appId: string;
    shortcutKey: string;
    profile?: string;
    customArguments?: string;
  }

  interface BrowserRoutingRule {
    id: string;
    name: string;
    hostPattern: string;
    pathPrefix?: string;
    browserAppId: string;
    profile?: string;
    sourceAppBundleId?: string;
    isEnabled: boolean;
    usePrivateMode: boolean;
    useRegex: boolean;
  }

  interface InstalledBrowser {
    name: string;
    appId: string;
    path: string;
    profiles: Array<{ name: string; directory: string }>;
  }

  interface RecentUrl {
    url: string;
    browserId: string | null;
    timestamp: number;
  }

  interface FocusMode {
    browserId: string;
    expiresAt: number | null;
  }

  interface McpStatus {
    isRunning: boolean;
    port: number;
    authToken: string;
  }

  type PickerLayout = 'icons' | 'list';

  type SettingsSchema = ElectrobunRPCSchema & {
    bun: {
      requests: {
        getState: {
          params: undefined;
          response: {
            browsers: BrowserConfig[];
            rules: BrowserRoutingRule[];
            installedBrowsers: InstalledBrowser[];
            hasCompletedOnboarding: boolean;
            hiddenAppIds: string[];
            recentUrls: RecentUrl[];
            pickerLayout: PickerLayout;
            launchAtLogin: boolean;
            focusMode: FocusMode | null;
            mcpStatus: McpStatus;
          };
        };
        setPickerLayout: { params: { layout: PickerLayout }; response: void };
        setLaunchAtLogin: { params: { enabled: boolean }; response: void };
        toggleMcpServer: { params: undefined; response: McpStatus };
        openDefaultBrowserSettings: { params: undefined; response: void };
        resetToDefaults: { params: undefined; response: void };
      };
      messages: Record<string, never>;
    };
    webview: {
      requests: Record<string, never>;
      messages: Record<string, never>;
    };
  };

  let activeTab = $state('General');
  
  const rpc = Electroview.defineRPC<SettingsSchema>({
    handlers: {
      messages: {},
    },
  });

  new Electroview({ rpc });

  function handleTabChange(tab: string) {
    activeTab = tab;
  }
</script>

<SettingsShell {activeTab} onTabChange={handleTabChange}>
  {#if activeTab === 'Browsers'}
    <BrowsersTab {rpc} />
  {:else if activeTab === 'Rules'}
    <RulesTab {rpc} />
  {:else if activeTab === 'General'}
    <GeneralTab {rpc} />
  {:else if activeTab === 'Hidden Apps'}
    <HiddenAppsTab {rpc} />
  {/if}
</SettingsShell>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    background: var(--color-background);
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif;
    color: var(--color-text-primary);
    --color-background: #1c1c1e;
    --color-surface: #242426;
    --color-control-background: #2c2c2e;
    --color-background-secondary: #3a3a3c;
    --color-background-tertiary: #454547;
    --color-border: #3a3a3c;
    --color-separator: #545456;
    --color-control-border: #545456;
    --color-text-primary: rgba(255, 255, 255, 0.87);
    --color-text-secondary: rgba(255, 255, 255, 0.6);
    --color-text-tertiary: rgba(255, 255, 255, 0.4);
    --color-accent: #0066ff;
    --color-accent-hover: #0052cc;
    --color-accent-pressed: #0040a6;
    --color-error: #ff3b30;
    --color-glass-light: rgba(255, 255, 255, 0.1);
    --font-family-system: -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif;
    --font-size-xs: 12px;
    --font-size-sm: 13px;
    --font-size-base: 14px;
    --font-size-lg: 16px;
    --font-weight-medium: 500;
    --font-weight-semibold: 600;
    --spacing-1: 4px;
    --spacing-2: 8px;
    --spacing-3: 12px;
    --spacing-4: 16px;
    --spacing-6: 24px;
    --spacing-8: 32px;
    --radius-default: 6px;
    --radius-md: 8px;
  }
</style>
