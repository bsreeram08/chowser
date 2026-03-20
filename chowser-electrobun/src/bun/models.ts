// ---------------------------------------------------------------------------
// Chowser data models
// ---------------------------------------------------------------------------

export const APP_VERSION = 1;
export const DOMAIN_SUGGESTION_THRESHOLD = 30;
export const DOMAIN_MAX_ENTRIES = 100;
export const RECENT_URLS_MAX = 100;
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

/** Apps that handle URLs but are not browsers (media players, etc.) */
export const DEFAULT_HIDDEN_APP_IDS: string[] = [
  "com.colliderli.iina",
  "org.videolan.vlc",
  "io.mpv",
  "com.apple.QuickTimePlayerX",
  "net.mxvideoplayer.mac.MX-Video-Player-Pro",
  "com.apple.TV",
  "com.apple.Music",
];

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
// Recent URLs
// ---------------------------------------------------------------------------

export interface RecentUrl {
  url: string;
  /** Browser appId that was used, or null if dismissed */
  browserId: string | null;
  timestamp: number;
}

// ---------------------------------------------------------------------------
// Picker layout preference
// ---------------------------------------------------------------------------

export type PickerLayout = "icons" | "list";

// ---------------------------------------------------------------------------
// Focus mode — temporary browser override
// ---------------------------------------------------------------------------

export interface FocusMode {
  /** Browser ID (BrowserConfig.id) to use during focus session */
  browserId: string;
  /** Unix timestamp (ms) when focus mode expires, or null for session-only */
  expiresAt: number | null;
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
  recentUrls: RecentUrl[];
  pickerLayout: PickerLayout;
  launchAtLogin: boolean;
  focusMode: FocusMode | null;
}

export function createDefaultState(): PersistedState {
  return {
    version: APP_VERSION,
    hasCompletedOnboarding: false,
    configuredBrowsers: defaultBrowsers(),
    routingRules: [],
    hiddenAppIds: [...DEFAULT_HIDDEN_APP_IDS],
    domainFrequency: {},
    recentUrls: [],
    pickerLayout: "icons",
    launchAtLogin: false,
    focusMode: null,
  };
}

function defaultBrowsers(): BrowserConfig[] {
  // Seed with the platform's most common built-in browser so users have
  // something visible on first launch on every OS.
  switch (process.platform) {
    case "win32":
      return [
        {
          id: crypto.randomUUID(),
          name: "Microsoft Edge",
          appId: "com.microsoft.edgemac",
          shortcutKey: "1",
        },
      ];
    case "linux":
      return [
        {
          id: crypto.randomUUID(),
          name: "Firefox",
          appId: "org.mozilla.firefox",
          shortcutKey: "1",
        },
      ];
    default: // darwin
      return [
        {
          id: crypto.randomUUID(),
          name: "Safari",
          appId: "com.apple.Safari",
          shortcutKey: "1",
        },
      ];
  }
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
