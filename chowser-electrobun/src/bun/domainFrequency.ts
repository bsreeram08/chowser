// ---------------------------------------------------------------------------
// Domain frequency tracking — suggestion logic for the picker banner
//
// Uses the existing DomainFrequency data persisted in state.json via config.ts.
// This module adds:
//   • getSuggestionForDomain() — checks if a domain qualifies for a suggestion
//     (30+ total clicks AND 60%+ dominance by a single browser)
//   • dismissSuggestion() / isDismissed() — per-session dismiss set
//   • clearDismissed() — reset on app start
// ---------------------------------------------------------------------------

import type { DomainFrequency, BrowserConfig } from "./models.ts";
import { DOMAIN_SUGGESTION_THRESHOLD } from "./models.ts";

const DOMINANCE_RATIO = 0.6;

const _dismissed = new Set<string>();

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export interface PickerSuggestion {
  domain: string;
  browserId: string;
  browserName: string;
  count: number;
}

/**
 * Check whether `domain` qualifies for a suggestion banner in the picker.
 *
 * Criteria (matching macOS Swift reference):
 *   1. Total clicks for the domain ≥ DOMAIN_SUGGESTION_THRESHOLD (30)
 *   2. A single browser (by appId) accounts for ≥ 60 % of those clicks
 *   3. The domain has not been dismissed this session
 *   4. No existing routing rule already covers the domain (caller checks)
 *
 * Returns a `PickerSuggestion` with the browser's *configured* id + name,
 * or `null` if no suggestion applies.
 */
export function getSuggestionForDomain(
  domain: string,
  frequency: DomainFrequency,
  browsers: BrowserConfig[],
): PickerSuggestion | null {
  const key = domain.trim().toLowerCase();
  if (!key) return null;
  if (_dismissed.has(key)) return null;

  const counts = frequency[key];
  if (!counts) return null;

  let total = 0;
  let topAppId = "";
  let topCount = 0;

  for (const [appId, count] of Object.entries(counts)) {
    total += count;
    if (count > topCount) {
      topCount = count;
      topAppId = appId;
    }
  }

  if (total < DOMAIN_SUGGESTION_THRESHOLD) return null;
  if (topCount / total < DOMINANCE_RATIO) return null;

  const browser = browsers.find((b) => b.appId === topAppId);
  if (!browser) return null;

  return {
    domain: key,
    browserId: browser.id,
    browserName: browser.name,
    count: topCount,
  };
}

export function dismissSuggestion(domain: string): void {
  _dismissed.add(domain.trim().toLowerCase());
}

export function isDismissed(domain: string): boolean {
  return _dismissed.has(domain.trim().toLowerCase());
}

export function clearDismissed(): void {
  _dismissed.clear();
}
