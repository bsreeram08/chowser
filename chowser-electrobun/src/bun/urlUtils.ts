// ---------------------------------------------------------------------------
// URL utilities — cleaning and unshortening
// ---------------------------------------------------------------------------

/** Tracking query parameters to strip from URLs */
const TRACKING_PARAMS = new Set([
  // UTM
  "utm_source",
  "utm_medium",
  "utm_campaign",
  "utm_term",
  "utm_content",
  "utm_id",
  "utm_reader",
  "utm_referral",
  "utm_name",
  // Facebook
  "fbclid",
  "fb_action_ids",
  "fb_action_types",
  "fb_source",
  "fb_ref",
  // Google
  "gclid",
  "gbraid",
  "wbraid",
  "gclsrc",
  "dclid",
  // HubSpot
  "_hsenc",
  "_hsmi",
  "hsCtaTracking",
  // Mailchimp
  "mc_cid",
  "mc_eid",
  // Twitter / X
  "twclid",
  // Microsoft
  "msclkid",
  // Marketo
  "mkt_tok",
  // Misc
  "yclid",
  "ref",
  "igshid",
  "si",
  "spm",
]);

/**
 * Strip known tracking parameters from a URL.
 * Returns the original URL if parsing fails.
 */
export function cleanUrl(url: string): string {
  try {
    const u = new URL(url);
    let removed = false;
    for (const key of Array.from(u.searchParams.keys())) {
      if (TRACKING_PARAMS.has(key)) {
        u.searchParams.delete(key);
        removed = true;
      }
    }
    if (!removed) return url;
    // Remove trailing '?' if no params remain
    const result = u.toString();
    return result.endsWith("?") ? result.slice(0, -1) : result;
  } catch {
    return url;
  }
}

/**
 * Follow redirects for shortened URLs (bit.ly, t.co, tinyurl, etc.).
 * Returns the final destination URL or the original if unshortening fails.
 */
export async function unshortenUrl(
  url: string,
  maxRedirects = 10,
  timeoutMs = 8000
): Promise<string> {
  let current = url;
  for (let i = 0; i < maxRedirects; i++) {
    const next = await followOneRedirect(current, timeoutMs);
    if (!next || next === current) break;
    current = next;
  }
  return current;
}

async function followOneRedirect(
  url: string,
  timeoutMs: number
): Promise<string | null> {
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const resp = await fetch(url, {
        method: "HEAD",
        redirect: "manual",
        signal: controller.signal,
      });
      const location = resp.headers.get("location");
      if (
        resp.status >= 300 &&
        resp.status < 400 &&
        location
      ) {
        // Resolve relative redirects
        try {
          return new URL(location, url).toString();
        } catch {
          return location;
        }
      }
      return null;
    } finally {
      clearTimeout(timer);
    }
  } catch {
    return null;
  }
}

/**
 * Check whether a string looks like an http(s) URL.
 */
export function isHttpUrl(text: string): boolean {
  try {
    const u = new URL(text);
    return u.protocol === "http:" || u.protocol === "https:";
  } catch {
    return false;
  }
}
