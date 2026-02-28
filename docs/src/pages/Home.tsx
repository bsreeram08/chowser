import { useState, useEffect } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Download, Eye, Link as LinkIcon, Plus, Copy, Globe, Zap, Shield } from 'lucide-react';
import { Link } from 'react-router-dom';
import { cn } from '@/lib/utils';
import { toast } from 'sonner';

export const Home: React.FC = () => {
    const [isPrivate, setIsPrivate] = useState(false);
    const [isRuleSimulatorOpen, setIsRuleSimulatorOpen] = useState(false);
    const [selectedBrowser, setSelectedBrowser] = useState<string | null>(null);

    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.key.toLowerCase() === 'p') {
                setIsPrivate(prev => !prev);
                toast.info(`Private Mode ${!isPrivate ? 'Enabled' : 'Disabled'}`, {
                    duration: 1500,
                    icon: <Shield className="w-4 h-4" />
                });
            }
            if (e.key.toLowerCase() === 'r') {
                setIsRuleSimulatorOpen(prev => !prev);
                if (selectedBrowser) setSelectedBrowser(null);
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [isPrivate, isRuleSimulatorOpen, selectedBrowser]);

    const handleBrowserSelect = (name: string) => {
        if (isRuleSimulatorOpen) {
            setSelectedBrowser(name);
            toast.success(`Rule set: Always open with ${name}`, {
                duration: 2000,
                icon: <Zap className="w-4 h-4" />
            });
            setTimeout(() => setIsRuleSimulatorOpen(false), 1500);
        }
    };

    const handleCopy = () => {
        const url = selectedBrowser ? `rule:always_${selectedBrowser.toLowerCase()}` : (isPrivate ? "private.browsing.enabled" : "chowser.app/setup");
        navigator.clipboard.writeText(url);
        toast.success("URL/Rule copied to clipboard", {
            duration: 2000,
            icon: <Copy className="w-4 h-4" />
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
                        Take Control of<br className="hidden sm:block" /> Your Links
                    </h1>

                    {/* Subtext */}
                    <p className="text-base sm:text-xl text-muted-foreground mb-10 max-w-2xl mx-auto leading-relaxed animate-in fade-in slide-in-from-bottom-4 duration-1000 delay-200">
                        A keyboard-first browser chooser with profiles, private mode, app-based routing, and smart rules. Pick the right browser for every link — automatically or in one keystroke.
                    </p>

                    {/* CTAs */}
                    <div className="flex flex-col sm:flex-row items-center justify-center gap-4 animate-in fade-in slide-in-from-bottom-4 duration-1000 delay-300 w-full sm:w-auto">
                        <a
                            href="https://github.com/bsreeram08/chowser/releases/latest"
                            target="_blank"
                            rel="noopener noreferrer"
                            className="w-full sm:w-auto"
                        >
                            <Button
                                id="download"
                                size="lg"
                                className="w-full h-16 px-8 bg-primary hover:bg-primary/90 text-white rounded-2xl font-bold text-lg transition-all duration-300 transform hover:scale-[1.02] shadow-[0_0_30px_-5px_var(--color-primary)]/40 gap-3 group"
                            >
                                <Download className="w-5 h-5 group-hover:-translate-y-1 transition-transform" />
                                Download for Mac
                            </Button>
                        </a>
                        <Link to="/agentic-setup" className="w-full sm:w-auto">
                            <Button size="lg" variant="outline" className="w-full sm:w-auto h-16 px-8 bg-muted/20 hover:bg-muted/40 border-border/50 backdrop-blur-md rounded-2xl font-bold text-lg transition-all text-white">
                                View Setup Guide
                            </Button>
                        </Link>
                    </div>

                    {/* Interactive Demo Toggle */}
                    <div className="mt-12 animate-in fade-in duration-1000 delay-500">
                        <button
                            onClick={() => setIsPrivate(!isPrivate)}
                            className={cn(
                                "flex items-center gap-2.5 px-5 py-2.5 rounded-full border transition-all duration-500 font-medium text-sm",
                                isPrivate
                                    ? "bg-purple-500/10 border-purple-500/30 text-purple-400 shadow-[0_0_20px_-5px_rgba(168,85,247,0.3)]"
                                    : "bg-muted/30 border-border/50 text-muted-foreground hover:text-foreground hover:bg-muted/50"
                            )}>
                            <Eye className={cn("w-4 h-4", isPrivate && "animate-pulse")} />
                            {isPrivate ? "Private Mode Active" : "Try Private Mode"}
                        </button>
                    </div>
                </div>

                {/* Unified Panel Mockup */}
                <div className="mt-16 sm:mt-24 z-10 animate-in fade-in zoom-in-95 duration-1000 delay-500 transform transition-all duration-700 flex justify-center w-full relative group">
                    {/* Shadow behind panel */}
                    <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full max-w-[400px] h-[180px] bg-primary/20 blur-[100px] -z-10 group-hover:bg-primary/30 transition-colors duration-700" />

                    <div className={cn(
                        "flex flex-col w-full max-w-[380px] rounded-[24px] border border-white/10 relative overflow-hidden transition-all duration-700 shadow-2xl backdrop-blur-[32px]",
                        isPrivate ? "bg-purple-950/40 border-purple-500/20" : "bg-black/60"
                    )}>
                        {/* Header: URL Bubble */}
                        <div className="flex items-center gap-2 px-4 py-3 border-b border-white/5 bg-white/5">
                            <LinkIcon className="w-3.5 h-3.5 shrink-0 opacity-40 text-white" />
                            <span className="text-[13px] font-medium text-white/90 flex-1 truncate">
                                {isRuleSimulatorOpen
                                    ? "Add New Routing Rule"
                                    : (selectedBrowser
                                        ? `rule:always_${selectedBrowser.toLowerCase()}`
                                        : (isPrivate ? "private.browsing.enabled" : "chowser.app/setup"))}
                            </span>
                            <div className="flex items-center gap-2">
                                <Plus
                                    className={cn("w-3.5 h-3.5 opacity-40 text-white cursor-pointer hover:opacity-100 transition-opacity", isRuleSimulatorOpen && "text-primary opacity-100 animate-pulse")}
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
                                        <p className="text-sm font-bold text-white">Select Default Browser</p>
                                        <p className="text-[11px] text-white/40">For all links on this domain</p>
                                    </div>
                                    <div className="flex gap-4">
                                        {[
                                            { name: "Safari", color: "bg-[#006CFF]", icon: <Globe className="w-4 h-4" /> },
                                            { name: "Firefox", color: "bg-[#FF6611]", icon: <Shield className="w-4 h-4" /> },
                                            { name: "Chrome", color: "bg-[#4285F4]", icon: <Zap className="w-4 h-4" /> }
                                        ].map((browser) => (
                                            <button
                                                key={browser.name}
                                                onClick={() => handleBrowserSelect(browser.name)}
                                                className={cn(
                                                    "w-10 h-10 rounded-xl flex items-center justify-center text-white transition-all hover:scale-110 active:scale-95 shadow-lg",
                                                    browser.color
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
                                        { name: "Safari", color: "bg-[#006CFF]", icon: <Globe className="w-5 h-5" />, key: "1" },
                                        { name: "Firefox", color: "bg-[#FF6611]", icon: <Shield className="w-5 h-5 opacity-40" />, key: "2" },
                                        { name: "Chrome", color: "bg-[#4285F4]", icon: <Zap className="w-5 h-5" />, key: "3" }
                                    ].map((browser, i) => (
                                        <div key={browser.name} className="flex flex-col items-center gap-2 group/browser cursor-pointer" onClick={() => handleBrowserSelect(browser.name)}>
                                            <div className={cn(
                                                "w-[56px] h-[56px] rounded-2xl flex items-center justify-center relative transition-all duration-300",
                                                (selectedBrowser === browser.name || (!selectedBrowser && i === 0)) ? "bg-white/15 ring-1 ring-white/20 scale-105" : "hover:bg-white/10"
                                            )}>
                                                <div className={cn(
                                                    "w-[40px] h-[40px] rounded-xl flex items-center justify-center text-white shadow-xl transition-transform duration-300 group-hover/browser:scale-110",
                                                    browser.color
                                                )}>
                                                    {browser.icon}
                                                </div>
                                                <span className="absolute -bottom-1 -right-1 z-20 text-[10px] font-bold font-mono text-white/70 bg-black/80 border border-white/10 rounded-md px-1.5 py-0.5 leading-none shadow-sm">
                                                    {browser.key}
                                                </span>
                                            </div>
                                            <span className={cn(
                                                "text-[11px] font-medium transition-colors",
                                                (selectedBrowser === browser.name || (!selectedBrowser && i === 0)) ? "text-white" : "text-white/40 group-hover/browser:text-white/80"
                                            )}>
                                                {browser.name}
                                            </span>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>

                        {/* Footer: Keyboard Hints */}
                        <div className="flex items-center gap-3 w-full px-4 py-2.5 border-t border-white/5 bg-black/40">
                            <div className={cn("flex items-center gap-1.5 transition-opacity", isPrivate ? "opacity-100" : "opacity-30")}>
                                <kbd className={cn("text-[10px] font-bold font-mono text-white border border-white/10 rounded-[4px] px-1.5 py-0.5", isPrivate ? "bg-purple-500/50" : "bg-white/10")}>P</kbd>
                                <span className="text-[9px] font-bold text-white tracking-widest uppercase">Private</span>
                            </div>
                            <div className={cn("flex items-center gap-1.5 transition-opacity", (isRuleSimulatorOpen || selectedBrowser) ? "opacity-100" : "opacity-30")}>
                                <kbd className={cn("text-[10px] font-bold font-mono text-white border border-white/10 rounded-[4px] px-1.5 py-0.5", (isRuleSimulatorOpen || selectedBrowser) ? "bg-amber-500/50" : "bg-white/10")}>R</kbd>
                                <span className="text-[9px] font-bold text-white tracking-widest uppercase">{isRuleSimulatorOpen ? "Active" : "Rule"}</span>
                            </div>
                            <div className="flex-1" />
                            <div className="flex items-center gap-1.5">
                                <kbd className="text-[10px] font-bold font-mono text-white bg-primary rounded-[4px] px-1.5 py-0.5 shadow-[0_0_10px_rgba(59,130,246,0.5)]">↵</kbd>
                                <span className="text-[9px] font-bold text-primary tracking-widest uppercase">Launch</span>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Feature Grid */}
                <section className="container mx-auto px-4 mt-20 max-w-6xl z-10">
                    <div className="grid sm:grid-cols-3 gap-8">
                        <Card className="bg-card/40 border-border/50 p-8 transition-all hover:bg-card/60 hover:scale-[1.02] group backdrop-blur-sm">
                            <Badge variant="outline" className="mb-4 border-primary/20 text-primary">Powerful</Badge>
                            <h3 className="text-xl font-bold text-foreground mb-3 font-sans">Profile Support</h3>
                            <p className="text-muted-foreground text-sm leading-relaxed">
                                Professional support for Multi-Profile across Chrome, Brave, Arc, and Firefox. Keep work and personal separate.
                            </p>
                        </Card>
                        <Card className="bg-card/40 border-border/50 p-8 transition-all hover:bg-card/60 hover:scale-[1.02] group backdrop-blur-sm">
                            <Badge variant="outline" className="mb-4 border-green-500/20 text-green-500">Fast</Badge>
                            <h3 className="text-xl font-bold text-foreground mb-3 font-sans">Keyboard First</h3>
                            <p className="text-muted-foreground text-sm leading-relaxed">
                                Launch any browser with a single shortcut key. No mouse required for lightning-fast link routing.
                            </p>
                        </Card>
                        <Card className="bg-card/40 border-border/50 p-8 transition-all hover:bg-card/60 hover:scale-[1.02] group backdrop-blur-sm">
                            <Badge variant="outline" className="mb-4 border-amber-500/20 text-amber-500">Secure</Badge>
                            <h3 className="text-xl font-bold text-foreground mb-3 font-sans">Smart Rules</h3>
                            <p className="text-muted-foreground text-sm leading-relaxed">
                                Define complex rules using regex or domain matching. Always open the right app for the right task.
                            </p>
                        </Card>
                    </div>
                </section>
            </main>

            <Footer />
        </div>
    );
};

export default Home;
