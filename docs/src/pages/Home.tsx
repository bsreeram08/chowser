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
  ShieldAlert,
  MousePointer2,
  Settings,
  CheckCircle2,
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

  // Security & AI Setup Animation States
  const [securityStep, setSecurityStep] = useState(0);
  const [aiDemoStep, setAiDemoStep] = useState(0);

  useEffect(() => {
    const securityInterval = setInterval(() => {
      setSecurityStep((prev) => (prev + 1) % 5);
    }, 2000);
    return () => clearInterval(securityInterval);
  }, []);

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

  const [downloadUrl, setDownloadUrl] = useState(
    "https://github.com/bsreeram08/chowser/releases/latest",
  );
  const [downloadVersion, setDownloadVersion] = useState<string | null>(null);
  const [isLoadingDownload, setIsLoadingDownload] = useState(true);

  useEffect(() => {
    const fetchLatestRelease = async () => {
      try {
        const response = await fetch(
          "https://api.github.com/repos/bsreeram08/chowser/releases/latest",
        );
        const data = await response.json();
        const dmgAsset = data.assets?.find((asset: any) =>
          asset.name.endsWith(".dmg"),
        );
        if (dmgAsset) {
          setDownloadUrl(dmgAsset.browser_download_url);
        }
        if (data.tag_name) {
          // Remove "v" prefix if it exists to just show "3.0.0" etc
          setDownloadVersion(data.tag_name.replace(/^v/, ""));
        }
      } catch (error) {
        console.error("Failed to fetch latest release:", error);
      } finally {
        setIsLoadingDownload(false);
      }
    };
    fetchLatestRelease();
  }, []);

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
              href={downloadUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="w-full sm:w-auto"
            >
              <Button
                id="download"
                size="lg"
                disabled={
                  isLoadingDownload &&
                  downloadUrl ===
                    "https://github.com/bsreeram08/chowser/releases/latest"
                }
                className="w-full h-14 sm:h-16 px-8 bg-primary hover:bg-primary/90 text-white rounded-2xl font-bold text-base sm:text-lg transition-all duration-300 transform hover:scale-[1.02] shadow-[0_0_30px_-5px_var(--color-primary)]/40 gap-3 group"
              >
                <Download className="w-5 h-5 group-hover:-translate-y-1 transition-transform" />
                {isLoadingDownload
                  ? "Finding Latest..."
                  : `Download ${downloadVersion ? `v${downloadVersion}` : ""} for Mac`}
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
                Smart Rules
              </h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Define complex rules using exact or wildcard domain matching.
                Always open the right app for the right task.
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
                Quick Rules
              </h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Hold Option (⌥) while viewing your Recent URLs to instantly
                pre-fill and create a new permanent routing rule.
              </p>
            </Card>
          </div>
        </section>

        {/* Security Setup Section */}
        <section
          id="security-setup"
          className="container mx-auto px-4 mt-32 max-w-4xl z-10 scroll-mt-32"
        >
          <header className="text-center space-y-6 mb-12 animate-in fade-in slide-in-from-bottom-4 duration-1000">
            <Badge
              variant="destructive"
              className="bg-destructive/10 border-destructive/20 text-destructive gap-1.5 py-1 px-3"
            >
              <ShieldAlert className="w-3 h-3" />
              Bypass macOS Gatekeeper
            </Badge>
            <h2 className="text-3xl md:text-4xl font-extrabold tracking-tight text-foreground leading-tight">
              Install & Allow Chowser
            </h2>
            <p className="text-muted-foreground text-lg max-w-2xl mx-auto leading-relaxed">
              Chowser is a professional tool currently in a pre-release state
              and is unsigned. Follow these steps to allow it on your Mac.
            </p>
          </header>

          <div className="space-y-6">
            <div className="grid gap-6">
              <div className="flex flex-col sm:flex-row gap-4 sm:gap-6 group">
                <div className="flex sm:flex-col items-center">
                  <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-muted border border-border/50 flex items-center justify-center text-xs sm:text-sm font-bold shrink-0 group-hover:border-primary/50 transition-colors">
                    1
                  </div>
                  <div className="hidden sm:block w-px flex-1 bg-border/20 my-4" />
                </div>
                <Card className="flex-1 bg-card/40 border-border/50 p-6 sm:p-8 transition-colors hover:bg-card/60 flex flex-col md:flex-row gap-8 items-center md:items-start relative overflow-hidden">
                  <div className="flex flex-col sm:flex-row items-start gap-4 flex-1">
                    <div className="p-3 rounded-xl bg-blue-500/10 text-blue-500 border border-blue-500/20 shrink-0">
                      <MousePointer2 className="w-5 h-5 sm:w-6 sm:h-6" />
                    </div>
                    <div className="space-y-2 relative z-10 w-full md:w-auto">
                      <h3 className="text-lg sm:text-xl font-bold text-foreground">
                        Right-click to Open
                      </h3>
                      <p className="text-muted-foreground text-sm leading-relaxed max-w-sm">
                        Drag Chowser to your{" "}
                        <span className="text-foreground">Applications</span>{" "}
                        folder. Hold the{" "}
                        <kbd className="bg-muted px-1.5 py-0.5 rounded border border-border/50 font-mono text-[10px] sm:text-xs">
                          Control
                        </kbd>{" "}
                        key and click the app icon, then select{" "}
                        <strong>Open</strong> from the menu.
                      </p>
                    </div>
                  </div>
                  {/* Animation */}
                  <div className="hidden md:flex w-full md:w-72 h-40 bg-black/40 border border-white/5 rounded-2xl relative items-center justify-center shrink-0 overflow-hidden group-hover:bg-black/60 transition-colors">
                    {/* App Icon */}
                    <div
                      className={cn(
                        "w-14 h-14 bg-gradient-to-br from-blue-500/20 to-purple-500/20 rounded-2xl border border-white/10 flex items-center justify-center shadow-lg transition-transform duration-300",
                        securityStep === 1 || securityStep === 2
                          ? "scale-105 bg-white/10"
                          : "",
                      )}
                    >
                      <Globe className="w-7 h-7 text-white/80" />
                    </div>
                    {/* Context Menu */}
                    <div
                      className={cn(
                        "absolute top-1/2 left-1/2 ml-4 mt-2 w-40 bg-[#1e1e1e]/95 backdrop-blur-xl border border-white/10 rounded-xl shadow-2xl p-1 text-[11px] origin-top-left transition-all duration-300 z-20",
                        securityStep >= 2 && securityStep <= 4
                          ? "opacity-100 scale-100"
                          : "opacity-0 scale-90 pointer-events-none",
                      )}
                    >
                      <div
                        className={cn(
                          "px-3 py-1.5 rounded-md transition-colors",
                          securityStep >= 3
                            ? "bg-blue-500 text-white shadow-sm"
                            : "text-white/80",
                        )}
                      >
                        Open
                      </div>
                      <div className="px-3 py-1.5 text-white/50">
                        Show Package Contents
                      </div>
                      <div className="px-3 py-1.5 text-white/50">
                        Move to Trash
                      </div>
                    </div>
                    {/* Cursor */}
                    <MousePointer2
                      className={cn(
                        "absolute w-5 h-5 text-white drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)] fill-black z-30 transition-all duration-[800ms] ease-in-out pointer-events-none",
                        securityStep === 0
                          ? "top-[120%] left-[80%]"
                          : securityStep === 1
                            ? "top-1/2 left-1/2 translate-x-2 translate-y-2 scale-95"
                            : securityStep === 2
                              ? "top-1/2 left-1/2 translate-x-3 translate-y-3"
                              : "top-1/2 left-1/2 translate-x-12 translate-y-6 scale-90",
                      )}
                    />
                  </div>
                </Card>
              </div>

              <div className="flex flex-col sm:flex-row gap-4 sm:gap-6 group">
                <div className="flex sm:flex-col items-center">
                  <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-muted border border-border/50 flex items-center justify-center text-xs sm:text-sm font-bold shrink-0 group-hover:border-primary/50 transition-colors">
                    2
                  </div>
                  <div className="hidden sm:block w-px flex-1 bg-border/20 my-4" />
                </div>
                <Card className="flex-1 bg-card/40 border-border/50 p-6 sm:p-8 transition-colors hover:bg-card/60 border-l-amber-500/30 flex flex-col md:flex-row gap-8 items-center md:items-start relative overflow-hidden">
                  <div className="flex flex-col sm:flex-row items-start gap-4 flex-1">
                    <div className="p-3 rounded-xl bg-amber-500/10 text-amber-500 border border-amber-500/20 shrink-0">
                      <Settings className="w-5 h-5 sm:w-6 sm:h-6" />
                    </div>
                    <div className="space-y-2 relative z-10 w-full md:w-auto">
                      <h3 className="text-lg sm:text-xl font-bold text-foreground">
                        System Settings
                      </h3>
                      <p className="text-muted-foreground text-sm leading-relaxed max-w-sm">
                        If macOS blocks it, open{" "}
                        <strong>
                          System Settings &rarr; Privacy & Security
                        </strong>
                        . Scroll down to the Security section and click{" "}
                        <strong>Open Anyway</strong> for Chowser.
                      </p>
                    </div>
                  </div>
                  {/* Animation */}
                  <div className="hidden md:flex w-full md:w-72 h-40 bg-black/40 border border-white/5 rounded-2xl relative items-center justify-center shrink-0 overflow-hidden group-hover:bg-black/60 transition-colors">
                    {/* Fake Settings Modal */}
                    <div className="w-64 bg-[#1e1e1e]/90 backdrop-blur-md rounded-xl border border-white/10 shadow-2xl p-4 flex flex-col gap-3 relative z-10 transform scale-90 sm:scale-100">
                      <div className="flex items-center gap-2 mb-1">
                        <div className="w-3 h-3 rounded-full bg-red-500/80" />
                        <div className="text-[10px] font-medium text-white/50 flex-1 text-center pr-3">
                          Privacy & Security
                        </div>
                      </div>
                      <div className="bg-black/40 border border-white/5 rounded-lg p-3 space-y-3">
                        <p className="text-[10px] text-white/80 leading-snug">
                          "Chowser" was blocked from use because it is not from
                          an identified developer.
                        </p>
                        <div className="flex justify-end pt-1">
                          <div
                            className={cn(
                              "px-3 py-1.5 rounded-md text-[10px] font-medium transition-all duration-300",
                              securityStep >= 3
                                ? "bg-blue-500 text-white shadow-md scale-95"
                                : "bg-white/10 text-white/90 hover:bg-white/20",
                            )}
                          >
                            Open Anyway
                          </div>
                        </div>
                      </div>
                    </div>
                    {/* Cursor */}
                    <MousePointer2
                      className={cn(
                        "absolute w-5 h-5 text-white drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)] fill-black z-30 transition-all duration-[800ms] ease-in-out pointer-events-none",
                        securityStep <= 1
                          ? "top-[120%] right-[10%]"
                          : securityStep === 2
                            ? "top-[65%] right-[18%]"
                            : "top-[65%] right-[18%] scale-90",
                      )}
                    />
                  </div>
                </Card>
              </div>

              <div className="flex flex-col sm:flex-row gap-4 sm:gap-6 group">
                <div className="flex sm:flex-col items-center">
                  <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-muted border border-border/50 flex items-center justify-center text-xs sm:text-sm font-bold shrink-0 group-hover:border-green-500/50 transition-colors text-green-500 leading-none">
                    <CheckCircle2 className="w-4 h-4 sm:w-5 sm:h-5" />
                  </div>
                </div>
                <Card className="flex-1 bg-card/40 border-border/50 p-6 sm:p-8 transition-colors hover:bg-card/60">
                  <div className="flex flex-col sm:flex-row items-start gap-4">
                    <div className="p-3 rounded-xl bg-green-500/10 text-green-500 border border-green-500/20 shrink-0">
                      <CheckCircle2 className="w-5 h-5 sm:w-6 sm:h-6" />
                    </div>
                    <div className="space-y-2">
                      <h3 className="text-lg sm:text-xl font-bold text-foreground">
                        Set as Default
                      </h3>
                      <p className="text-muted-foreground text-sm leading-relaxed">
                        Finally, set Chowser as your system's default browser in{" "}
                        <strong>System Settings &rarr; Desktop & Dock</strong>.
                      </p>
                    </div>
                  </div>
                </Card>
              </div>
            </div>
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
                        curl -s https://chowser.sreerams.in/agentic-setup.md |
                        pbcopy
                      </code>
                    </pre>
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={() => {
                        navigator.clipboard.writeText(
                          "curl -s https://chowser.sreerams.in/agentic-setup.md | pbcopy",
                        );
                        toast.success("Copied to clipboard");
                      }}
                      className="absolute right-2 top-2 opacity-0 group-hover/code:opacity-100 transition-opacity bg-white/10 hover:bg-white/20 text-white border-0"
                    >
                      <Copy className="w-3 h-3 mr-2" />
                      Copy
                    </Button>
                  </div>
                </div>
                {/* Terminal Animation Panel */}
                <div className="hidden lg:flex w-80 bg-black/80 border-l border-white/5 relative items-center justify-center p-6 shrink-0 z-0">
                  <div className="w-full h-36 bg-[#1a1b26]/90 border border-white/10 rounded-xl overflow-hidden shadow-2xl font-mono text-[11px] flex flex-col">
                    <div className="flex items-center gap-1.5 px-3 py-2 bg-black/40 border-b border-white/5">
                      <div className="w-2.5 h-2.5 rounded-full bg-red-500/80" />
                      <div className="w-2.5 h-2.5 rounded-full bg-amber-500/80" />
                      <div className="w-2.5 h-2.5 rounded-full bg-green-500/80" />
                      <span className="ml-2 text-white/30 font-sans text-[10px]">
                        zsh
                      </span>
                    </div>
                    <div className="p-3 space-y-2 text-white/80 flex-1 relative">
                      <div className="flex items-start gap-2">
                        <span className="text-green-400 shrink-0">➜</span>
                        <span className="text-blue-400 shrink-0">~</span>
                        <div className="relative flex-1 min-w-0">
                          <div className="flex flex-wrap items-center text-white/90">
                            <span
                              className="overflow-hidden whitespace-nowrap inline-block align-bottom"
                              style={{
                                width: aiDemoStep >= 1 ? "100%" : "0%",
                                transition:
                                  aiDemoStep >= 1
                                    ? "width 1s steps(40, end)"
                                    : "none",
                              }}
                            >
                              curl -s https://chowser... | pbcopy
                            </span>
                            <span
                              className={cn(
                                "inline-block w-1 h-3.5 bg-white/70 ml-0.5",
                                aiDemoStep >= 2 ? "hidden" : "animate-pulse",
                              )}
                            />
                          </div>
                        </div>
                      </div>
                      <div
                        className={cn(
                          "text-emerald-400/90 flex items-center gap-1.5 absolute bottom-4 left-3 transition-all duration-300",
                          aiDemoStep >= 2
                            ? "opacity-100 translate-y-0"
                            : "opacity-0 translate-y-2 pointer-events-none",
                        )}
                      >
                        <CheckCircle2 className="w-3 h-3" /> Copied to
                        clipboard.
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
