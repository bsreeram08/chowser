// ---------------------------------------------------------------------------
// URL routing engine — mirrors Chowser Swift routing logic in TypeScript
// ---------------------------------------------------------------------------

import type {
  BrowserConfig,
  BrowserRoutingRule,
  ResolvedRoute,
} from "./models.ts";

/**
 * Walk rules top-to-bottom and return the first match, or null if none match.
 *
 * Rules are matched on:
 *   1. isEnabled must be true
 *   2. hostPattern (glob wildcard or regex) must match the URL host
 *   3. pathPrefix (if set) must be a prefix of the URL pathname
 *   4. sourceAppBundleId (if set) must equal the opening app's bundle ID
 */
export function resolveRoute(
  url: string,
  rules: BrowserRoutingRule[],
  sourceAppBundleId?: string
): ResolvedRoute | null {
  let parsedUrl: URL;
  try {
    parsedUrl = new URL(url);
  } catch {
    return null;
  }

  const host = parsedUrl.hostname;
  const pathname = parsedUrl.pathname;

  for (const rule of rules) {
    if (!rule.isEnabled) continue;
    if (!matchesHost(host, rule.hostPattern, rule.useRegex)) continue;
    if (
      rule.pathPrefix &&
      !pathname.toLowerCase().startsWith(rule.pathPrefix.toLowerCase())
    )
      continue;
    if (
      rule.sourceAppBundleId &&
      rule.sourceAppBundleId !== sourceAppBundleId
    )
      continue;

    return {
      browserAppId: rule.browserAppId,
      profile: rule.profile,
      usePrivateMode: rule.usePrivateMode,
      matchedRuleId: rule.id,
    };
  }

  return null;
}

// ---------------------------------------------------------------------------
// Host pattern matching
// ---------------------------------------------------------------------------

function matchesHost(
  host: string,
  pattern: string,
  useRegex: boolean
): boolean {
  if (!pattern || pattern === "*") return true;

  if (useRegex) {
    try {
      return new RegExp(`^(?:${pattern})$`, "i").test(host);
    } catch {
      return false;
    }
  }

  // Glob-style wildcard matching
  return globMatch(pattern.toLowerCase(), host.toLowerCase());
}

/**
 * Simple glob matcher supporting `*` (any sequence, no dots) and
 * `**` (any sequence including dots).
 *
 * Examples:
 *   "*.github.com"      matches  "docs.github.com"
 *   "**.google.com"     matches  "mail.google.com"
 *   "github.com"        matches  "github.com" exactly
 */
function globMatch(pattern: string, input: string): boolean {
  // Convert glob to regex
  const regexStr = pattern
    .split("**")
    .map((part) =>
      part
        .split("*")
        .map((s) => escapeRegex(s))
        .join("[^.]*")
    )
    .join(".*");

  try {
    return new RegExp(`^${regexStr}$`).test(input);
  } catch {
    return pattern === input;
  }
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// ---------------------------------------------------------------------------
// Domain frequency tracking
// ---------------------------------------------------------------------------

import type { DomainFrequency, DomainSuggestion } from "./models.ts";
import {
  DOMAIN_MAX_ENTRIES,
  DOMAIN_SUGGESTION_THRESHOLD,
} from "./models.ts";

/** Record a click and return updated frequency map. */
export function recordDomainClick(
  frequency: DomainFrequency,
  domain: string,
  appId: string
): DomainFrequency {
  const updated = { ...frequency };
  const key = domain.trim().toLowerCase();
  const app = appId.trim();
  if (!key || !app) return updated;

  if (!updated[key]) updated[key] = {};
  updated[key] = { ...updated[key], [app]: (updated[key]![app] ?? 0) + 1 };

  // Evict oldest entry if over limit
  const keys = Object.keys(updated);
  if (keys.length > DOMAIN_MAX_ENTRIES) {
    keys.sort();
    delete updated[keys[0]!];
  }

  return updated;
}

/** Return domains/app pairs that exceed the suggestion threshold. */
export function getSuggestions(
  frequency: DomainFrequency,
  threshold = DOMAIN_SUGGESTION_THRESHOLD
): DomainSuggestion[] {
  const suggestions: DomainSuggestion[] = [];

  for (const [domain, counts] of Object.entries(frequency)) {
    for (const [appId, count] of Object.entries(counts)) {
      if (count >= threshold) {
        suggestions.push({ domain, appId, count });
      }
    }
  }

  return suggestions.sort(
    (a, b) =>
      b.count - a.count ||
      a.domain.localeCompare(b.domain) ||
      a.appId.localeCompare(b.appId)
  );
}

// ---------------------------------------------------------------------------
// Rule utilities
// ---------------------------------------------------------------------------

/** Return a human-readable description of a rule. */
export function ruleDescription(rule: BrowserRoutingRule): string {
  const parts: string[] = [];
  parts.push(`host: ${rule.hostPattern}`);
  if (rule.pathPrefix) parts.push(`path: ${rule.pathPrefix}`);
  if (rule.sourceAppBundleId)
    parts.push(`from: ${rule.sourceAppBundleId}`);
  return parts.join(", ");
}
