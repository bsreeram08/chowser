import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { Card } from "@/components/ui/card";
import {
  Download,
  MousePointerClick,
  Globe,
  ListFilter,
  Eye,
  Wand2,
  Smartphone,
  Bot,
  ArrowRight,
  PanelTop,
  Stethoscope,
} from "lucide-react";

const Kbd: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <kbd className="keycap text-[11px] px-1.5 py-0.5 mx-0.5">{children}</kbd>
);

const STEPS = [
  {
    icon: PanelTop,
    title: "Choose App or Menu Bar mode",
    body:
      "Open Settings → General → App Mode. App mode keeps Chowser in the Dock and Cmd-Tab; Menu Bar mode runs without a Dock icon. You can switch later, and Chowser keeps Settings reachable if macOS rejects a transition.",
  },
  {
    icon: Download,
    title: "Install & onboard",
    body:
      "Download Chowser from the App Store and launch it. The first-run wizard walks you through making Chowser your default link handler and adding your browsers. Once the menu-bar icon appears, you're set.",
  },
  {
    icon: Globe,
    title: "Make it the default browser handler",
    body:
      "macOS sends every clicked link to Chowser instead of opening a browser directly. Keep the system default pointed at Chowser so links from any app route through the picker first.",
  },
  {
    icon: MousePointerClick,
    title: "Add browsers & profiles",
    body:
      "Open Settings → Browsers and add Chrome, Safari, Arc, Firefox and more. Chowser auto-detects profiles (Work, Personal) so you can route into a specific profile per rule.",
  },
  {
    icon: ListFilter,
    title: "Create routing rules",
    body:
      "In Settings → Rules, match on host (github.com), path prefix (/pulls), or source app (Slack). Order matters — the first matching rule wins. You can also create a rule on the fly from the picker.",
  },
  {
    icon: Eye,
    title: "Private mode & shortcuts",
    body: (
      <>
        Numbers <Kbd>1</Kbd>–<Kbd>9</Kbd> launch browsers, <Kbd>P</Kbd> opens
        the link in private mode, <Kbd>R</Kbd> creates a rule, <Kbd>H</Kbd>{" "}
        reveals a resolved shortlink, and arrow keys move selection. Your hands
        never leave the keyboard.
      </>
    ),
  },
  {
    icon: Wand2,
    title: "Set up URL rewrites",
    body: (
      <>
        In Settings → Rewrites, add transforms that clean a URL before routing —
        strip tracking params, upgrade http to https, or rewrite a host. Tap{" "}
        <span className="font-medium">Check for Predefined Rewrites</span> to
        import a curated catalog, then pick exactly which rules to enable.
      </>
    ),
  },
  {
    icon: Smartphone,
    title: "Send to Phone",
    body:
      "From the picker, AirDrop a link, show a QR code styled in your picker's colors, or copy it. Handoff also reaches nearby Apple devices so you can continue on iPhone.",
  },
  {
    icon: Bot,
    title: "Turn on the MCP server",
    body:
      "Enable the local MCP server in Settings → General to let an AI agent manage your browsers and routing rules for you, or use the AI Setup flow to describe your workflow in plain language.",
  },
  {
    icon: Stethoscope,
    title: "Find diagnostics when something goes wrong",
    body:
      "Open Settings → General → About → Diagnostics. You can inspect recent startup and App Mode events, copy or export a privacy-safe report, reveal raw logs for your own review, or open a prefilled GitHub issue.",
  },
];

export const Guide: React.FC = () => {
  return (
    <div className="bg-background min-h-screen text-foreground font-sans antialiased overflow-x-hidden">
      <Navbar />

      <main className="relative">
        <section className="text-center pt-36 sm:pt-44 pb-10 px-6">
          <span className="eyebrow inline-flex items-center gap-1.5">
            <Wand2 className="w-3 h-3" />
            Get started
          </span>
          <h1 className="font-display font-bold tracking-tight leading-[1.04] text-4xl sm:text-6xl text-foreground mt-4">
            How to set up Chowser
          </h1>
          <p className="text-muted-foreground text-lg max-w-2xl mx-auto mt-5 leading-relaxed">
            From first launch to advanced routing, rewrites, and troubleshooting.
          </p>
        </section>

        <section className="max-w-3xl mx-auto px-6 pb-28">
          <ol className="space-y-5">
            {STEPS.map((step, i) => {
              const Icon = step.icon;
              return (
                <li key={step.title}>
                  <Card className="flex gap-5 p-5 sm:p-6 items-start">
                    <div className="shrink-0 w-11 h-11 rounded-xl bg-primary/10 text-primary grid place-items-center">
                      <Icon className="w-5 h-5" />
                    </div>
                    <div className="min-w-0">
                      <div className="flex items-center gap-3">
                        <span className="text-xs font-mono font-semibold text-muted-foreground/70">
                          {String(i + 1).padStart(2, "0")}
                        </span>
                        <h3 className="font-display text-lg font-semibold tracking-tight text-foreground">
                          {step.title}
                        </h3>
                      </div>
                      <p className="text-muted-foreground text-[15px] leading-relaxed mt-2">
                        {step.body}
                      </p>
                    </div>
                  </Card>
                </li>
              );
            })}
          </ol>

          <div className="mt-14 grid md:grid-cols-2 gap-5">
            <Card className="p-6">
              <span className="eyebrow">How links flow</span>
              <h2 className="font-display text-xl font-semibold mt-3">Clean, match, then open</h2>
              <p className="text-sm text-muted-foreground leading-relaxed mt-3">
                Chowser applies enabled URL rewrites first, evaluates routing rules from top to bottom,
                then opens the first match. If nothing matches, your fallback policy either shows the
                picker or opens the browser you selected.
              </p>
            </Card>
            <Card className="p-6">
              <span className="eyebrow">Safe defaults</span>
              <h2 className="font-display text-xl font-semibold mt-3">Network work stays opt-in</h2>
              <p className="text-sm text-muted-foreground leading-relaxed mt-3">
                Shortlink resolution and catalog refreshes can contact the network. Hosted catalogs are
                signed, fetched only from fixed Chowser endpoints, and never receive the link you clicked.
                Rewrites and native-app deep links remain disabled until you approve them in Settings.
              </p>
              <a href="/rewrites" className="inline-flex items-center gap-1 text-sm font-medium text-primary mt-4 hover:underline">
                Browse predefined rewrites <ArrowRight className="w-3.5 h-3.5" />
              </a>
            </Card>
          </div>

          <div className="mt-10 flex items-center justify-center gap-2 text-sm text-muted-foreground">
            <span>Ready to route?</span>
            <a
              href="https://apps.apple.com/in/app/chowser/id6760034779"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1 font-medium text-primary hover:underline"
            >
              Get Chowser <ArrowRight className="w-3.5 h-3.5" />
            </a>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
};

export default Guide;
