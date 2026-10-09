import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { BrowserTileArt, type DemoBrowserKind } from "@/components/BrowserTileArt";
import { PickerDemo, useReducedMotion } from "@/components/PickerDemo";
import { APP_STORE_URL, useLatestRelease } from "@/hooks/use-latest-release";
import { Copy, Download, MousePointerClick } from "lucide-react";
import { cn } from "@/lib/utils";
import { toast } from "sonner";



/* The hero: a routing log. Each clicked link resolves to where Chowser sent it, and why. */
const ROUTES: {
  link: string;
  from: string;
  reason: string;
  to: string;
  tile: DemoBrowserKind | "picker";
}[] = [
  { link: "github.com/acme/api/pull/482", from: "Slack", reason: "Rule: github.com", to: "Chrome, Work profile", tile: "work" },
  { link: "figma.com/design/Onboarding", from: "Mail", reason: "Rule: figma.com", to: "Arc", tile: "arc" },
  { link: "t.co/3x8qA9L", from: "Messages", reason: "Unshortened to youtube.com", to: "Safari", tile: "safari" },
  { link: "open.spotify.com/track/4uLU6h", from: "Discord", reason: "Approved native app", to: "Spotify", tile: "spotify" },
  { link: "docs.google.com/doc/d/1Bx", from: "Slack", reason: "Source app: Slack", to: "Chrome, Work profile", tile: "work" },
  { link: "news.ycombinator.com/item?id=41", from: "Notes", reason: "No rule matched", to: "You choose", tile: "picker" },
];

const GROUPS = [
  {
    title: "Route",
    lead: "Decide once. Chowser remembers.",
    items: [
      ["Rules", "Match a host, a path, or the app you clicked from. The first match wins."],
      ["Profiles", "Open Chrome, Brave, Edge, Arc or Firefox straight into Work or Personal."],
      ["Native apps", "Send Spotify and other approved links to their Mac app instead of a tab."],
      ["Private mode", "Press P in the picker and the link opens in a private window."],
    ],
  },
  {
    title: "Clean",
    lead: "See where a link really goes.",
    items: [
      ["Unshortening", "t.co, bit.ly and friends are resolved before anything opens."],
      ["Tracking cleanup", "utm_ and other tracking parameters are stripped on the way through."],
      ["Rewrites", "Upgrade http, or rewrite hosts and paths with a signed, reviewable catalog."],
      ["Preview", "A link preview shows the destination before you commit to a browser."],
    ],
  },
  {
    title: "Hand off",
    lead: "Links that belong somewhere else.",
    items: [
      ["Send to phone", "AirDrop the link or scan a QR code when you need to sign in on your phone."],
      ["Clipboard", "Open whatever URL is on your clipboard from the menu bar."],
      ["Quick rules", "Press R in the picker to save a rule without opening Settings."],
      ["AI setup", "A local API lets your AI assistant discover browsers and write rules for you."],
    ],
  },
] as const;

const AGENT_PROMPT =
  "Run `curl -s https://chowser.sreerams.in/agentic-setup.md` to get the detailed Chowser configuration prompt, then follow it to help me set up my browsers.";

const DestinationTile: React.FC<{ tile: DemoBrowserKind | "picker" }> = ({ tile }) =>
  tile === "picker" ? (
    <div className="w-7 h-7 rounded-[27%] border border-dashed border-ink/30 grid place-items-center shrink-0">
      <MousePointerClick className="w-3.5 h-3.5 text-ink/60" />
    </div>
  ) : (
    <BrowserTileArt kind={tile} size={28} />
  );

const RoutingLog: React.FC = () => {
  const reducedMotion = useReducedMotion();
  return (
    <div className="rounded-[22px] bg-white shadow-[0_1px_0_rgba(21,22,28,0.04),0_24px_60px_-20px_rgba(36,30,120,0.28)] ring-1 ring-ink/[0.07] overflow-hidden">
      <div className="flex items-center justify-between px-5 py-3 border-b border-line">
        <span className="text-[13px] font-medium text-ink">Today's links</span>
        <span className="text-[12px] text-ink-soft hidden sm:inline">6 clicks, 0 wrong browsers</span>
      </div>
      <ol>
        {ROUTES.map((route, index) => (
          <li
            key={route.link}
            className={cn(
              "grid grid-cols-[1fr_auto] sm:grid-cols-[minmax(0,1fr)_minmax(0,0.8fr)] items-center gap-x-4 gap-y-1 px-5 py-3 border-b border-line last:border-b-0",
              !reducedMotion && "route-row",
            )}
            style={{ animationDelay: `${300 + index * 260}ms` }}
          >
            <div className="min-w-0">
              <div className="font-mono text-[13px] text-ink truncate">{route.link}</div>
              <div className="text-[12px] text-ink-soft truncate">
                from {route.from}. {route.reason}
              </div>
            </div>
            <div
              className={cn("flex items-center gap-2.5 min-w-0 justify-self-end sm:justify-self-start", !reducedMotion && "route-dest")}
              style={{ animationDelay: `${520 + index * 260}ms` }}
            >
              <DestinationTile tile={route.tile} />
              <span
                className={cn(
                  "text-[13px] font-medium truncate hidden sm:inline",
                  route.tile === "picker" ? "text-ink-soft" : "text-ink",
                )}
              >
                {route.to}
              </span>
            </div>
          </li>
        ))}
      </ol>
    </div>
  );
};

