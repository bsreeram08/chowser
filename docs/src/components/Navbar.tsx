import { useState, useEffect } from 'react';
import { Github } from 'lucide-react';
import { Button, buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export const Navbar = () => {
    const [downloadUrl, setDownloadUrl] = useState("https://github.com/bsreeram08/chowser/releases/latest");

    useEffect(() => {
        const fetchLatestRelease = async () => {
            try {
                const response = await fetch('https://api.github.com/repos/bsreeram08/chowser/releases/latest');
                const data = await response.json();
                const dmgAsset = data.assets?.find((asset: any) => asset.name.endsWith('.dmg'));
                if (dmgAsset) {
                    setDownloadUrl(dmgAsset.browser_download_url);
                }
            } catch (error) {
                console.error("Failed to fetch latest release in navbar:", error);
            }
        };
        fetchLatestRelease();
    }, []);

    return (
        <nav className="fixed top-0 w-full z-50 border-b border-border/50 bg-background/70 backdrop-blur-xl">
            <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
                <a href="#" className="flex items-center gap-2 group">
                    <div className="w-10 h-10 rounded-xl overflow-hidden shadow-lg transform group-hover:scale-105 transition-transform border border-white/10">
                        <img src="/icon.png" alt="Chowser Icon" className="w-full h-full object-cover" />
                    </div>
                    <span className="font-bold text-xl tracking-tight text-foreground">Chowser</span>
                </a>
                <div className="flex items-center gap-1 sm:gap-6">
                    <a href="#agentic-setup">
                        <Button variant="ghost" size="sm" className="text-muted-foreground hover:text-foreground">AI Setup</Button>
                    </a>
                    <a href="#security-setup">
                        <Button variant="ghost" size="sm" className="text-muted-foreground hover:text-foreground">Security</Button>
                    </a>
                    <div className="w-px h-4 bg-border/20 hidden sm:block mx-2" />
                    <a
                        href="https://github.com/bsreeram08/chowser"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-muted-foreground hover:text-foreground transition-colors"
                    >
                        <Github className="w-5 h-5" />
                    </a>
                    <a
                        href={downloadUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={cn(buttonVariants({ variant: "outline", size: "sm" }), "hidden sm:flex border-primary/20 hover:border-primary/40 bg-primary/5 hover:bg-primary/10")}
                    >
                        Download
                    </a>
                </div>
            </div>
        </nav>
    );
};
