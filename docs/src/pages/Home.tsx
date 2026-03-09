import { useState, useEffect } from "react";
import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import {
  Download,
  Eye,
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
  MousePointer2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

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

  const APP_STORE_URL = "https://apps.apple.com/app/chowser/id6741527291";

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

      <main className="relative pt-28 sm:pt-40 pb-20 px-4 flex flex-col items-center">
        {/* Background Blobs */}
        <div className="absolute top-0 inset-x-0 h-[500px] bg-gradient-to-b from-primary/10 to-transparent blur-3xl -z-10 opacity-50" />

        <div className="text-center max-w-4xl mx-auto z-10 w-full flex flex-col items-center text-white">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-border/50 bg-muted/40 text-[10px] sm:text-xs font-medium text-muted-foreground mb-8 animate-in fade-in slide-in-from-bottom-4 duration-1000">
            <span className="flex h-2 w-2 relative">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary/75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
            </span>
            macOS 13.0+ · Professional Browser Chooser
          </div>

          {/* H1 */}
          <h1 className="text-4xl sm:text-7xl font-extrabold tracking-tighter text-transparent bg-clip-text bg-gradient-to-br from-white via-zinc-200 to-zinc-500 mb-6 animate-in fade-in slide-in-from-bottom-4 duration-1000 delay-200 leading-[1.1]">
            Take Control of
            <br className="hidden sm:block" /> Your Links
          </h1>

          {/* Subtext */}
          <p className="text-base sm:text-xl text-muted-foreground mb-10 max-w-2xl mx-auto leading-relaxed animate-in fade-in slide-in-from-bottom-4 duration-1000 delay-200">
            A keyboard-first browser chooser with profiles, private mode,
            app-based routing, and smart rules. Pick the right browser for every
            link — automatically or in one keystroke.
          </p>

          {/* CTAs */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 animate-in fade-in slide-in-from-bottom-4 duration-1000 delay-300 w-full sm:w-auto px-4 sm:px-0">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="w-full sm:w-auto"
            >
              <Button
                id="download"
                size="lg"
                className="w-full h-14 sm:h-16 px-8 bg-primary hover:bg-primary/90 text-white rounded-2xl font-bold text-base sm:text-lg transition-all duration-300 transform hover:scale-[1.02] shadow-[0_0_30px_-5px_var(--color-primary)]/40 gap-3 group"
              >
                <Download className="w-5 h-5 group-hover:-translate-y-1 transition-transform" />
                Download on the App Store
              </Button>
            </a>
            <a href="#agentic-setup" className="w-full sm:w-auto">
              <Button
                size="lg"
                variant="outline"
                className="w-full h-14 sm:h-16 px-8 bg-white/5 hover:bg-white/10 border-white/10 backdrop-blur-md rounded-2xl font-bold text-base sm:text-lg transition-all text-white gap-2"
              >
                <Zap className="w-4 h-4 text-primary" />
                AI Setup
              </Button>
            </a>
          </div>

          {/* Interactive Demo Toggle */}
          <div className="mt-12 animate-in fade-in duration-1000 delay-500">
            <button
              onClick={() => setIsPrivate(!isPrivate)}
              className={cn(
                "flex items-center gap-2.5 px-5 py-2.5 rounded-full border transition-all duration-500 font-medium text-sm",
                isPrivate
                  ? "bg-purple-500/10 border-purple-500/30 text-purple-400 shadow-[0_0_20px_-5px_rgba(168,85,247,0.3)]"
                  : "bg-muted/30 border-border/50 text-muted-foreground hover:text-foreground hover:bg-muted/50",
              )}
            >
              <Eye className={cn("w-4 h-4", isPrivate && "animate-pulse")} />
              {isPrivate ? "Private Mode Active" : "Try Private Mode"}
            </button>
          </div>
        </div>

        {/* Simulated Link Click & Unified Panel Mockup */}
        <div
          className="mt-16 sm:mt-32 z-10 w-full relative flex justify-center h-[280px]"
          onMouseEnter={() => setUserInteracted(true)}
          onClick={() => setUserInteracted(true)}
        >
          {/* Mock Background / Chat Message */}
          <div
            className={cn(
              "absolute top-4 left-1/2 -translate-x-1/2 w-full max-w-[320px] bg-white/[0.03] border border-white/10 rounded-2xl p-4 flex flex-col gap-3 transition-all duration-1000 origin-bottom",
              demoStep >= 4
                ? "opacity-20 scale-95 blur-sm translate-y-[-20px]"
                : "opacity-100 scale-100 blur-none translate-y-0",
            )}
          >
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-blue-500/20 flex items-center justify-center shrink-0">
                <Bot className="w-4 h-4 text-blue-400" />
              </div>
              <div className="space-y-1">
                <div className="text-xs font-bold text-white/80">
                  Teammate{" "}
                  <span className="text-[10px] text-white/30 font-normal ml-1">
                    Today at 2:00 PM
                  </span>
                </div>
                <div className="text-sm text-white/90">
                  Hey, can you review this PR?
                </div>
              </div>
            </div>
            <div className="pl-11">
              <span
                className={cn(
                  "text-blue-400 text-sm hover:underline cursor-pointer transition-colors duration-300",
                  demoStep === 2 || demoStep === 3
                    ? "text-blue-300 underline bg-blue-500/10 rounded px-1"
                    : "",
                )}
              >
                https://t.co/3x8qA9L
              </span>
            </div>

            {/* Animated Mouse Cursor */}
            {!userInteracted && (
              <div
                className="absolute pointer-events-none z-50 text-white drop-shadow-xl transition-all"
                style={{
                  left: demoStep === 0 ? "80%" : demoStep >= 1 ? "40%" : "80%",
                  top: demoStep === 0 ? "150%" : demoStep >= 1 ? "70%" : "150%",
                  transitionDuration: demoStep === 1 ? "1.5s" : "0.3s",
                  transitionProperty: "all",
                  transitionTimingFunction: "ease-out",
                  transform: demoStep === 3 ? "scale(0.8)" : "scale(1)",
                }}
              >
                <MousePointer2 className="w-6 h-6 fill-black drop-shadow-[0_4px_4px_rgba(0,0,0,0.5)]" />
              </div>
            )}
          </div>

          {/* Shadow behind panel */}
          <div
            className={cn(
              "absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-[20%] w-full max-w-[400px] h-[180px] bg-primary/20 blur-[100px] -z-10 transition-all duration-1000",
              demoStep >= 4 ? "opacity-100 scale-100" : "opacity-0 scale-50",
            )}
          />

          {/* The Chowser Panel */}
          <div
            className={cn(
              "flex flex-col w-full max-w-[340px] sm:max-w-[380px] mx-auto rounded-[24px] border border-white/10 absolute origin-center overflow-hidden transition-all duration-700 shadow-2xl backdrop-blur-[32px]",
              isPrivate
                ? "bg-purple-950/40 border-purple-500/20"
                : "bg-black/80",
              demoStep >= 4
                ? "opacity-100 scale-100 translate-y-0"
                : "opacity-0 scale-90 translate-y-8 pointer-events-none",
            )}
          >
            {/* Header: URL Bubble */}
            <div className="flex items-center gap-2 px-4 py-3 border-b border-white/5 bg-white/5">
              <LinkIcon className="w-3.5 h-3.5 shrink-0 opacity-40 text-white" />
              <span className="text-[13px] font-medium text-white/90 flex-1 truncate">
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
              <div className="flex items-center gap-2">
                <Plus
                  className={cn(
                    "w-3.5 h-3.5 opacity-40 text-white cursor-pointer hover:opacity-100 transition-opacity",
                    isRuleSimulatorOpen &&
                    "text-primary opacity-100 animate-pulse",
                  )}
                  onClick={() => setIsRuleSimulatorOpen(!isRuleSimulatorOpen)}
                />
                <Copy
                  className="w-3.5 h-3.5 opacity-40 text-white cursor-pointer hover:opacity-100 transition-opacity"
                  onClick={handleCopy}
                />
              </div>
            </div>

            {/* Main Body: Browser Bar / Rule Simulator */}
            <div className="relative min-h-[140px] flex items-center justify-center">
              {isRuleSimulatorOpen ? (
                <div className="flex flex-col items-center gap-4 px-6 text-center animate-in fade-in slide-in-from-top-4 duration-500">
                  <div className="p-3 rounded-full bg-primary/10 border border-primary/20">
                    <Zap className="w-6 h-6 text-primary animate-pulse" />
                  </div>
                  <div className="space-y-1">
                    <p className="text-sm font-bold text-white">
                      {selectedBrowser
                        ? "Rule Created!"
                        : "Select Default Browser"}
                    </p>
                    <p className="text-[11px] text-white/40">
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
                          "w-10 h-10 rounded-xl flex items-center justify-center text-white transition-all hover:scale-110 active:scale-95 shadow-lg",
                          browser.color,
                        )}
                      >
                        {browser.icon}
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="flex items-start justify-center gap-4 px-4 py-6 w-full">
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
                      icon: <Shield className="w-5 h-5 opacity-40" />,
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
                            ? "bg-white/15 ring-1 ring-white/20 scale-105"
                            : "hover:bg-white/10",
                        )}
                      >
                        <div
                          className={cn(
                            "w-[40px] h-[40px] rounded-xl flex items-center justify-center text-white shadow-xl transition-transform duration-300 group-hover/browser:scale-110",
                            browser.color,
                          )}
                        >
                          {browser.icon}
                        </div>
                        <span className="absolute -bottom-1 -right-1 z-20 text-[10px] font-bold font-mono text-white/70 bg-black/80 border border-white/10 rounded-md px-1.5 py-0.5 leading-none shadow-sm">
                          {browser.key}
                        </span>
                      </div>
                      <span
                        className={cn(
                          "text-[11px] font-medium transition-colors",
                          selectedBrowser === browser.name ||
                            (!selectedBrowser && i === 0)
                            ? "text-white"
                            : "text-white/40 group-hover/browser:text-white/80",
                        )}
                      >
                        {browser.name}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Footer: Keyboard Hints */}
            <div className="flex items-center gap-2.5 w-full px-4 py-2.5 border-t border-white/5 bg-black/40 overflow-x-auto">
              <div
                className={cn(
                  "flex items-center gap-1.5 shrink-0 transition-opacity",
                  isPrivate ? "opacity-100" : "opacity-30",
                )}
              >
                <kbd
                  className={cn(
                    "text-[10px] font-bold font-mono text-white border border-white/10 rounded-[4px] px-1.5 py-0.5",
                    isPrivate ? "bg-purple-500/50" : "bg-white/10",
                  )}
                >
                  P
                </kbd>
                <span className="text-[9px] font-bold text-white tracking-widest uppercase">
                  Private
                </span>
              </div>
              <div
                className={cn(
                  "flex items-center gap-1.5 shrink-0 transition-opacity",
                  isRuleSimulatorOpen || selectedBrowser
                    ? "opacity-100"
                    : "opacity-30",
                )}
              >
                <kbd
                  className={cn(
                    "text-[10px] font-bold font-mono text-white border border-white/10 rounded-[4px] px-1.5 py-0.5",
                    isRuleSimulatorOpen || selectedBrowser
                      ? "bg-amber-500/50"
                      : "bg-white/10",
                  )}
                >
                  R
                </kbd>
                <span className="text-[9px] font-bold text-white tracking-widest uppercase">
                  {isRuleSimulatorOpen ? "Active" : "Rule"}
                </span>
              </div>
              <div
                className={cn(
                  "flex items-center gap-1.5 shrink-0 transition-opacity",
                  isRevealed ? "opacity-100" : "opacity-30",
                )}
              >
                <kbd
                  className={cn(
                    "text-[10px] font-bold font-mono text-white border border-white/10 rounded-[4px] px-1.5 py-0.5 shadow-[0_0_10px_rgba(59,130,246,0.2)]",
                    isRevealed ? "bg-blue-500/50" : "bg-white/10",
                  )}
                >
                  H
                </kbd>
                <span className="text-[9px] font-bold text-white tracking-widest uppercase flex items-center gap-1">
                  <Search className="w-2.5 h-2.5" />{" "}
                  {isRevealed ? "Revealed" : "Reveal"}
                </span>
              </div>
              <div className="flex-1 min-w-[20px]" />
              <div className="flex items-center gap-1.5 shrink-0">
                <kbd className="text-[10px] font-bold font-mono text-white bg-primary rounded-[4px] px-1.5 py-0.5 shadow-[0_0_10px_rgba(59,130,246,0.5)]">
                  ↵
                </kbd>
                <span className="text-[9px] font-bold text-primary tracking-widest uppercase">
                  Launch
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Feature Grid */}
        <section className="container mx-auto px-4 mt-20 max-w-6xl z-10">
          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-8">
            <Card className="bg-card/40 border-border/50 p-8 transition-all hover:bg-card/60 hover:scale-[1.02] group backdrop-blur-sm">
              <Badge
                variant="outline"
                className="mb-4 border-primary/20 text-primary"
              >
                Powerful
              </Badge>
              <h3 className="text-xl font-bold text-foreground mb-3 font-sans">
                Profile Support
              </h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Professional support for Multi-Profile across Chrome, Brave,
                Arc, and Firefox. Keep work and personal separate.
              </p>
            </Card>
            <Card className="bg-card/40 border-border/50 p-8 transition-all hover:bg-card/60 hover:scale-[1.02] group backdrop-blur-sm">
              <Badge
                variant="outline"
                className="mb-4 border-green-500/20 text-green-500"
              >
                Fast
              </Badge>
              <h3 className="text-xl font-bold text-foreground mb-3 font-sans">
                Keyboard First
              </h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Launch any browser with a single shortcut key. No mouse required
                for lightning-fast link routing.
              </p>
            </Card>
            <Card className="bg-card/40 border-border/50 p-8 transition-all hover:bg-card/60 hover:scale-[1.02] group backdrop-blur-sm">
              <Badge
                variant="outline"
                className="mb-4 border-amber-500/20 text-amber-500"
              >
                Secure
              </Badge>
              <h3 className="text-xl font-bold text-foreground mb-3 font-sans">
                Master-Detail Rules
              </h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                A powerful redesigned rules manager with browser-based grouping.
                Easily organize and edit complex routing logic in a sleek master-detail layout.
              </p>
            </Card>

            <Card className="bg-card/40 border-border/50 p-8 transition-all hover:bg-card/60 hover:scale-[1.02] group backdrop-blur-sm">
              <Badge
                variant="outline"
                className="mb-4 border-blue-500/20 text-blue-500"
              >
                Workflow
              </Badge>
              <h3 className="text-xl font-bold text-foreground mb-3 font-sans">
                Focus Mode
              </h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Temporarily route all clicked links to a specific browser for 1
                Hour or Until Tomorrow right from the menu bar.
              </p>
            </Card>
            <Card className="bg-card/40 border-border/50 p-8 transition-all hover:bg-card/60 hover:scale-[1.02] group backdrop-blur-sm">
              <Badge
                variant="outline"
                className="mb-4 border-purple-500/20 text-purple-500"
              >
                Privacy
              </Badge>
              <h3 className="text-xl font-bold text-foreground mb-3 font-sans">
                URL Unshortener
              </h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Automatically shreds tracking parameters and actively resolves
                shortlinks (like bit.ly) before routing them.
              </p>
            </Card>
            <Card className="bg-card/40 border-border/50 p-8 transition-all hover:bg-card/60 hover:scale-[1.02] group backdrop-blur-sm">
              <Badge
                variant="outline"
                className="mb-4 border-teal-500/20 text-teal-500"
              >
                Automation
              </Badge>
              <h3 className="text-xl font-bold text-foreground mb-3 font-sans">
                Instant Rules
              </h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Create rules straight from the picker with one key (`R`).
                Recent URLs can be converted into permanent rules instantly with pre-filled patterns.
              </p>
            </Card>
          </div>
        </section>

        {/* AI Setup Section */}
        <section
          id="agentic-setup"
          className="container mx-auto px-4 mt-32 max-w-4xl z-10 scroll-mt-32"
        >
          <header className="text-center space-y-6 mb-16 animate-in fade-in slide-in-from-bottom-4 duration-1000">
            <Badge
              variant="outline"
              className="bg-primary/10 border-primary/20 text-primary gap-1.5 py-1 px-3"
            >
              <Sparkles className="w-3 h-3" />
              AI-Enhanced Setup
            </Badge>
            <h2 className="text-3xl md:text-5xl font-extrabold tracking-tight text-foreground">
              Let AI Configure Chowser
            </h2>
            <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
              Automate your browser profile discovery and rule generation. Paste
              the prompt into Claude, ChatGPT, or Cursor to get started.
            </p>
          </header>

          <div className="grid gap-8">
            {/* Step 1 */}
            <div className="relative group">
              <div className="absolute -left-4 top-0 w-8 h-8 rounded-full bg-primary flex items-center justify-center font-bold text-primary-foreground z-10 hidden md:flex shadow-lg">
                1
              </div>
              <Card className="bg-card/50 border-border/50 overflow-hidden relative transition-all hover:bg-card/60 flex flex-col lg:flex-row">
                <div className="p-6 sm:p-8 flex-1 space-y-4 sm:space-y-6 relative z-10">
                  <h3 className="text-xl sm:text-2xl font-bold flex items-center gap-2">
                    <Terminal className="w-5 h-5 text-primary" />
                    Run Terminal Command
                  </h3>
                  <p className="text-muted-foreground text-sm sm:text-base max-w-md">
                    This command fetches the full setup prompt and pipes it
                    straight to your clipboard.
                  </p>

                  <div className="group/code relative max-w-lg">
                    <pre className="bg-black/60 p-4 rounded-xl font-mono text-[13px] border border-white/10 text-white overflow-x-auto shadow-inner">
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
                      className="absolute right-2 top-2 opacity-0 group-hover/code:opacity-100 transition-opacity bg-white/10 hover:bg-white/20 text-white border-0"
                    >
                      <Copy className="w-3 h-3 mr-2" />
                      Copy Prompt
                    </Button>
                  </div>
                </div>
                {/* AI Agent Animation Panel (Redesigned) */}
                <div className="hidden lg:flex w-80 bg-black/80 border-l border-white/5 relative items-center justify-center p-6 shrink-0 z-0">
                  <div className="w-full h-36 bg-purple-950/20 border border-purple-500/30 rounded-xl overflow-hidden shadow-[0_0_30px_-10px_rgba(168,85,247,0.4)] font-mono text-[11px] flex flex-col backdrop-blur-sm">
                    <div className="flex items-center gap-1.5 px-3 py-2 bg-purple-500/10 border-b border-purple-500/20">
                      <Sparkles className="w-3 h-3 text-purple-400" />
                      <span className="text-white/70 font-sans text-[10px] font-medium">
                        Your AI Agent
                      </span>
                    </div>
                    <div className="p-3 space-y-2 text-white/80 flex-1 relative">
                      <div className="flex items-start gap-2">
                        <div className="shrink-0 w-4 h-4 rounded bg-purple-500/20 flex items-center justify-center">
                          <Bot className="w-3 h-3 text-purple-400" />
                        </div>
                        <div className="relative flex-1 min-w-0">
                          <div className="flex flex-col gap-1.5 text-white/90">
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
                                "h-px bg-purple-500/20 transition-all duration-700",
                                aiDemoStep >= 2 ? "w-full" : "w-0",
                              )}
                            />
                            <span
                              className="text-[9px] text-purple-300/60 italic"
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
                        <Sparkles className="w-3.5 h-3.5 text-purple-400 animate-pulse" />
                      </div>
                    </div>
                  </div>
                </div>
              </Card>
            </div>

            {/* Step 2 */}
            <div className="relative group">
              <div className="absolute -left-4 top-0 w-8 h-8 rounded-full bg-primary flex items-center justify-center font-bold text-primary-foreground z-10 hidden md:flex shadow-lg">
                2
              </div>
              <Card className="bg-card/50 border-border/50 overflow-hidden relative transition-all hover:bg-card/60 flex flex-col lg:flex-row">
                <div className="p-6 sm:p-8 flex-1 space-y-4 sm:space-y-6 relative z-10">
                  <h3 className="text-xl sm:text-2xl font-bold flex items-center gap-2">
                    <Wand2 className="w-5 h-5 text-purple-400" />
                    Paste to AI Assistant
                  </h3>
                  <p className="text-muted-foreground text-sm sm:text-base leading-relaxed max-w-md">
                    Open your AI assistant (e.g., Cursor Composer, Claude, or
                    ChatGPT) and paste the content. The AI will then:
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
                {/* AI Chat Animation Panel */}
                <div className="hidden lg:flex w-[26rem] bg-black/40 border-l border-white/5 relative items-center justify-center p-6 shrink-0 z-0">
                  <div className="w-full bg-[#18181b]/95 border border-white/10 rounded-xl overflow-hidden shadow-2xl flex flex-col h-64 relative">
                    <div className="p-3 bg-black/40 border-b border-white/5 flex items-center gap-2">
                      <Wand2 className="w-4 h-4 text-purple-400" />
                      <span className="text-xs font-medium text-white/80">
                        Composer
                      </span>
                    </div>
                    <div className="p-4 flex-1 overflow-y-auto space-y-4 text-[11px] no-scrollbar">
                      {/* User Message */}
                      <div
                        className={cn(
                          "flex justify-end transition-all duration-500",
                          aiDemoStep >= 3
                            ? "opacity-100 translate-y-0"
                            : "opacity-0 translate-y-4",
                        )}
                      >
                        <div className="bg-primary/20 text-white/90 px-3 py-2.5 rounded-xl max-w-[85%] rounded-tr-sm border border-primary/20 shadow-sm relative">
                          <div className="flex items-center gap-1.5 opacity-50 mb-1">
                            <Terminal className="w-3 h-3" />
                            <span className="text-[9px] uppercase tracking-wider font-bold">
                              Pasted Script
                            </span>
                          </div>
                          <div className="text-white/70 line-clamp-2 italic">
                            "You are an expert macOS configuration assistant.
                            Help me configure..."
                          </div>
                        </div>
                      </div>
                      {/* AI Message */}
                      <div
                        className={cn(
                          "flex justify-start transition-all duration-500",
                          aiDemoStep >= 4
                            ? "opacity-100 translate-y-0"
                            : "opacity-0 translate-y-4",
                        )}
                      >
                        <div className="bg-black/40 text-white/90 px-3 py-3 rounded-xl max-w-[95%] rounded-tl-sm border border-white/10 space-y-3 shadow-md">
                          <div className="flex items-center gap-2 text-purple-400">
                            <Bot className="w-3.5 h-3.5" />
                            <span className="font-medium text-[10px]">
                              Analyzing browsers...
                            </span>
                            {aiDemoStep === 4 && (
                              <span className="flex gap-0.5 ml-1">
                                <span className="w-1 h-1 bg-purple-400 rounded-full animate-bounce delay-75" />
                                <span
                                  className="w-1 h-1 bg-purple-400 rounded-full animate-bounce delay-150"
                                  style={{ animationDelay: "150ms" }}
                                />
                                <span
                                  className="w-1 h-1 bg-purple-400 rounded-full animate-bounce delay-300"
                                  style={{ animationDelay: "300ms" }}
                                />
                              </span>
                            )}
                          </div>
                          <div
                            className={cn(
                              "bg-[#0d0d0d] p-2.5 rounded-lg border border-white/5 font-mono text-[9px] text-green-400/90 overflow-hidden transition-all duration-700",
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