const DownloadButton: React.FC<{ dmgUrl: string; className?: string }> = ({ dmgUrl, className }) => (
  <a
    href={dmgUrl}
    className={cn(
      "inline-flex items-center justify-center gap-2 rounded-full bg-ink text-white px-6 py-3.5 text-[15px] font-medium transition-[background-color,transform] duration-[var(--duration-press)] ease-[var(--ease-out)] hover:bg-route active:scale-[0.97] motion-reduce:active:scale-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-route",
      className,
    )}
  >
    <Download className="w-4 h-4" />
    Download for Mac
  </a>
);

export const Home: React.FC = () => {
  const { version, dmgUrl } = useLatestRelease();

  return (
    <div className="bg-canvas min-h-screen text-ink font-sans antialiased overflow-x-hidden">
      <Navbar />

      <main>
        {/* Hero */}
        <section className="max-w-6xl mx-auto px-5 sm:px-8 pt-32 sm:pt-40 pb-20 sm:pb-28 grid lg:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)] gap-14 lg:gap-16 items-center">
          <div className="min-w-0">
            <h1 className="font-display font-semibold text-[40px] leading-[1.04] sm:text-[68px] sm:leading-[1.02] tracking-[-0.035em] text-ink">
              Every link opens in the right browser.
            </h1>
            <p className="mt-6 max-w-[34ch] text-[19px] sm:text-[21px] leading-[1.45] text-ink-soft">
              Chowser sits in your menu bar as your default browser and sends each link where it belongs: the right
              browser, the right profile, or the app itself.
            </p>
            <div className="mt-9 flex flex-col sm:flex-row sm:items-center gap-4">
              <DownloadButton dmgUrl={dmgUrl} />
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="text-[15px] font-medium text-ink underline decoration-ink/25 underline-offset-4 hover:decoration-ink"
              >
                Get it on the Mac App Store
              </a>
            </div>
            <p className="mt-4 text-[13px] text-ink-soft">
              {version ? `Version ${version}. ` : ""}Free, for macOS 14 Sonoma or later. Signed and notarized by Apple.
            </p>
          </div>
          <RoutingLog />
        </section>

        {/* Picker */}
        <section id="demo" className="bg-ink text-white">
          <div className="max-w-6xl mx-auto px-5 sm:px-8 py-20 sm:py-28 grid lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)] gap-12 lg:gap-16 items-center">
            <div>
              <h2 className="font-display font-semibold text-[34px] sm:text-[44px] leading-[1.05] tracking-[-0.03em]">
                When no rule fits, you pick in a keystroke.
              </h2>
              <p className="mt-5 text-[17px] leading-relaxed text-white/65 max-w-[40ch]">
                The picker appears right where you clicked. Press a number to open a browser, P for private, or R to
                remember the choice as a rule. Try it here.
              </p>
              <dl className="mt-8 grid grid-cols-[auto_1fr] gap-x-4 gap-y-2.5 text-[15px]">
                {[
                  ["1–9", "Open in that browser"],
                  ["P", "Open privately"],
                  ["R", "Save as a rule"],
                  ["H", "Reveal a shortened link"],
                  ["Shift", "Always show the picker"],
                ].map(([key, action]) => (
                  <div key={key} className="contents">
                    <dt>
                      <kbd className="keycap text-[12px] px-2 py-1 min-w-[2rem]">{key}</kbd>
                    </dt>
                    <dd className="text-white/80 self-center">{action}</dd>
                  </div>
                ))}
              </dl>
            </div>
            <div className="text-ink">
              <PickerDemo />
            </div>
          </div>
        </section>

        {/* Features */}
        <section className="max-w-6xl mx-auto px-5 sm:px-8 py-20 sm:py-28">
          <h2 className="font-display font-semibold text-[34px] sm:text-[44px] leading-[1.05] tracking-[-0.03em] max-w-[18ch]">
            Small decisions, made before the page loads.
          </h2>
          <div className="mt-14 grid md:grid-cols-3 gap-12 md:gap-10">
            {GROUPS.map((group) => (
              <div key={group.title} className="border-t-2 border-ink pt-5">
                <h3 className="font-display text-[22px] font-semibold tracking-[-0.02em]">{group.title}</h3>
                <p className="mt-1 text-[15px] text-ink-soft">{group.lead}</p>
                <dl className="mt-7 space-y-5">
                  {group.items.map(([name, description]) => (
                    <div key={name}>
                      <dt className="text-[15px] font-semibold text-ink">{name}</dt>
                      <dd className="mt-1 text-[15px] leading-relaxed text-ink-soft">{description}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            ))}
          </div>
          <p className="mt-12 text-[15px] text-ink-soft">
            Rewrites come from a signed catalog you review before installing.{" "}
            <a href="/rewrites" className="text-ink font-medium underline decoration-ink/25 underline-offset-4 hover:decoration-ink">
              Browse the rewrite catalog
            </a>
          </p>
        </section>

        {/* AI setup */}
        <section id="agentic-setup" className="max-w-6xl mx-auto px-5 sm:px-8 pb-20 sm:pb-28 scroll-mt-24">
          <div className="rounded-[28px] bg-white ring-1 ring-ink/[0.07] p-6 sm:p-12 grid lg:grid-cols-2 gap-10 lg:gap-14 items-center">
            <div>
              <h2 className="font-display font-semibold text-[30px] sm:text-[38px] leading-[1.08] tracking-[-0.03em]">
                Describe how you work. Your AI assistant writes the rules.
              </h2>
              <p className="mt-5 text-[16px] leading-relaxed text-ink-soft max-w-[46ch]">
                Paste this into Claude, ChatGPT, Cursor or any assistant that can run commands. It finds your browsers
                and profiles, shows you the exact launch commands, and writes the routing rules.
              </p>
              <div className="mt-6 rounded-2xl bg-canvas ring-1 ring-line p-4 sm:p-5">
                <p className="font-mono text-[13px] leading-relaxed text-ink break-words">{AGENT_PROMPT}</p>
                <button
                  type="button"
                  onClick={() => {
                    navigator.clipboard.writeText(AGENT_PROMPT);
                    toast.success("Prompt copied");
                  }}
                  className="mt-4 inline-flex items-center gap-2 rounded-full bg-ink text-white px-4 py-2 text-[13px] font-medium hover:bg-route transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-route"
                >
                  <Copy className="w-3.5 h-3.5" />
                  Copy prompt
                </button>
              </div>
            </div>
            <div>
              <div className="rounded-2xl bg-canvas ring-1 ring-line px-5 py-4 text-[16px] leading-relaxed text-ink">
                “Work stuff in Chrome Work, design in Arc, everything else asks me.”
              </div>
              <ul className="mt-3 space-y-2">
                {[
                  { pattern: "*.slack.com", target: "Chrome, Work" },
                  { pattern: "github.com/*", target: "Chrome, Work" },
                  { pattern: "figma.com/*", target: "Arc" },
                  { pattern: "everything else", target: "Show the picker" },
                ].map((rule) => (
                  <li
                    key={rule.pattern}
                    className="flex items-center justify-between gap-4 rounded-xl bg-white ring-1 ring-line px-4 py-2.5"
                  >
                    <span className="font-mono text-[13px] text-ink">{rule.pattern}</span>
                    <span className="text-[13px] font-medium text-route">{rule.target}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </section>

        {/* Download */}
        <section id="download" className="border-t border-line">
          <div className="max-w-6xl mx-auto px-5 sm:px-8 py-20 sm:py-28">
            <h2 className="font-display font-semibold text-[34px] sm:text-[44px] leading-[1.05] tracking-[-0.03em]">
              Two ways to install.
            </h2>
            <div className="mt-12 grid md:grid-cols-2 gap-6">
              <div className="rounded-[22px] bg-white ring-2 ring-ink p-7 sm:p-9 flex flex-col">
                <h3 className="font-display text-[24px] font-semibold tracking-[-0.02em]">Direct download</h3>
                <p className="mt-2 text-[15px] text-ink-soft">Recommended. Every feature, updated automatically.</p>
                <ul className="mt-6 space-y-2.5 text-[15px] text-ink flex-1">
                  <li>Opens browsers directly into a chosen profile</li>
                  <li>Updates itself in the background</li>
                  <li>Signed and notarized by Apple</li>
                </ul>
                <DownloadButton dmgUrl={dmgUrl} className="mt-8 self-start" />
              </div>
              <div className="rounded-[22px] bg-white ring-1 ring-line p-7 sm:p-9 flex flex-col">
                <h3 className="font-display text-[24px] font-semibold tracking-[-0.02em]">Mac App Store</h3>
                <p className="mt-2 text-[15px] text-ink-soft">The same app, inside Apple's sandbox.</p>
                <ul className="mt-6 space-y-2.5 text-[15px] text-ink flex-1">
                  <li>Updates through the App Store</li>
                  <li>Sandboxing limits opening specific browser profiles</li>
                  <li>Everything else works the same</li>
                </ul>
                <a
                  href={APP_STORE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="mt-8 self-start inline-flex items-center rounded-full ring-1 ring-ink/20 px-6 py-3.5 text-[15px] font-medium text-ink hover:ring-ink transition-shadow focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-route"
                >
                  Open the App Store
                </a>
              </div>
            </div>
            <p className="mt-8 text-[15px] text-ink-soft">
              New to Chowser?{" "}
              <a href="/guide" className="text-ink font-medium underline decoration-ink/25 underline-offset-4 hover:decoration-ink">
                Read the setup guide
              </a>
            </p>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
};

export default Home;
