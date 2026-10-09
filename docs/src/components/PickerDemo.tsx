import { useCallback, useEffect, useRef, useState } from "react";
import { Link as LinkIcon, Plus, Copy, Zap, Shield, Search, Bot, Smartphone, MousePointer2 } from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { BrowserTileArt } from "@/components/BrowserTileArt";

const DEMO_BROWSERS = [
  { name: "Chrome", key: "1", kind: "chrome" },
  { name: "Safari", key: "2", kind: "safari" },
  { name: "Work", key: "3", kind: "work" },
  { name: "Personal", key: "4", kind: "personal" },
] as const;

const useReducedMotion = () => {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(() =>
    window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  );

  useEffect(() => {
    const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    const handleChange = (event: MediaQueryListEvent) => {
      setPrefersReducedMotion(event.matches);
    };

    mediaQuery.addEventListener("change", handleChange);
    return () => mediaQuery.removeEventListener("change", handleChange);
  }, []);

  return prefersReducedMotion;
};

const usePageVisibility = () => {
  const [isPageVisible, setIsPageVisible] = useState(() => !document.hidden);

  useEffect(() => {
    const handleVisibilityChange = () => setIsPageVisible(!document.hidden);
    document.addEventListener("visibilitychange", handleVisibilityChange);
    return () =>
      document.removeEventListener("visibilitychange", handleVisibilityChange);
  }, []);

  return isPageVisible;
};

const useElementInView = <T extends Element>(threshold: number) => {
  const elementRef = useRef<T>(null);
  const [isInView, setIsInView] = useState(false);

  useEffect(() => {
    const element = elementRef.current;
    if (!element) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        setIsInView(entry.isIntersecting && entry.intersectionRatio >= threshold);
      },
      { threshold },
    );

    observer.observe(element);
    return () => observer.disconnect();
  }, [threshold]);

  return [elementRef, isInView] as const;
};

export { useReducedMotion };

