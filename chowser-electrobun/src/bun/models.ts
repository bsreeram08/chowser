// ---------------------------------------------------------------------------
// Chowser data models
// ---------------------------------------------------------------------------

export const APP_VERSION = 1;
export const DOMAIN_SUGGESTION_THRESHOLD = 30;
export const DOMAIN_MAX_ENTRIES = 100;
export const SUPPORTED_SHORTCUTS = [
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
] as const;

// ---------------------------------------------------------------------------
// Browser configuration
// ---------------------------------------------------------------------------

/**
 * A configured browser entry.  The `appId` is the macOS bundle ID (e.g.
 * "com.google.Chrome").  `executable` is an optional path override — when
 * omitted the system resolves the app by bundle ID.
 */
export interface BrowserConfig {
  id: string;
  name: string;
  /** macOS bundle ID, e.g. "com.google.Chrome" */
  appId: string;
  /** Single-key shortcut ("1"–"9") for the picker */
  shortcutKey: string;
  /** Chrome/Brave/Edge/Vivaldi profile directory name, e.g. "Default" or "Profile 1" */
  profile?: string;
  /** Extra CLI arguments appended when launching */
  customArguments?: string;
}

// ---------------------------------------------------------------------------
// Routing rule
// ---------------------------------------------------------------------------

export interface BrowserRoutingRule {
  id: string;
  name: string;
  /** Glob or regex pattern matched against the URL host */
  hostPattern: string;
  /** Optional path prefix matched against the URL pathname */
  pathPrefix?: string;
  /** Bundle ID of the browser to open this URL in */
  browserAppId: string;
  /** Optional browser profile name */
  profile?: string;
  /** If set, the rule only matches when the link was opened from this source app */
  sourceAppBundleId?: string;
  isEnabled: boolean;
  usePrivateMode: boolean;
  /** When true, hostPattern is treated as a full JavaScript regular expression */
  useRegex: boolean;
}

// ---------------------------------------------------------------------------
// Domain frequency (auto-rule suggestion)
// ---------------------------------------------------------------------------

export interface DomainFrequency {
  /** domain → { appId → click count } */
  [domain: string]: { [appId: string]: number };
}

export interface DomainSuggestion {
  domain: string;
  appId: string;
  count: number;
}

// ---------------------------------------------------------------------------
// Persisted application state
// ---------------------------------------------------------------------------

export interface PersistedState {
  version: number;
  hasCompletedOnboarding: boolean;
  configuredBrowsers: BrowserConfig[];
  routingRules: BrowserRoutingRule[];
  hiddenAppIds: string[];
  domainFrequency: DomainFrequency;
}

export function createDefaultState(): PersistedState {
  return {
    version: APP_VERSION,
    hasCompletedOnboarding: false,
    configuredBrowsers: defaultBrowsers(),
    routingRules: [],
    hiddenAppIds: [],
    domainFrequency: {},
  };
}

function defaultBrowsers(): BrowserConfig[] {
  return [
    {
      id: crypto.randomUUID(),
      name: "Safari",
      appId: "com.apple.Safari",
      shortcutKey: "1",
    },
  ];
}

// ---------------------------------------------------------------------------
// Installed browser detected at runtime
// ---------------------------------------------------------------------------

export interface InstalledBrowser {
  name: string;
  appId: string;
  path: string;
  profiles: BrowserProfile[];
}

export interface BrowserProfile {
  name: string;
  directory: string;
}

// ---------------------------------------------------------------------------
// Route resolution result
// ---------------------------------------------------------------------------

export interface ResolvedRoute {
  browserAppId: string;
  profile?: string;
  usePrivateMode: boolean;
  matchedRuleId?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

export function nextAvailableShortcut(
  browsers: BrowserConfig[]
): (typeof SUPPORTED_SHORTCUTS)[number] {
  const used = new Set(browsers.map((b) => b.shortcutKey));
  for (const key of SUPPORTED_SHORTCUTS) {
    if (!used.has(key)) return key;
  }
  return "9";
}

export function normalizeShortcut(
  input: string
): (typeof SUPPORTED_SHORTCUTS)[number] | null {
  const trimmed = input.trim() as (typeof SUPPORTED_SHORTCUTS)[number];
  return (SUPPORTED_SHORTCUTS as readonly string[]).includes(trimmed)
    ? trimmed
    : null;
}
