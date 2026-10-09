import { useEffect, useState } from "react";

export const RELEASES_URL = "https://github.com/bsreeram08/chowser/releases/latest";
export const APP_STORE_URL = "https://apps.apple.com/in/app/chowser/id6760034779";

type LatestRelease = { version: string | null; dmgUrl: string };

/* Resolves the newest DMG from GitHub; falls back to the releases page if the API is unreachable. */
export function useLatestRelease(): LatestRelease {
  const [release, setRelease] = useState<LatestRelease>({ version: null, dmgUrl: RELEASES_URL });

  useEffect(() => {
    const controller = new AbortController();
    fetch("https://api.github.com/repos/bsreeram08/chowser/releases/latest", { signal: controller.signal })
      .then((response) => (response.ok ? response.json() : Promise.reject(response.status)))
      .then((data: { tag_name?: string; assets?: { name: string; browser_download_url: string }[] }) => {
        const dmg = data.assets?.find((asset) => asset.name.endsWith(".dmg"));
        if (dmg) setRelease({ version: data.tag_name?.replace(/^v/, "") ?? null, dmgUrl: dmg.browser_download_url });
      })
      .catch(() => {});
    return () => controller.abort();
  }, []);

  return release;
}
