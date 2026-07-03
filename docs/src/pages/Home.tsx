import { useState, useEffect } from "react";
import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import {
  Link as LinkIcon,
  Plus,
  Copy,
  Globe,
  Zap,
  Shield,
  Search,
  Terminal,
  Bot,
  Sparkles,
  Wand2,
  Smartphone,
  MousePointer2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

const APP_STORE_URL = "https://apps.apple.com/in/app/chowser/id6760034779";

/* Colorful QR glyph — the only saturated element on the page (pure CSS). */
const QrGlyph = () => (
  <div className="shrink-0 w-[84px] h-[84px] rounded-2xl bg-white shadow-[0_8px_20px_rgba(0,0,0,0.1)] grid place-items-center">
    <div
      className="w-[60px] h-[60px] rounded-[4px] relative"
      style={{
        background:
          "repeating-linear-gradient(0deg,#4b3de8 0 4px,transparent 4px 8px), repeating-linear-gradient(90deg,#4b3de8 0 4px,#22a7f0 4px 8px)",
      }}
    >
      <div className="absolute inset-[22px] bg-white rounded-full shadow-[0_0_0_3px_#fff]" />
    </div>
  </div>
);

export const Home: React.FC = () => {
  const [isPrivate, setIsPrivate] = useState(false);
  const [isRuleSimulatorOpen, setIsRuleSimulatorOpen] = useState(false);
  const [selectedBrowser, setSelectedBrowser] = useState<string | null>(null);
  const [isRevealed, setIsRevealed] = useState(false);

  // Animation Demo State
  const [demoStep, setDemoStep] = useState(0);
  const [userInteracted, setUserInteracted] = useState(false);

  // AI Setup Animation State
  const [aiDemoStep, setAiDemoStep] = useState(0);

  useEffect(() => {
    const aiInterval = setInterval(() => {
      setAiDemoStep((prev) => (prev >= 6 ? 0 : prev + 1));
    }, 2500);
    return () => clearInterval(aiInterval);
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === "p") {
        setIsPrivate((prev) => !prev);
        toast.info(`Private Mode ${!isPrivate ? "Enabled" : "Disabled"}`, {
          duration: 1500,
          icon: <Shield className="w-4 h-4" />,
        });
      }
      if (e.key.toLowerCase() === "r") {
        setIsRuleSimulatorOpen((prev) => !prev);
        if (selectedBrowser) setSelectedBrowser(null);
      }
      if (e.key.toLowerCase() === "h") {
        setIsRevealed((prev) => !prev);
        toast.success(
          !isRevealed ? "URL unshortened successfully!" : "Preview reset",
          {
            duration: 1500,
            icon: <Search className="w-4 h-4" />,
          },
        );
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    const timers: ReturnType<typeof setTimeout>[] = [];
    if (!userInteracted) {
      const runLoop = () => {
        setDemoStep(0);
        timers.push(setTimeout(() => setDemoStep(1), 1000)); // Mouse starts moving
        timers.push(setTimeout(() => setDemoStep(2), 2500)); // Mouse hovers link
        timers.push(setTimeout(() => setDemoStep(3), 2800)); // Mouse clicks link
        timers.push(setTimeout(() => setDemoStep(4), 3100)); // Panel opens
        timers.push(setTimeout(runLoop, 8000)); // Reset after 8s
      };
      runLoop();
    } else {
      setDemoStep(4); // Keep panel open if user interacts
    }

    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      timers.forEach(clearTimeout);
    };
  }, [
    isPrivate,
    isRuleSimulatorOpen,
    selectedBrowser,
    isRevealed,
    userInteracted,
  ]);

  const handleBrowserSelect = (name: string) => {
    if (isRuleSimulatorOpen) {
      setSelectedBrowser(name);
      toast.success(`Rule set: Always open with ${name}`, {
        duration: 2000,
        icon: <Zap className="w-4 h-4" />,
      });
      setTimeout(() => setIsRuleSimulatorOpen(false), 1500);
    }
  };

  const handleCopy = () => {
    let url = "";
    if (selectedBrowser) {
      url = `rule:always_${selectedBrowser.toLowerCase()}`;
    } else if (isPrivate) {
      url = "private.browsing.enabled";
    } else if (isRevealed) {
      url = "https://github.com/bsreeram08/chowser";
    } else {
      url = "https://t.co/3x8qA9L";
    }

    navigator.clipboard.writeText(url);
    toast.success("URL/Rule copied to clipboard", {
      duration: 2000,
      icon: <Copy className="w-4 h-4" />,
    });
  };

  return (
    <div className="bg-background min-h-screen text-foreground font-sans antialiased overflow-x-hidden">
      <Navbar />

      <main className="relative">
        {/* ── Hero ── */}
        <section className="text-center pt-36 sm:pt-44 pb-14 px-6">
          <h1 className="font-display font-bold tracking-tight leading-[1.02] text-5xl sm:text-7xl text-foreground animate-in fade-in slide-in-from-bottom-4 duration-1000">
            The right browser.
            <br />
            Every link.
          </h1>
          <p className="mt-6 mx-auto max-w-xl text-lg sm:text-2xl text-muted-foreground leading-snug animate-in fade-in slide-in-from-bottom-4 duration-1000 delay-100">
            Chowser lives in your menu bar and routes every link you click to
            the browser it belongs in.
          </p>
          <div className="mt-9 flex flex-col sm:flex-row items-center justify-center gap-3 animate-in fade-in slide-in-from-bottom-4 duration-1000 delay-200">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center rounded-full bg-primary text-primary-foreground px-7 py-3.5 text-base font-medium transition-all hover:brightness-110 hover:-translate-y-0.5 shadow-sm"
            >
              Get Chowser
            </a>
            <a
              href="#demo"
              className="inline-flex items-center justify-center rounded-full px-5 py-3.5 text-base font-medium text-primary transition-colors hover:brightness-110"
            >
              Watch the demo ›
            </a>
          </div>
        </section>

        {/* ── Product mockup on a soft gradient desktop ── */}
        <section id="demo" className="max-w-5xl mx-auto px-6">
          <div
            className="rounded-[20px] px-6 sm:px-10 py-20 sm:py-24 flex justify-center shadow-[inset_0_0_0_1px_rgba(0,0,0,0.05)] relative overflow-hidden"
            style={{
              background:
                "radial-gradient(1200px 500px at 30% 0%, #cfe3ff 0%, transparent 60%), radial-gradient(900px 500px at 80% 100%, #ffd9c8 0%, transparent 55%), linear-gradient(160deg, #e8ecf4 0%, #dde5f0 100%)",
            }}
          >
            <div
              className="relative flex justify-center w-full h-[300px]"
              onMouseEnter={() => setUserInteracted(true)}
              onClick={() => setUserInteracted(true)}
            >
              {/* Mock chat message with the link being clicked */}
              <div
                className={cn(
                  "absolute top-2 left-1/2 -translate-x-1/2 w-full max-w-[320px] bg-white/70 border border-black/5 rounded-2xl p-4 flex flex-col gap-3 shadow-sm transition-all duration-1000 origin-bottom",
                  demoStep >= 4
                    ? "opacity-30 scale-95 blur-sm translate-y-[-20px]"
                    : "opacity-100 scale-100 blur-none translate-y-0",
                )}
              >
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                    <Bot className="w-4 h-4 text-primary" />
                  </div>
                  <div className="space-y-1">
                    <div className="text-xs font-semibold text-foreground">
                      Teammate{" "}
                      <span className="text-[10px] text-muted-foreground font-normal ml-1">
                        Today at 2:00 PM
                      </span>
                    </div>
                    <div className="text-sm text-foreground/90">
                      Hey, can you review this PR?
                    </div>
                  </div>
                </div>
                <div className="pl-11">
                  <span
                    className={cn(
                      "text-primary text-sm cursor-pointer transition-colors duration-300",
                      demoStep === 2 || demoStep === 3
                        ? "underline bg-primary/10 rounded px-1"
                        : "hover:underline",
                    )}
                  >
                    https://t.co/3x8qA9L
                  </span>
                </div>

                {/* Animated mouse cursor */}
                {!userInteracted && (
                  <div
                    className="absolute pointer-events-none z-50 text-foreground drop-shadow-xl transition-all"
                    style={{
                      left: demoStep === 0 ? "80%" : demoStep >= 1 ? "40%" : "80%",
                      top: demoStep === 0 ? "150%" : demoStep >= 1 ? "70%" : "150%",
                      transitionDuration: demoStep === 1 ? "1.5s" : "0.3s",
                      transitionProperty: "all",
                      transitionTimingFunction: "ease-out",
                      transform: demoStep === 3 ? "scale(0.8)" : "scale(1)",
                    }}
                  >
                    <MousePointer2 className="w-6 h-6 fill-white drop-shadow-[0_4px_4px_rgba(0,0,0,0.35)]" />
                  </div>
                )}
              </div>

              {/* Soft glow behind panel */}
              <div
                className={cn(
                  "absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-[20%] w-full max-w-[420px] h-[200px] bg-primary/20 blur-[90px] -z-0 transition-all duration-1000",
                  demoStep >= 4 ? "opacity-100 scale-100" : "opacity-0 scale-50",
                )}
              />

              {/* The Chowser picker panel — frosted white */}
              <div
                className={cn(
                  "flex flex-col w-full max-w-[360px] sm:max-w-[400px] mx-auto rounded-[18px] absolute origin-center overflow-hidden transition-all duration-700 backdrop-blur-[30px] shadow-[0_30px_70px_rgba(20,30,60,0.25),inset_0_0_0_1px_rgba(255,255,255,0.6)]",
                  isPrivate
                    ? "bg-[#eef1ff]/85 ring-1 ring-primary/15"
                    : "bg-white/72",
                  demoStep >= 4
                    ? "opacity-100 scale-100 translate-y-0"
                    : "opacity-0 scale-90 translate-y-8 pointer-events-none",
                )}
              >
                {/* Header: URL bar + mini actions */}
                <div className="flex items-center gap-2 px-4 py-3 border-b border-black/[0.06]">
                  <LinkIcon className="w-3.5 h-3.5 shrink-0 text-muted-foreground" />
                  <span className="text-[13px] font-medium text-foreground flex-1 truncate">
                    {isRuleSimulatorOpen
                      ? selectedBrowser
                        ? `rule:always_${selectedBrowser.toLowerCase()}`
                        : "Create Rule for github.com"
                      : isPrivate
                        ? "private.browsing.enabled"
                        : isRevealed
                          ? "github.com/bsreeram08/chowser"
                          : "t.co/3x8qA9L"}
                  </span>
                  <div className="flex items-center gap-1.5">
                    {[
                      {
                        key: "plus",
                        node: (
                          <Plus
                            className={cn(
                              "w-3.5 h-3.5",
                              isRuleSimulatorOpen
                                ? "text-primary"
                                : "text-muted-foreground",
                            )}
                          />
                        ),
                        onClick: () => setIsRuleSimulatorOpen(!isRuleSimulatorOpen),
                        title: "Create rule",
                      },
                      {
                        key: "copy",
                        node: <Copy className="w-3.5 h-3.5 text-muted-foreground" />,
                        onClick: handleCopy,
                        title: "Copy link",
                      },
                      {
                        key: "phone",
                        node: (
                          <Smartphone className="w-3.5 h-3.5 text-muted-foreground" />
                        ),
                        onClick: () =>
                          toast.success("Sent to Phone", {
                            duration: 2000,
                            description: "AirDrop · QR code · or copy",
                            icon: <Smartphone className="w-4 h-4" />,
                          }),
                        title: "Send to Phone",
                      },
                    ].map((a) => (
                      <button
                        key={a.key}
                        title={a.title}
                        onClick={a.onClick}
                        className="w-[26px] h-[26px] rounded-[7px] bg-black/[0.05] hover:bg-black/[0.09] flex items-center justify-center transition-colors"
                      >
                        {a.node}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Body: browser bar or rule simulator */}
                <div className="relative min-h-[140px] flex items-center justify-center">
                  {isRuleSimulatorOpen ? (
                    <div className="flex flex-col items-center gap-4 px-6 text-center animate-in fade-in slide-in-from-top-4 duration-500">
                      <div className="p-3 rounded-full bg-primary/10 border border-primary/20">
                        <Zap className="w-6 h-6 text-primary animate-pulse" />
                      </div>
                      <div className="space-y-1">
                        <p className="text-sm font-semibold text-foreground">
                          {selectedBrowser
                            ? "Rule Created!"
                            : "Select Default Browser"}
                        </p>
                        <p className="text-[11px] text-muted-foreground">
                          {selectedBrowser
                            ? "Saved to Chowser settings"
                            : "For all links on github.com"}
                        </p>
                      </div>
                      <div className="flex gap-4">
                        {[
                          {
                            name: "Safari",
                            color: "bg-[#006CFF]",
                            icon: <Globe className="w-4 h-4" />,
                          },
                          {
                            name: "Firefox",
                            color: "bg-[#FF6611]",
                            icon: <Shield className="w-4 h-4" />,
                          },
                          {
                            name: "Chrome",
                            color: "bg-[#4285F4]",
                            icon: <Zap className="w-4 h-4" />,
                          },
                        ].map((browser) => (
                          <button
                            key={browser.name}
                            onClick={() => handleBrowserSelect(browser.name)}
                            className={cn(
                              "w-10 h-10 rounded-xl flex items-center justify-center text-white transition-all hover:scale-110 active:scale-95 shadow-md",
                              browser.color,
                            )}
                          >
                            {browser.icon}
                          </button>
                        ))}
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-start justify-center gap-5 px-4 py-6 w-full">
                      {[
                        {
                          name: "Safari",
                          color: "bg-[#006CFF]",
                          icon: <Globe className="w-5 h-5" />,
                          key: "1",
                        },
                        {
                          name: "Firefox",
                          color: "bg-[#FF6611]",
                          icon: <Shield className="w-5 h-5 opacity-70" />,
                          key: "2",
                        },
                        {
                          name: "Chrome",
                          color: "bg-[#4285F4]",
                          icon: <Zap className="w-5 h-5" />,
                          key: "3",
                        },
                      ].map((browser, i) => (
                        <div
                          key={browser.name}
                          className="flex flex-col items-center gap-2 group/browser cursor-pointer"
                          onClick={() => handleBrowserSelect(browser.name)}
                        >
                          <div
                            className={cn(
                              "w-[56px] h-[56px] rounded-2xl flex items-center justify-center relative transition-all duration-300",
                              selectedBrowser === browser.name ||
                                (!selectedBrowser && i === 0)
                                ? "bg-black/[0.06] ring-1 ring-black/10 scale-105"
                                : "hover:bg-black/[0.04]",
                            )}
                          >
                            <div
                              className={cn(
                                "w-[40px] h-[40px] rounded-xl flex items-center justify-center text-white shadow-lg transition-transform duration-300 group-hover/browser:scale-110",
                                browser.color,
                              )}
                            >
                              {browser.icon}
                            </div>
                            <span className="absolute -bottom-1 -right-1 z-20 text-[10px] font-bold font-mono text-white bg-[#1d1d1f] rounded-md px-1.5 py-0.5 leading-none shadow-sm">
                              {browser.key}
                            </span>
                          </div>
                          <span
                            className={cn(
                              "text-[11px] font-medium transition-colors",
                              selectedBrowser === browser.name ||
                                (!selectedBrowser && i === 0)
                                ? "text-foreground"
                                : "text-muted-foreground group-hover/browser:text-foreground",
                            )}
                          >
                            {browser.name}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Footer: keyboard hints */}
                <div className="flex items-center gap-2.5 w-full px-4 py-2.5 border-t border-black/[0.06] bg-white/40 overflow-x-auto">
                  <div
                    className={cn(
                      "flex items-center gap-1.5 shrink-0 transition-opacity",
                      isPrivate ? "opacity-100" : "opacity-45",
                    )}
                  >
                    <kbd
                      className={cn(
                        "keycap text-[10px] px-1.5 py-0.5",
                        isPrivate && "keycap-active",
                      )}
                    >
                      P
                    </kbd>
                    <span className="text-[9px] font-bold text-muted-foreground tracking-widest uppercase">
                      Private
                    </span>
                  </div>
                  <div
                    className={cn(
                      "flex items-center gap-1.5 shrink-0 transition-opacity",
                      isRuleSimulatorOpen || selectedBrowser
                        ? "opacity-100"
                        : "opacity-45",
                    )}
                  >
                    <kbd
                      className={cn(
                        "keycap text-[10px] px-1.5 py-0.5",
                        (isRuleSimulatorOpen || selectedBrowser) &&
                          "keycap-active",
                      )}
                    >
                      R
                    </kbd>
                    <span className="text-[9px] font-bold text-muted-foreground tracking-widest uppercase">
                      {isRuleSimulatorOpen ? "Active" : "Rule"}
                    </span>
                  </div>
                  <div
                    className={cn(
                      "flex items-center gap-1.5 shrink-0 transition-opacity",
                      isRevealed ? "opacity-100" : "opacity-45",
                    )}
                  >
                    <kbd
                      className={cn(
                        "keycap text-[10px] px-1.5 py-0.5",
                        isRevealed && "keycap-active",
                      )}
                    >
                      H
                    </kbd>
                    <span className="text-[9px] font-bold text-muted-foreground tracking-widest uppercase flex items-center gap-1">
                      <Search className="w-2.5 h-2.5" />{" "}
                      {isRevealed ? "Revealed" : "Reveal"}
                    </span>
                  </div>
                  <div className="flex-1 min-w-[20px]" />
                  <div className="flex items-center gap-1.5 shrink-0">
                    <kbd className="keycap keycap-active text-[10px] px-1.5 py-0.5">
                      ↵
                    </kbd>
                    <span className="text-[9px] font-bold text-primary tracking-widest uppercase">
                      Launch
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <p className="text-center text-[13px] text-muted-foreground mt-4">
            Try it: press{" "}
            <kbd className="keycap text-[11px] px-1.5 py-0.5">P</kbd>,{" "}
            <kbd className="keycap text-[11px] px-1.5 py-0.5">R</kbd>, or{" "}
            <kbd className="keycap text-[11px] px-1.5 py-0.5">H</kbd>.
          </p>
        </section>

        {/* ── Features: thin-divider rows ── */}
        <section className="max-w-4xl mx-auto px-6 my-24 sm:my-28">
          <div className="flex flex-col sm:flex-row gap-4 sm:gap-7 py-8 border-t border-black/[0.08]">
            <h3 className="sm:flex-[0_0_220px] font-display text-lg font-semibold tracking-tight text-foreground">
              Rules that route for you
            </h3>
            <p className="text-muted-foreground text-[15px] leading-relaxed">
              Host, path, and source-app matching sends GitHub to your work
              profile and YouTube to your personal one — automatically, before
              the picker even appears.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row gap-4 sm:gap-7 py-8 border-t border-black/[0.08]">
            <h3 className="sm:flex-[0_0_220px] font-display text-lg font-semibold tracking-tight text-foreground">
              Keyboard first
            </h3>
            <p className="text-muted-foreground text-[15px] leading-relaxed">
              Numbers launch browsers. P for private mode. R creates a rule.
              Your hands never leave the keys.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row items-start sm:items-center gap-4 sm:gap-7 py-8 border-t border-black/[0.08]">
            <QrGlyph />
            <h3 className="sm:flex-[0_0_136px] font-display text-lg font-semibold tracking-tight text-foreground">
              Send to Phone
            </h3>
            <p className="text-muted-foreground text-[15px] leading-relaxed">
              AirDrop the link, scan a QR code styled in the app's own colors,
              or copy it — perfect for links that need your phone to sign in.
              Handoff reaches nearby Apple devices too.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row gap-4 sm:gap-7 py-8 border-t border-black/[0.08]">
            <h3 className="sm:flex-[0_0_220px] font-display text-lg font-semibold tracking-tight text-foreground">
              Private by design
            </h3>
            <p className="text-muted-foreground text-[15px] leading-relaxed">
              One keystroke opens any link in incognito. Tracking parameters are
              shredded and shortlinks resolved before your browser ever sees
              them.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row gap-4 sm:gap-7 py-8 border-t border-black/[0.08]">
            <h3 className="sm:flex-[0_0_220px] font-display text-lg font-semibold tracking-tight text-foreground">
              Profiles
            </h3>
            <p className="text-muted-foreground text-[15px] leading-relaxed">
              Multi-profile routing across Chrome, Brave, Edge, Firefox and more
              keeps work and personal separate. Full per-profile launch works in
              the direct-download build; macOS sandboxing limits the App Store
              build.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row gap-4 sm:gap-7 py-8 border-t border-b border-black/[0.08]">
            <h3 className="sm:flex-[0_0_220px] font-display text-lg font-semibold tracking-tight text-foreground">
              Make it yours
            </h3>
            <p className="text-muted-foreground text-[15px] leading-relaxed">
              Tune the picker's tint, transparency, corner radius, and accent
              color with a live preview over any background. Icons or list
              layout — your call.
            </p>
          </div>
        </section>

        {/* ── AI-Enhanced Setup ── */}
        <section
          id="agentic-setup"
          className="max-w-4xl mx-auto px-6 mt-8 mb-28 scroll-mt-28"
        >
          <header className="text-center space-y-5 mb-14">
            <span className="eyebrow inline-flex items-center gap-1.5">
              <Sparkles className="w-3 h-3" />
              AI-Enhanced Setup
            </span>
            <h2 className="font-display text-3xl md:text-5xl font-bold tracking-tight text-foreground">
              Let AI configure Chowser
            </h2>
            <p className="text-muted-foreground text-lg max-w-2xl mx-auto leading-relaxed">
              Automate browser profile discovery and rule generation — your AI
              agent can research each browser's profile and private-window launch
              arguments, preview the exact command, and set them for you. Paste
              the prompt into your favorite AI agent to get started.
            </p>
          </header>

          <div className="grid gap-6">
            {/* Step 1 */}
            <div className="relative">
              <div className="absolute -left-4 top-6 w-8 h-8 rounded-full bg-primary flex items-center justify-center font-bold text-primary-foreground z-10 hidden md:flex shadow-md">
                1
              </div>
              <Card className="panel-hard rounded-2xl overflow-hidden relative flex flex-col lg:flex-row">
                <div className="p-6 sm:p-8 flex-1 space-y-4">
                  <h3 className="text-xl sm:text-2xl font-semibold tracking-tight flex items-center gap-2 text-foreground">
                    <Terminal className="w-5 h-5 text-primary" />
                    Run Terminal Command
                  </h3>
                  <p className="text-muted-foreground text-sm sm:text-base max-w-md">
                    This command fetches the full setup prompt and pipes it
                    straight to your clipboard.
                  </p>

                  <div className="group/code relative max-w-lg">
                    <pre className="bg-[#f5f5f7] p-4 rounded-xl font-mono text-[13px] border border-black/[0.06] text-foreground overflow-x-auto">
                      <code>
                        Run `curl -s https://chowser.sreerams.in/agentic-setup.md`
                        to get instructions and follow them.
                      </code>
                    </pre>
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={() => {
                        navigator.clipboard.writeText(
                          "Run `curl -s https://chowser.sreerams.in/agentic-setup.md` to get the detailed Chowser configuration prompt, then follow it to help me set up my browsers.",
                        );
                        toast.success("Mini-prompt copied to clipboard");
                      }}
                      className="absolute right-2 top-2 opacity-0 group-hover/code:opacity-100 transition-opacity"
                    >
                      <Copy className="w-3 h-3 mr-2" />
                      Copy Prompt
                    </Button>
                  </div>
                </div>
                {/* AI agent animation */}
                <div className="hidden lg:flex w-80 bg-[#f5f5f7] border-l border-black/[0.06] relative items-center justify-center p-6 shrink-0">
                  <div className="w-full h-36 bg-white border border-black/[0.08] rounded-xl overflow-hidden shadow-sm font-mono text-[11px] flex flex-col">
                    <div className="flex items-center gap-1.5 px-3 py-2 bg-primary/5 border-b border-black/[0.06]">
                      <Sparkles className="w-3 h-3 text-primary" />
                      <span className="text-muted-foreground font-sans text-[10px] font-medium">
                        Your AI Agent
                      </span>
                    </div>
                    <div className="p-3 space-y-2 text-foreground/80 flex-1 relative">
                      <div className="flex items-start gap-2">
                        <div className="shrink-0 w-4 h-4 rounded bg-primary/10 flex items-center justify-center">
                          <Bot className="w-3 h-3 text-primary" />
                        </div>
                        <div className="relative flex-1 min-w-0">
                          <div className="flex flex-col gap-1.5">
                            <span
                              className="overflow-hidden whitespace-normal inline-block text-[10px] leading-relaxed"
                              style={{
                                opacity: aiDemoStep >= 1 ? 1 : 0,
                                transition: "opacity 0.5s ease-in",
                              }}
                            >
                              Run `curl -s https://chowser...`
                            </span>
                            <div
                              className={cn(
                                "h-px bg-black/10 transition-all duration-700",
                                aiDemoStep >= 2 ? "w-full" : "w-0",
                              )}
                            />
                            <span
                              className="text-[9px] text-primary/70 italic"
                              style={{
                                opacity: aiDemoStep >= 2 ? 1 : 0,
                                transition: "opacity 0.5s ease-in",
                              }}
                            >
                              Fetching config...
                            </span>
                          </div>
                        </div>
                      </div>
                      <div
                        className={cn(
                          "absolute bottom-3 right-3 transition-all duration-300",
                          aiDemoStep >= 2
                            ? "opacity-100 translate-y-0"
                            : "opacity-0 translate-y-2 pointer-events-none",
                        )}
                      >
                        <Sparkles className="w-3.5 h-3.5 text-primary animate-pulse" />
                      </div>
                    </div>
                  </div>
                </div>
              </Card>
            </div>

            {/* Step 2 */}
            <div className="relative">
              <div className="absolute -left-4 top-6 w-8 h-8 rounded-full bg-primary flex items-center justify-center font-bold text-primary-foreground z-10 hidden md:flex shadow-md">
                2
              </div>
              <Card className="panel-hard rounded-2xl overflow-hidden relative flex flex-col lg:flex-row">
                <div className="p-6 sm:p-8 flex-1 space-y-4">
                  <h3 className="text-xl sm:text-2xl font-semibold tracking-tight flex items-center gap-2 text-foreground">
                    <Wand2 className="w-5 h-5 text-primary" />
                    Paste to AI Assistant
                  </h3>
                  <p className="text-muted-foreground text-sm sm:text-base leading-relaxed max-w-md">
                    Open your AI assistant and paste the content. The AI will
                    then:
                  </p>
                  <ul className="space-y-3 text-sm text-muted-foreground list-disc list-inside ml-2">
                    <li>
                      Scan your{" "}
                      <span className="text-foreground">
                        Application Support
                      </span>{" "}
                      folders for browsers.
                    </li>
                    <li>Discover all available profiles and spaces.</li>
                    <li>
                      Generate your{" "}
                      <span className="text-foreground">
                        ChowserBrowsers.json
                      </span>{" "}
                      configuration.
                    </li>
                    <li>
                      Draft routing rules based on your specific requirements.
                    </li>
                  </ul>
                </div>
                {/* AI chat animation */}
                <div className="hidden lg:flex w-[26rem] bg-[#f5f5f7] border-l border-black/[0.06] relative items-center justify-center p-6 shrink-0">
                  <div className="w-full bg-white border border-black/[0.08] rounded-xl overflow-hidden shadow-sm flex flex-col h-64 relative">
                    <div className="p-3 bg-primary/5 border-b border-black/[0.06] flex items-center gap-2">
                      <Wand2 className="w-4 h-4 text-primary" />
                      <span className="text-xs font-medium text-foreground/80">
                        Composer
                      </span>
                    </div>
                    <div className="p-4 flex-1 overflow-y-auto space-y-4 text-[11px]">
                      {/* User message */}
                      <div
                        className={cn(
                          "flex justify-end transition-all duration-500",
                          aiDemoStep >= 3
                            ? "opacity-100 translate-y-0"
                            : "opacity-0 translate-y-4",
                        )}
                      >
                        <div className="bg-primary/10 text-foreground px-3 py-2.5 rounded-xl max-w-[85%] rounded-tr-sm border border-primary/15">
                          <div className="flex items-center gap-1.5 opacity-60 mb-1">
                            <Terminal className="w-3 h-3" />
                            <span className="text-[9px] uppercase tracking-wider font-bold">
                              Pasted Script
                            </span>
                          </div>
                          <div className="text-muted-foreground line-clamp-2 italic">
                            "You are an expert macOS configuration assistant.
                            Help me configure..."
                          </div>
                        </div>
                      </div>
                      {/* AI message */}
                      <div
                        className={cn(
                          "flex justify-start transition-all duration-500",
                          aiDemoStep >= 4
                            ? "opacity-100 translate-y-0"
                            : "opacity-0 translate-y-4",
                        )}
                      >
                        <div className="bg-[#f5f5f7] text-foreground px-3 py-3 rounded-xl max-w-[95%] rounded-tl-sm border border-black/[0.06] space-y-3">
                          <div className="flex items-center gap-2 text-primary">
                            <Bot className="w-3.5 h-3.5" />
                            <span className="font-medium text-[10px]">
                              Analyzing browsers...
                            </span>
                            {aiDemoStep === 4 && (
                              <span className="flex gap-0.5 ml-1">
                                <span className="w-1 h-1 bg-primary rounded-full animate-bounce" />
                                <span
                                  className="w-1 h-1 bg-primary rounded-full animate-bounce"
                                  style={{ animationDelay: "150ms" }}
                                />
                                <span
                                  className="w-1 h-1 bg-primary rounded-full animate-bounce"
                                  style={{ animationDelay: "300ms" }}
                                />
                              </span>
                            )}
                          </div>
                          <div
                            className={cn(
                              "bg-[#1d1d1f] p-2.5 rounded-lg font-mono text-[9px] text-green-400 overflow-hidden transition-all duration-700",
                              aiDemoStep >= 5
                                ? "opacity-100 max-h-32 scale-100"
                                : "opacity-0 max-h-0 scale-95 pointer-events-none",
                            )}
                          >
                            <pre>{`{
  "browsers": [
    {
      "name": "Arc",
      "executable": "...",
      "profiles": ["Default", "Work"]
    }
  ]
}`}</pre>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </Card>
            </div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
};

export default Home;
