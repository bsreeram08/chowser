import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import {
  ArrowRight,
  Braces,
  Check,
  ExternalLink,
  LockKeyhole,
  RefreshCw,
  ShieldCheck,
  Sparkles,
} from "lucide-react";
import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { Card } from "@/components/ui/card";

type RewriteAction = {
  type: string;
  scheme?: string;
  names?: string[];
  prefixes?: string[];
};

type CatalogRule = {
  id: string;
  name: string;
  summary: string;
  hostPattern: string;
  schemes?: string[];
  excludeHostPatterns?: string[];
  actions: RewriteAction[];
};

type Catalog = {
  schemaVersion: number;
  catalogKind: string;
  catalogVersion: number;
  publishedAt: string;
  rules: CatalogRule[];
};

const describeAction = (action: RewriteAction) => {
  switch (action.type) {
    case "forceScheme":
      return `Changes matching links to ${action.scheme ?? "HTTPS"}.`;
    case "stripQueryParameters":
      return `Removes ${action.names?.join(", ") ?? "listed parameters"} from the URL.`;
    case "stripQueryParameterPrefixes":
      return `Removes parameters beginning with ${action.prefixes?.join(", ") ?? "the listed prefixes"}.`;
    default:
      return "Applies a predefined URL transformation before routing.";
  }
};

export const RewriteCatalog: React.FC = () => {
  const [catalog, setCatalog] = useState<Catalog | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    fetch("/rewrite-catalog.json")
      .then((response) => {
        if (!response.ok) throw new Error("Catalog unavailable");
        return response.json() as Promise<Catalog>;
      })
      .then(setCatalog)
      .catch(() => setFailed(true));
  }, []);

  return (
    <div className="bg-background min-h-screen text-foreground font-sans antialiased overflow-x-hidden">
      <Navbar />
      <main>
        <section className="max-w-5xl mx-auto px-6 pt-36 sm:pt-44 pb-14">
          <div className="max-w-3xl">
            <span className="eyebrow inline-flex items-center gap-1.5">
              <Sparkles className="w-3 h-3" />
              Hosted rule library
            </span>
            <h1 className="font-display font-bold tracking-tight leading-[1.03] text-4xl sm:text-6xl mt-4">
              Useful URL cleanup,
              <br />ready to review.
            </h1>
            <p className="text-muted-foreground text-lg sm:text-xl mt-6 max-w-2xl leading-relaxed">
              These optional rewrites clean links before Chowser routes them. Nothing is
              installed automatically: you choose each rule in Settings.
            </p>
          </div>

          <div className="grid sm:grid-cols-3 gap-3 mt-10">
            {[
              [ShieldCheck, "Signed catalog", "Chowser verifies every catalog before showing it."],
              [LockKeyhole, "Local execution", "Rewrites run on your Mac before launch."],
              [RefreshCw, "Explicit updates", "Chowser only checks when you ask it to."],
            ].map(([Icon, title, body]) => {
              const ItemIcon = Icon as typeof ShieldCheck;
              return (
                <Card key={title as string} className="p-5">
                  <ItemIcon className="w-5 h-5 text-primary" />
                  <h2 className="font-display font-semibold mt-4">{title as string}</h2>
                  <p className="text-sm text-muted-foreground mt-1.5 leading-relaxed">{body as string}</p>
                </Card>
              );
            })}
          </div>
        </section>

        <section className="max-w-5xl mx-auto px-6 pb-16">
          <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 pb-5 border-b border-black/[0.08]">
            <div>
              <span className="eyebrow">Current catalog</span>
              <h2 className="font-display text-2xl sm:text-3xl font-bold tracking-tight mt-2">
                {catalog ? `${catalog.rules.length} predefined rewrites` : "Predefined rewrites"}
              </h2>
            </div>
            {catalog && (
              <span className="font-mono text-xs text-muted-foreground">
                v{catalog.catalogVersion} · published {catalog.publishedAt.slice(0, 10)}
              </span>
            )}
          </div>

          {failed && (
            <Card className="p-6 mt-5 border-orange-200 bg-orange-50/50">
              <p className="font-medium">The catalog could not be loaded.</p>
              <p className="text-sm text-muted-foreground mt-1">
                You can still inspect the raw catalog or try again later.
              </p>
            </Card>
          )}

          {!catalog && !failed && (
            <div className="py-16 text-center text-muted-foreground">Loading the catalog…</div>
          )}

          <div className="divide-y divide-black/[0.08]">
            {catalog?.rules.map((rule) => (
              <article key={rule.id} className="grid md:grid-cols-[220px_1fr] gap-3 md:gap-10 py-7">
                <div>
                  <h3 className="font-display font-semibold text-lg">{rule.name}</h3>
                  <code className="inline-block mt-2 rounded-md bg-black/[0.04] px-2 py-1 text-[11px] text-muted-foreground">
                    {rule.hostPattern}
                  </code>
                </div>
                <div>
                  <p className="text-[15px] text-foreground leading-relaxed mb-2">
                    {rule.summary}
                  </p>
                  <p className="text-[15px] text-muted-foreground leading-relaxed">
                    {rule.actions.map(describeAction).join(" ")}
                  </p>
                  {rule.excludeHostPatterns && rule.excludeHostPatterns.length > 0 && (
                    <p className="text-xs text-muted-foreground mt-3">
                      Excludes {rule.excludeHostPatterns.join(", ")}.
                    </p>
                  )}
                </div>
              </article>
            ))}
          </div>
        </section>

        <section className="max-w-5xl mx-auto px-6 pb-28">
          <div className="rounded-3xl bg-[#f5f5f7] border border-black/[0.06] p-6 sm:p-9 grid md:grid-cols-[1fr_auto] gap-8 items-center">
            <div>
              <h2 className="font-display text-2xl font-bold tracking-tight">Add only what you need</h2>
              <ol className="mt-5 space-y-3 text-sm text-muted-foreground">
                <li className="flex gap-3"><Check className="w-4 h-4 text-primary shrink-0 mt-0.5" />Open Chowser Settings → Rewrites.</li>
                <li className="flex gap-3"><Check className="w-4 h-4 text-primary shrink-0 mt-0.5" />Choose Browse Predefined Rewrites.</li>
                <li className="flex gap-3"><Check className="w-4 h-4 text-primary shrink-0 mt-0.5" />Review, select, and add the rules you want.</li>
              </ol>
            </div>
            <div className="flex flex-col items-start gap-3 text-sm">
              <Link to="/guide" className="inline-flex items-center gap-1.5 font-medium text-primary hover:underline">
                Read the setup guide <ArrowRight className="w-4 h-4" />
              </Link>
              <a href="/rewrite-catalog.json" className="inline-flex items-center gap-1.5 text-muted-foreground hover:text-foreground">
                <Braces className="w-4 h-4" /> Raw JSON <ExternalLink className="w-3 h-3" />
              </a>
              <a href="/rewrite-catalog.sig.json" className="inline-flex items-center gap-1.5 text-muted-foreground hover:text-foreground">
                <ShieldCheck className="w-4 h-4" /> Signature <ExternalLink className="w-3 h-3" />
              </a>
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </div>
  );
};

export default RewriteCatalog;
