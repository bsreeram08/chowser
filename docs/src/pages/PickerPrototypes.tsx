import { useState, useEffect } from "react";
import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Card } from "@/components/ui/card";
import { BrowserTileArt, type DemoBrowserKind } from "./Home";
import { Info, MousePointer2, ArrowRight, Sparkles } from "lucide-react";
import { cn } from "@/lib/utils";

const BROWSERS: { name: string; key: string; kind: DemoBrowserKind }[] = [
  { name: "Chrome", key: "1", kind: "chrome" },
  { name: "Safari", key: "2", kind: "safari" },
  { name: "Work", key: "3", kind: "work" },
  { name: "Personal", key: "4", kind: "personal" },
];

const TRACE = [
  { rule: "Strip UTM Tracking", from: "example.com?utm_source=x", to: "example.com" },
  { rule: "Force HTTPS", from: "http://", to: "https://" },
];

const Kbd: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <kbd className="keycap text-[10px] px-1.5 py-0.5 mx-0.5">{children}</kbd>
);

/* Shared mock link-preview card */
const LinkPreview: React.FC = () => (
  <div className="rounded-2xl overflow-hidden border border-black/[0.08] bg-white shadow-sm">
    <div className="h-28 bg-gradient-to-br from-sky-200 via-indigo-200 to-fuchsia-200" />
    <div className="p-4">
      <div className="flex items-center gap-2 mb-1">
        <div className="w-4 h-4 rounded-full bg-emerald-500" />
        <span className="text-[11px] font-mono text-muted-foreground">
          example.com
        </span>
      </div>
      <p className="font-semibold text-[15px] leading-snug text-foreground">
        Building a faster link router for macOS
      </p>
      <p className="text-[12px] text-muted-foreground mt-1 line-clamp-2">
        A short post about routing every clicked link to the right browser —
        and cleaning it up first.
      </p>
    </div>
  </div>
);

const BrowserRow: React.FC = () => (
  <div className="flex items-center gap-2.5 px-3 py-2.5">
    {BROWSERS.map((b) => (
      <div key={b.name} className="flex flex-col items-center gap-1">
        <div className="relative">
          <div className="transition-transform group-hover:scale-105">
            <BrowserTileArt kind={b.kind} size={42} />
          </div>
          <span className="absolute -bottom-1 -right-1 z-20 text-[9px] font-bold font-mono text-white bg-[#1d1d1f] rounded px-1 py-0.5 leading-none shadow">
            {b.key}
          </span>
        </div>
        <span className="text-[10px] text-muted-foreground">{b.name}</span>
      </div>
    ))}
    <div className="ml-auto flex items-center gap-1.5">
      <Kbd>P</Kbd>
      <Kbd>R</Kbd>
      <Kbd>H</Kbd>
    </div>
  </div>
);

const TraceList: React.FC = () => (
  <div className="space-y-1.5 text-[11px] text-muted-foreground">
    {TRACE.map((t) => (
      <div key={t.rule} className="flex items-center gap-1.5">
        <Info className="w-3 h-3 text-primary shrink-0" />
        <span className="font-medium text-foreground/80">{t.rule}</span>
        <ArrowRight className="w-3 h-3 shrink-0" />
        <span className="font-mono truncate">{t.to}</span>
      </div>
    ))}
  </div>
);

/* ── Variant A: Preview-first (trace as footer chip) ── */
const VariantPreviewFirst: React.FC = () => (
  <Card className="overflow-hidden">
    <div className="p-3 bg-white/40">
      <LinkPreview />
    </div>
    <div className="px-4 py-2 border-t border-black/[0.06] bg-primary/[0.03]">
      <TraceList />
    </div>
    <BrowserRow />
  </Card>
);

/* ── Variant B: Side-by-side ── */
const VariantSideBySide: React.FC = () => (
  <Card className="overflow-hidden flex">
    <div className="flex-1 p-3 bg-white/40 border-r border-black/[0.06]">
      <LinkPreview />
      <BrowserRow />
    </div>
    <div className="w-44 p-3 bg-primary/[0.03]">
      <p className="text-[10px] font-semibold uppercase tracking-widest text-muted-foreground mb-2">
        Rewrite trace
      </p>
      <TraceList />
    </div>
  </Card>
);

/* ── Variant C: Trace-as-toast (auto-fades) ── */
const VariantTraceToast: React.FC = () => {
  const [visible, setVisible] = useState(true);
  useEffect(() => {
    const t = setTimeout(() => setVisible(false), 4000);
    return () => clearTimeout(t);
  }, []);
  return (
    <Card className="overflow-hidden relative">
      <div className="p-3 bg-white/40">
        <LinkPreview />
      </div>
      <BrowserRow />
      <div
        className={cn(
          "absolute left-3 right-3 bottom-16 transition-all duration-500",
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-2"
        )}
      >
        <div className="rounded-xl bg-[#1d1d1f] text-white px-3 py-2 shadow-lg">
          <TraceList />
        </div>
      </div>
      <button
        onClick={() => setVisible((v) => !v)}
        className="absolute bottom-2 right-3 text-[10px] text-muted-foreground hover:text-foreground"
      >
        {visible ? "hide trace" : "show trace"}
      </button>
    </Card>
  );
};

const VARIANTS = [
  {
    id: "preview-first",
    label: "Preview-first",
    desc: "Link preview on top; rewrite trace collapses into a thin footer chip that only appears when rules actually fired.",
    node: <VariantPreviewFirst />,
  },
  {
    id: "side-by-side",
    label: "Side-by-side",
    desc: "Preview dominates the left; a slim column on the right holds the rewrite trace.",
    node: <VariantSideBySide />,
  },
  {
    id: "trace-toast",
    label: "Trace-as-toast",
    desc: "Preview dominates; the rewrite trace fades in as a transient bottom strip, then auto-dismisses.",
    node: <VariantTraceToast />,
  },
];

export const PickerPrototypes: React.FC = () => {
  return (
    <div className="bg-background min-h-screen text-foreground font-sans antialiased overflow-x-hidden">
      <Navbar />

      <main className="relative">
        <section className="text-center pt-36 sm:pt-44 pb-8 px-6">
          <span className="eyebrow inline-flex items-center gap-1.5">
            <Sparkles className="w-3 h-3" />
            Lab
          </span>
          <h1 className="font-display font-bold tracking-tight leading-[1.04] text-4xl sm:text-6xl text-foreground mt-4">
            Picker layout prototypes
          </h1>
          <p className="text-muted-foreground text-lg max-w-2xl mx-auto mt-5 leading-relaxed">
            Three ways to place the rewrite trace relative to the link preview.
            Pick a favorite — we'll ship the winner natively.
          </p>
        </section>

        <section className="max-w-xl mx-auto px-6 pb-28">
          <Tabs defaultValue="preview-first">
            <TabsList className="w-full justify-center mb-6">
              {VARIANTS.map((v) => (
                <TabsTrigger key={v.id} value={v.id}>
                  {v.label}
                </TabsTrigger>
              ))}
            </TabsList>
            {VARIANTS.map((v) => (
              <TabsContent key={v.id} value={v.id} className="mt-0">
                <p className="text-center text-[13px] text-muted-foreground mb-4 px-4">
                  {v.desc}
                </p>
                {v.node}
              </TabsContent>
            ))}
          </Tabs>

          <div className="mt-8 flex items-center justify-center gap-2 text-[12px] text-muted-foreground">
            <MousePointer2 className="w-3.5 h-3.5" />
            <span>Try each tab and compare how the trace reads against the preview.</span>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
};

export default PickerPrototypes;
