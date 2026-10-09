import { Github } from 'lucide-react';
import { Link } from 'react-router-dom';
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { useLatestRelease } from "@/hooks/use-latest-release";


export const Navbar = () => {
    const { dmgUrl } = useLatestRelease();
    return (
        <nav className="fixed top-0 w-full z-50 border-b border-border/50 bg-canvas/80 backdrop-blur-xl">
            <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
                <Link to="/" className="flex items-center gap-2 group">
                    <div className="w-8 h-8 rounded-[10px] overflow-hidden">
                        <img src="/icon.png" alt="Chowser Icon" className="w-full h-full object-cover" />
                    </div>
                    <span className="font-display font-semibold text-lg tracking-tight text-foreground">Chowser</span>
                </Link>
                <div className="flex items-center gap-1 sm:gap-6">
                    <Link to="/guide" className={cn(buttonVariants({ variant: "ghost", size: "sm" }), "text-muted-foreground hover:text-foreground")}>
                        Guide
                    </Link>
                    <Link to="/rewrites" className={cn(buttonVariants({ variant: "ghost", size: "sm" }), "hidden md:inline-flex text-muted-foreground hover:text-foreground")}>
                        Rewrites
                    </Link>
                    <a href="/#agentic-setup" className={cn(buttonVariants({ variant: "ghost", size: "sm" }), "hidden sm:inline-flex text-muted-foreground hover:text-foreground")}>
                        AI Setup
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
                        href={dmgUrl}
                        className="hidden sm:inline-flex items-center rounded-full bg-ink text-white px-4 py-1.5 text-sm font-medium hover:bg-route transition-colors"
                    >
                        Download
                    </a>
                </div>
            </div>
        </nav>
    );
};