/* Interactive replica of the picker: plays a click-to-picker sequence once, then responds to P / R / H. */
export const PickerDemo: React.FC = () => {
  const prefersReducedMotion = useReducedMotion();
  const isPageVisible = usePageVisibility();
  const [pickerDemoRef, isPickerDemoInView] =
    useElementInView<HTMLDivElement>(0.35);
  const [isPrivate, setIsPrivate] = useState(false);
  const [isRuleSimulatorOpen, setIsRuleSimulatorOpen] = useState(false);
  const [selectedBrowser, setSelectedBrowser] = useState<string | null>(null);
  const [isRevealed, setIsRevealed] = useState(false);

  const [demoStep, setDemoStep] = useState(0);
  const [userInteracted, setUserInteracted] = useState(false);
  const [pickerDemoComplete, setPickerDemoComplete] = useState(false);
  const shouldResetPickerPlayback = useRef(true);
  const renderedPickerDemoStep = prefersReducedMotion ? 4 : demoStep;

  const completePickerDemo = useCallback(() => {
    shouldResetPickerPlayback.current = false;
    setUserInteracted(true);
    setPickerDemoComplete(true);
    setDemoStep(4);
  }, []);

  useEffect(() => {
    if (
      prefersReducedMotion ||
      pickerDemoComplete ||
      userInteracted
    ) {
      return;
    }

    if (!isPickerDemoInView || !isPageVisible) return;

    shouldResetPickerPlayback.current = true;
    const timers = [
      setTimeout(() => setDemoStep(1), 1000),
      setTimeout(() => setDemoStep(2), 2500),
      setTimeout(() => setDemoStep(3), 2800),
      setTimeout(() => {
        shouldResetPickerPlayback.current = false;
        setDemoStep(4);
        setPickerDemoComplete(true);
      }, 3100),
    ];

    return () => {
      timers.forEach(clearTimeout);
      if (shouldResetPickerPlayback.current) setDemoStep(0);
    };
  }, [
    isPageVisible,
    isPickerDemoInView,
    pickerDemoComplete,
    prefersReducedMotion,
    userInteracted,
  ]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === "p") {
        completePickerDemo();
        setIsPrivate((previous) => {
          const next = !previous;
          toast.info(`Private Mode ${next ? "Enabled" : "Disabled"}`, {
            duration: 1500,
            icon: <Shield className="w-4 h-4" />,
          });
          return next;
        });
      }
      if (e.key.toLowerCase() === "r") {
        completePickerDemo();
        setIsRuleSimulatorOpen((prev) => !prev);
        setSelectedBrowser(null);
      }
      if (e.key.toLowerCase() === "h") {
        completePickerDemo();
        setIsRevealed((previous) => {
          const next = !previous;
          toast.success(
            next ? "URL unshortened successfully!" : "Preview reset",
            {
              duration: 1500,
              icon: <Search className="w-4 h-4" />,
            },
          );
          return next;
        });
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [completePickerDemo]);

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
    <div>
          <div
            className="rounded-[20px] px-6 sm:px-10 py-14 sm:py-16 flex justify-center shadow-[inset_0_0_0_1px_rgba(0,0,0,0.05)] relative overflow-hidden"
            style={{
              background:
                "radial-gradient(1200px 500px at 30% 0%, #cfe3ff 0%, transparent 60%), radial-gradient(900px 500px at 80% 100%, #ffd9c8 0%, transparent 55%), linear-gradient(160deg, #e8ecf4 0%, #dde5f0 100%)",
            }}
          >
            <div
              ref={pickerDemoRef}
              className="relative flex justify-center w-full h-[290px]"
              onMouseEnter={completePickerDemo}
              onClick={completePickerDemo}
            >
              {/* Mock chat message with the link being clicked */}
              <div
                className={cn(
                  "absolute top-2 left-1/2 -translate-x-1/2 w-full max-w-[320px] bg-white/70 border border-black/5 rounded-2xl p-4 flex flex-col gap-3 shadow-sm transition-[transform,opacity,filter] ease-[var(--ease-out)] origin-bottom motion-reduce:translate-y-0 motion-reduce:scale-100 motion-reduce:blur-none motion-reduce:transition-opacity",
                  userInteracted
                    ? "duration-[var(--duration-ui)]"
                    : "duration-[var(--duration-marketing)]",
                  renderedPickerDemoStep >= 4
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
                      "text-primary text-sm cursor-pointer transition-colors duration-[var(--duration-ui)] ease-[var(--ease-out)]",
                      renderedPickerDemoStep === 2 || renderedPickerDemoStep === 3
                        ? "underline bg-primary/10 rounded px-1"
                        : "hover:underline",
                    )}
                  >
                    https://t.co/3x8qA9L
                  </span>
                </div>

                {/* Animated mouse cursor */}
                {!userInteracted && !prefersReducedMotion && (
                  <div
                    className="absolute inset-0 pointer-events-none z-50 origin-top-left"
                    style={{
                      transform:
                        renderedPickerDemoStep === 0
                          ? "translate3d(80%, 150%, 0)"
                          : "translate3d(40%, 70%, 0)",
                      transitionDuration:
                        renderedPickerDemoStep === 1
                          ? "1500ms"
                          : "var(--duration-press)",
                      transitionProperty: "transform",
                      transitionTimingFunction:
                        renderedPickerDemoStep === 1
                          ? "var(--ease-in-out)"
                          : "var(--ease-out)",
                    }}
                  >
                    <MousePointer2
                      className={cn(
                        "w-6 h-6 fill-white text-foreground drop-shadow-[0_4px_4px_rgba(0,0,0,0.35)] transition-transform duration-[var(--duration-press)] ease-[var(--ease-out)]",
                        renderedPickerDemoStep === 3
                          ? "scale-[0.97]"
                          : "scale-100",
                      )}
                    />
                  </div>
                )}
              </div>

              {/* Soft glow behind panel */}
              <div
                className={cn(
                  "absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-[20%] w-full max-w-[420px] h-[200px] bg-primary/20 blur-[90px] -z-0 transition-[transform,opacity] ease-[var(--ease-out)] motion-reduce:transition-opacity",
                  userInteracted
                    ? "duration-[var(--duration-ui)]"
                    : "duration-[var(--duration-marketing)]",
                  renderedPickerDemoStep >= 4
                    ? "opacity-100 scale-100"
                    : "opacity-0 scale-50",
                )}
              />

              {/* The Chowser picker panel — frosted white */}
              <div
                className={cn(
                  "flex flex-col w-full max-w-[380px] sm:max-w-[480px] mx-auto rounded-[18px] absolute origin-center overflow-hidden transition-[transform,opacity] ease-[var(--ease-out)] motion-reduce:transition-opacity backdrop-blur-[30px] shadow-[0_30px_70px_rgba(20,30,60,0.25),inset_0_0_0_1px_rgba(255,255,255,0.6)]",
                  userInteracted
                    ? "duration-[var(--duration-ui)]"
                    : "duration-[var(--duration-marketing)]",
                  isPrivate
                    ? "bg-[#eef1ff]/85 ring-1 ring-primary/15"
                    : "bg-white/72",
                  renderedPickerDemoStep >= 4
                    ? "opacity-100 scale-100 top-1/2 -translate-y-1/2"
                    : "opacity-0 scale-90 top-1/2 -translate-y-[42%] pointer-events-none",
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

                {/* Body: browser bar and rule simulator share one interruptible layer */}
                <div className="relative min-h-[140px] grid items-center justify-items-center">
                  <div
                    aria-hidden={!isRuleSimulatorOpen}
                    inert={!isRuleSimulatorOpen}
                    className={cn(
                      "col-start-1 row-start-1 flex flex-col items-center gap-4 px-6 text-center transition-[opacity,filter] duration-[var(--duration-ui)] ease-[var(--ease-in-out)] motion-reduce:blur-none",
                      isRuleSimulatorOpen
                        ? "opacity-100 blur-none pointer-events-auto"
                        : "opacity-0 blur-[2px] pointer-events-none",
                    )}
                  >
                      <div className="p-3 rounded-full bg-primary/10 border border-primary/20">
                        <Zap className="w-6 h-6 text-primary animate-pulse motion-reduce:animate-none" />
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
                        {DEMO_BROWSERS.map((browser) => (
                          <button
                            key={browser.name}
                            onClick={() => handleBrowserSelect(browser.name)}
                            className="transition-transform duration-[var(--duration-press)] ease-[var(--ease-out)] hover:scale-105 active:scale-[0.97] motion-reduce:transform-none"
                            title={browser.name}
                          >
                            <BrowserTileArt kind={browser.kind} size={40} />
                          </button>
                        ))}
                      </div>
                  </div>

                  <div
                    aria-hidden={isRuleSimulatorOpen}
                    inert={isRuleSimulatorOpen}
                    className={cn(
                      "col-start-1 row-start-1 flex items-start justify-center gap-6 sm:gap-7 px-5 py-7 w-full transition-[opacity,filter] duration-[var(--duration-ui)] ease-[var(--ease-in-out)] motion-reduce:blur-none",
                      isRuleSimulatorOpen
                        ? "opacity-0 blur-[2px] pointer-events-none"
                        : "opacity-100 blur-none pointer-events-auto",
                    )}
                  >
                      {DEMO_BROWSERS.map((browser, i) => (
                        <div
                          key={browser.name}
                          className="flex flex-col items-center gap-2"
                        >
                          <div
                            className={cn(
                              "p-[5px] rounded-[19px] relative transition-[transform,background-color,box-shadow] duration-[var(--duration-ui)] ease-[var(--ease-out)]",
                              selectedBrowser === browser.name ||
                                (!selectedBrowser && i === 0)
                                ? "bg-black/[0.06] ring-1 ring-black/10 scale-105"
                                : "bg-transparent",
                            )}
                          >
                            <BrowserTileArt kind={browser.kind} />
                            <span className="absolute -bottom-1 -right-1 z-20 text-[10px] font-bold font-mono text-white bg-[#1d1d1f] rounded-md px-1.5 py-0.5 leading-none shadow-md">
                              {browser.key}
                            </span>
                          </div>
                          <span
                            className={cn(
                              "text-[11px] font-medium transition-colors",
                              selectedBrowser === browser.name ||
                                (!selectedBrowser && i === 0)
                                ? "text-foreground"
                                : "text-muted-foreground",
                            )}
                          >
                            {browser.name}
                          </span>
                        </div>
                      ))}
                  </div>
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
                    <span className="text-[11px] font-medium text-muted-foreground">
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
                    <span className="text-[11px] font-medium text-muted-foreground">
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
                    <span className="text-[11px] font-medium text-muted-foreground flex items-center gap-1">
                      <Search className="w-2.5 h-2.5" />{" "}
                      {isRevealed ? "Revealed" : "Reveal"}
                    </span>
                  </div>
                  <div className="flex-1 min-w-[20px]" />
                  <div className="flex items-center gap-1.5 shrink-0">
                    <kbd className="keycap keycap-active text-[10px] px-1.5 py-0.5">
                      ↵
                    </kbd>
                    <span className="text-[11px] font-medium text-primary">
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
    </div>
  );
};
